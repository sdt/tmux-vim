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
**tmux** window according to `TMUX_VIM_SPLIT`, running an instance of **vim**.

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

### TMUX_VIM_VIM_BIN

Default: vim

The binary executable used to run **vim**. Useful if you're using
[MacVim](http://code.google.com/p/macvim/) and have another binary like `mvim`
which you'd like to use.

### TMUX_VIM_VIM_ARGS

Default: (empty)

Command-line arguments to pass through to **vim**.

### TMUX_VIM_LAYOUT

Default: mode:shell,orient:horiz,width:132

Layout specification. See *Layout* below.

Layout
------

The window layout can be specified with the `TMUX_VIM_LAYOUT` variable.

### Primary layout options

#### pos

Where the **vim** pane is created relative to the shell pane.

Values: `above` `below` `left` `right`

#### mode

How the size is computed.

Values: `vim` `shell`

When the value is `vim` the size calculations are made concerning the **vim**
pane; the shell pane is allocated the remaining space.

Conversely, whem the value is `shell`, the shell pane size is calculated, and
the **vim** pane gets the remainder.

#### size

What size to make the chosen pane.

Values: _number_ (eg. 132) or _percentage_ (eg. 40%)

You can specify an exact row or column size, or a percentage of the original
pane.

### Other layout options

#### count

Only valid for `mode:vim` and `pos:left/right`.

Values: _number_ or `auto`

Will create `size` * `count` vim sub-windows.

If the value is `auto`, the vim pane will fill the available width with
sub-windows, leaving at least `reserve` columns for the shell.

#### reserve

Only valid for count:auto.

Value: _number_

See `count` above.

#### autosplit

Only valid for `mode:vim` and `pos:left/right`.

Values: 1

If autosplit is set, vim will be called with the -O option to automatically
split into sub-windows.

How's it work?
--------------

**tmux** makes it all possible.

First `tmux split-window` is used to create the **vim** pane, and the pane id is
saved in the tmux environment. This happens on demand - panes are created only
when needed.

The **vim** instance is controlled by injecting keystrokes with
`tmux send-keys`. To load a file, **tmux-vim** sends `:edit filename<cr>` to the
**vim** instance.

Finally, `tmux select-pane` transfers control over to the **vim** pane.

Bugs?
-----

Probably.

By default, **vim** won't abandon an unsaved file to open another one, instead
the user is prompted to save, abandon or cancel. This can throw out the
keystroke injection when trying to open multiple files.

To avoid this problem, files are loaded with calls to `:badd` rather than
`:edit`. After the last buffer is added, `:buffer` is used to switch to it. This
delays the user prompt until the very end, when the user has regained control.
This appears to work, but there may still be issues lurking.

When the **vim** pane is created, the current directory is saved in the **tmux**
environment. The directory is used when computing relative paths. If the user
manually changes the vim working directory, the relative paths will break.

Acknowledgements
----------------

A big thank you to the following contributors:

* [Nathan Smith](http://github.com/smith)
* [Techlive Zheng](http://github.com/techlivezheng)
