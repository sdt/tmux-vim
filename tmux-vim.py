#!/usr/bin/env python

import os;
import pipes;
import re;
import subprocess;
import sys;

#------------------------------------------------------------------------------

cfg = {
	'layout': 	os.environ.get('TMUX_VIM_LAYOUT', 		''),
	'tmux': 	os.environ.get('TMUX_VIM_TMUX_BIN', 	'tmux'),
	'vim':  	os.environ.get('TMUX_VIM_VIM_BIN',  	'vim')
}

#------------------------------------------------------------------------------

def layout_option(key, default):
	# key=value,key=value,key=value
	pattern = '(?:^|,)' + re.escape(key) + ':(.*?)(?:,|$)'
	match = re.search(pattern, cfg['layout'])
	if match is None:
		return default
	return match.group(1)

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

def select_pane(pane_id):
	cmd = [ cfg['tmux'], 'select-pane', '-t', str(pane_id) ]
	return subprocess.call(cmd, stderr=open(os.devnull)) == 0

def spawn_vim_pane(filenames):
	vim_files = ' '.join(map(pipes.quote, filenames))
	vim_cmd = 'exec ' + cfg['vim'] + ' ' + vim_files
	tmux_cmd = [ cfg['tmux'], 'split-window', '-P', '-h', '-l', '80', vim_cmd ]
	pane_path = subprocess.check_output(tmux_cmd).rstrip('\n\r')

    # 0:1.1: [100x88] [history 0/10000, 0 bytes] %2
    # ^^^^^ pane_path                   pane_id  ^^
	pattern = '^' + re.escape(pane_path) + ':.*(%\\d+)'
	pane_id = cmd_query([ cfg['tmux'], 'lsp', '-a' ], pattern)
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
