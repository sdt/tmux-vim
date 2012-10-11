#!/usr/bin/env python

import ConfigParser;
import os;
import pipes;
import re;
import subprocess;
import sys;

#------------------------------------------------------------------------------

cfg = {}

#------------------------------------------------------------------------------

def die(msg):
	print >> sys.stderr, msg
	sys.exit(1)

def load_section(parser, section):
	if not parser.has_section(section):
		return { }
	return dict(parser.items(section))

def load_config(defaults):
	parser = ConfigParser.SafeConfigParser()
	inifile = os.environ.get('TMUX_VIM_INI',
							 os.path.expanduser('~/.tmux-vim.ini'))
	try:
		parser.read(inifile)
	except ConfigParser.Error as e:
		die('Reading %s:\n%s' % (inifile, e))
	cfg = defaults
	cfg.update(load_section(parser, 'general'))
	cfg['layout'] = load_section(parser, 'layout')
	return cfg

def tmux_exec(args):
	subprocess.check_call([cfg['tmux']] + args)

def cmd_query(command, pattern):
	output = subprocess.check_output(command)
	regex = re.compile(pattern, re.MULTILINE)
	match = regex.search(output)
	if match is None:
		return None
	return match.group(1)

def make_pattern(lhs):
	return '^' + re.escape(lhs) + '=(.*)\s*$'

def tmux_fetch_env(key):
	return cmd_query([ cfg['tmux'], 'show-environment' ], make_pattern(key))

def tmux_store_env(key, value):
	tmux_exec([ 'set-environment', key, value ])

def tmux_window_id():
	return cmd_query(
		[ cfg['tmux'], 'lsp', '-a', '-F', '#{pane_id}=#{window_index}' ],
		make_pattern(os.environ['TMUX_PANE'])
	)

def get_vim_cwd(vim_pane_id):
	vim_pid = cmd_query(
		[ cfg['tmux'], 'lsp', '-F', '#{pane_id}=#{pane_pid}' ],
		make_pattern(vim_pane_id)
	)
	return cmd_query(
		[ 'lsof', '-p', vim_pid, '-a', '-d', 'cwd', '-Fn' ],
		'^n(.*)$'
	)

def tmux_pane_size(split):
	if split == 'h':
		dimension = 'width'
	else:
		dimension = 'height'
	return int(cmd_query(
		[ cfg['tmux'], 'lsp', '-F', '#{pane_id}=#{pane_%s}' % (dimension) ],
		make_pattern(os.environ['TMUX_PANE'])
	))

def select_pane(pane_id):
	cmd = [ cfg['tmux'], 'select-pane', '-t', str(pane_id) ]
	return subprocess.call(cmd, stderr=open(os.devnull)) == 0

def layout_option(key, default):
	return cfg['layout'].get(key, default)

def split_method(vim_pos):
	if vim_pos == 'left' or vim_pos == 'right':
		return 'h'
	else:
		return 'v'

def eval_percent(pc, val):
	if str(pc)[-1] == '%':
		return int(pc[:-1]) * val / 100
	else:
		return int(pc)

def compute_layout():
	vim_pos = layout_option('vim-pos', 'right')
	split = split_method(vim_pos)
	pane = tmux_pane_size(split)
	mode = layout_option('mode', 'shell')
	swap_panes = (vim_pos == 'left' or vim_pos == 'top')
	vim_args = ' '

	default_shell = { 'h': 132, 'v': 15  }
	default_vim   = { 'h':  80, 'v': 24  }

	if mode == 'shell':

		shell_size = layout_option('size', default_shell[split])
		split_size = eval_percent(shell_size, pane)

	elif mode == 'vim':

		vim = eval_percent(layout_option('size', default_vim[split]), pane)

		# Factor in the vim sub-window count
		count = layout_option('count', 1)
		if count == 'auto':
			reserve = layout_option('reserve', default_shell[split])
			shell = eval_percent(reserve, pane)
			count = max(1, (pane - shell) / (vim + 1))
		else:
			count = int(count)

		split_size = (vim + 1) * count - 1

		autosplit = bool(layout_option('autosplit', False))
		if autosplit:
			window_method = { 'h': 'O', 'v': 'o' }
			vim_args += "-%s%d" % (window_method[split], count)

	if swap_panes:
		split_size = pane - split_size - 1

	return {
		'split_method': '-' + split,
		'split_size':	str(split_size),
		'swap_panes':	swap_panes,
		'vim_args':		vim_args,
	}


def spawn_vim_pane(filenames):
	opt = compute_layout()
	vim_files = ' '.join(map(pipes.quote, filenames))
	vim_cmd = ' '.join(['exec', cfg['vim'], opt['vim_args'], vim_files])
	tmux_cmd = [ cfg['tmux'], 'split-window', '-P', opt['split_method'], '-l', opt['split_size'], vim_cmd ]
	print tmux_cmd
	pane_path = subprocess.check_output(tmux_cmd).rstrip('\n\r')

	# 0:1.1: [100x88] [history 0/10000, 0 bytes] %2
	# ^^^^^ pane_path                   pane_id  ^^
	pattern = '^' + re.escape(pane_path) + ':.*(%\\d+)'
	pane_id = cmd_query([ cfg['tmux'], 'lsp', '-a' ], pattern)

	if opt['swap_panes']:
		tmux_exec(['swap-pane', '-D'])

	return pane_id

def vim_command(command, filename, vim_cwd):
	# Vim or bash may have changed directory, so we need some path manipulation
	relpath = os.path.relpath(filename, vim_cwd)
	abspath = os.path.abspath(filename)
	path = relpath if len(relpath) < len(abspath) else abspath

	# We split filename up into chars so it isn't processed as a tmux
	# key name (eg. space or enter)
	return [ ':', command, 'space' ] + list(path) + [ 'enter' ]

def reuse_vim_pane(pane_id, filenames):
	if filenames:
		vim_cwd = get_vim_cwd(pane_id)
		keys = ['escape']
		for filename in filenames[:-1]:
			keys += vim_command('badd', filename, vim_cwd)
		keys += vim_command('edit', filenames[-1], vim_cwd)
		tmux_exec([ 'send-keys', '-t', pane_id ] + keys)

#------------------------------------------------------------------------------

def main(filenames):
	global cfg
	cfg = load_config({ 'tmux': 'tmux', 'vim': 'vim' })
	window_key = 'tmux_vim_pane_' + tmux_window_id()
	vim_pane_id = tmux_fetch_env(window_key)
	if vim_pane_id is None or not select_pane(vim_pane_id):
		vim_pane_id = spawn_vim_pane(filenames)
		tmux_store_env(window_key, vim_pane_id)
	else:
		reuse_vim_pane(vim_pane_id, filenames)

#------------------------------------------------------------------------------

if __name__ == "__main__":
	main(sys.argv[1:])
