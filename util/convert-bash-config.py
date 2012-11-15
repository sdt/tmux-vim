#!/usr/bin/env python

from datetime import datetime;
import ConfigParser;
import os;
import os.path;
import re;
import string;
import sys;

LAYOUT_PREFIX = 'layout='

def main():
	if len(sys.argv) > 1:
		filename = sys.argv[1]
	else:
		filename = os.environ.get('TMUX_VIM_CONFIG', '~/.tmux-vim.conf')
	load_config_file_to_environment(filename)
	cp = create_config_from_environment()
	optimise_config(cp)
	write_config(cp, os.path.abspath(filename), sys.stdout)

def load_config_file_to_environment(filename):
	# Rather than try to parse the shell config file, exec the shell itself,
	# get it to parse the shell config file, and then call this script again.
	# That way all the stuff in the config file will then be in the environment.
	#
	# Use $TMUX_VIM_CONVERTING to flag that we've called ourselves.
	if '_TMUX_VIM_CONVERTING' not in os.environ:
		shell = os.environ['SHELL']
		shell_cmds = [
			'set -a',						# export all variables
			'source ' + filename, 			# read the config
			'_TMUX_VIM_CONVERTING=1',		# set the re-entry flag
			os.path.abspath(sys.argv[0])	# run this script again
				+ ' ' + filename			# ... with this filename
		]
		# Call exec rather than system because we don't want to return
		os.execl(shell, shell, '-c', ';'.join(shell_cmds))

def parse_layout_section(cp, section, config):
	cp.add_section(section)
	for opt in config.split(','):
		key, value = opt.split(':')
		cp.set(section, key, value)

def create_config_from_environment():
	cp = ConfigParser.SafeConfigParser()

	cmd_section = 'commands'
	cp.add_section(cmd_section)

	env = os.environ
	if 'TMUX_VIM_TMUX_BIN' in env:
		cp.set(cmd_section, 'tmux', env['TMUX_VIM_TMUX_BIN'])
	else:
		cp.set(cmd_section, '# tmux', '(tmux commandline)')

	if 'TMUX_VIM_VIM_BIN' in env or 'TMUX_VIM_VIM_ARGS' in env:
		vim = env.get('TMUX_VIM_VIM_BIN', 'vim')
		if 'TMUX_VIM_VIM_ARGS' in env:
			vim += ' ' + env['TMUX_VIM_VIM_ARGS']
		cp.set(cmd_section, 'vim', vim)
	else:
		cp.set(cmd_section, '# vim', '(vim commandline)')

	# See if we can find any sub-layouts like in the sample config
	tr = string.maketrans('_', '-')
	for var in env:
		match = re.match('TMUX_VIM_LAYOUT_(.*)', var)
		if match:
			name = match.group(1).lower().translate(tr)
			parse_layout_section(cp, LAYOUT_PREFIX + name, env[var])

	parse_layout_section(cp, 'layout', env.get('TMUX_VIM_LAYOUT', ''))

	return cp

def section_is_superset(cp, supsec, subsec):
	try:
		for key, val in cp.items(subsec):
			if cp.get(supsec, key) != val:
				return False
		return True
	except ConfigParser.NoOptionError:
		return False

def convert_subsection(cp, supsec, subsec):
	for key, val in cp.items(subsec):
		cp.remove_option(supsec, key)
	cp.set(supsec, 'include', subsec[len(LAYOUT_PREFIX):])

def optimise_config(cp):
	# Go through the layout sections in order, from biggest to smallest, with
	# the top-level section first.
	# This order ensures two things:
	# 1. we always include the biggest sub-section if multiple ones match
	# 2. we don't try to extract a nested sub-section
	sections = [ s for s in cp.sections() if re.match(LAYOUT_PREFIX, s) ]
	sections.sort(key = len, reverse=True)
	sections.insert(0, 'layout')

	for i in range(0, len(sections)-1):
		supsec = sections[i]
		for j in range(i + 1, len(sections)):
			subsec = sections[j]
			if section_is_superset(cp, supsec, subsec):
				convert_subsection(cp, supsec, subsec)
				break

def write_config(cp, filename, fh):
	print >> fh,  '# tmux-vim config'
	print >> fh,  '# automatically generated by %s at %s' % (os.path.basename(sys.argv[0]), datetime.now())
	print >> fh, '# from', filename
	print >> fh
	cp.write(sys.stdout)


if __name__ == "__main__":
	main()