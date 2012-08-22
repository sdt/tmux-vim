tmux-vim
========

**tmux-vim** is a bash script which works in conjunction with **tmux** to create
a persistent **vim** pane within a **tmux** window.

![screenshot](http://sdt.github.com/tmux-vim/img/tvim-screenshot.png)

Usage
-----

Use **tmux-vim** just like you'd use **vim**.

`tmux-vim [file] [files...]`


The first time you run it, a new pane will be created within your current
**tmux** window according to `TMUX_VIM_LAYOUT`, running an instance of **vim**.

Further calls to **tmux-vim** will open the files in new buffers in the same
**vim** session. This works in all panes within that **tmux** window, even ones
created after the **vim** session has been started.

If you close that **vim** session, the pane will be destroyed. The next call to
**tmux-vim** will create a new one.

Installation
------------

Copy **tmux-vim** to somewhere in your path.

Alternatively, you can do something like this in your `.bashrc`:

    if [[ -n $TMUX ]]; then
        vi() { ~/projects/tmux-vim/tmux-vim "$@"; }
    fi

Requirements
------------

You need **tmux** version 1.6 or later.

Configuration
-------------

This behaviour can be adjusted with the following environment variables.

### TMUX_VIM_CONFIG

Path to configuration file.

Default: ~/.tmux-vim.conf

The remaining variables can be set via this config file.

### TMUX_VIM_TMUX_BIN

The binary executable (and arguments) used to run **tmux**.

Default: tmux

To test tmux-vim against a different tmux binary that your usual one, first
start the tmux session with `$path_to_/tmux -L testing`, and then set
`TMUX_VIM_TMUX_BIN=$path_to_/tmux -L testing`.

### TMUX_VIM_VIM_BIN

The binary executable used to run **vim**.

Default: vim

Useful if you're using [MacVim](http://code.google.com/p/macvim/) and have
another binary like `mvim` which you'd like to use.

### TMUX_VIM_VIM_ARGS

Command-line arguments to pass through to **vim**.

Default: (empty)

Note that these will only be used when the **vim** instance is created.

### TMUX_VIM_LAYOUT

Layout specification. See *Layout* below.

Default: mode:shell,vim-pos:right,width:132

Layout
------

The window layout can be configured with the `TMUX_VIM_LAYOUT` variable.

When the **vim** window is spawned, the current **tmux** pane is split into two.
**tmux-vim** needs to decide which way to split it, and where to put the split.

### Primary layout options

#### vim-pos

Where the **vim** pane is created relative to the shell pane.

Values: `left` `right` `top` `bottom`
Default: `right`

#### mode

How the pane sizes is computed.

Values: `vim` `shell`
Default: `shell`

When the value is `vim` the **vim** pane size is calculated, and the shell pane
is allocated the remaining space.

Conversely, when the value is `shell`, the shell pane size is calculated, and
the **vim** pane gets the remainder.

#### size

What size to make the chosen pane.

Values: _number_ (eg. 132) or _percentage_ (eg. 40%)

You can specify an exact row or column size, or a percentage of the original
pane.

The defaults depend upon the mode. In `vim` mode, 80x24, in `shell` 132x15.

### Extra layout options for vim mode

#### count

Values: _number_ or `auto`
Default: 1

Will create `size` * `count` vim sub-windows.

If the value is `auto`, the vim pane will fill the available width with
sub-windows, leaving at least `reserve` columns for the shell.

#### reserve

Only valid for `count:auto`.

Value: _number_

The amount of space to reserve for the shell when using `mode:vim` with
`count:auto`

#### autosplit

Values: 0 1
Default: 0

If `autosplit` is 1, **vim** will automatically split into sub-windows.

How's it work?
--------------

**tmux** makes it all possible.

First `tmux split-window` is used to create the **vim** pane, and the pane id is
saved in the tmux environment. This happens on demand - panes are created only
when needed.

The **vim** instance is controlled by injecting keystrokes with
`tmux send-keys`. To load files, **tmux-vim** sends `:badd filename<cr>` to the
**vim** instance for each file, and then `:blast<cr>` to select the last file
added.

Finally, `tmux select-pane` transfers control over to the **vim** pane.

Bugs?
-----

Probably.

By default, **vim** won't abandon an unsaved file to open another one, instead
the user is prompted to save, abandon or cancel. This can throw out the
keystroke injection when trying to open multiple files.

To avoid this problem, files are loaded with calls to `:badd` rather than
`:edit`. After the last buffer is added, `:blast` is used to switch to it. This
delays the user prompt until the very end, when the user has regained control.
This appears to work, but there may still be issues lurking.

When the **vim** pane is created, the current directory is saved in the **tmux**
environment. The directory is used when computing relative paths. If the user
manually changes the vim working directory, the relative paths will break.

Contact
-------

Bug reports, suggestions, feature requests and patches are most welcome at
[the tmux-vim git repo](https://github.com/sdt/tmux-vim).

Acknowledgements
----------------

A big thank you to the following contributors:

* [Nathan Smith](http://github.com/smith)
* [Techlive Zheng](http://github.com/techlivezheng)
