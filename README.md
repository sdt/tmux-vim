# tvim

`tvim` is a bash script which works in conjunction with **tmux** to create a persistent **vim** pane within a **tmux** window.

![screenshot](http://sdt.github.com/tmux-vim/img/tvim-screenshot.png)

## Requirements

You need **tmux** version 1.6 or later.

## Installation

Copy **tvim** to somewhere in your path.

## Usage

Use **tvim** just like you'd use **vim**.

`tvim [file] [files...]`

The first time you run it, a new pane will be created on the right hand side of your **tmux** window, running an instance of **vim**.

Further calls to **tvim** will open the files in new buffers in the same **vim** session.

If you close that **vim** session, the pane will be destroyed. The next call to **tvim** will create a new one.

## Configuration

By default **tvim** will create as many 80-column **vim** panes as possible, while leaving at least 132-columns for the shell session on the left.

This behaviour can be adjusted with the following environment variables.

### TVIM_SPLIT

Value: ['HORIZONTAL' | 'VERTICAL' ]

Define how tvim split panes.

### TVIM_VIM_ARGS

Command-line arguments to pass through to **vim**

### TVIM_SHELL_WIDTH

If `TVIM_SPLIT` is 'HORIZONTAL', then this variable defines the width of the shell pane. The left space is for vim pane. If the left space is less than 80 columns, this variable will be ignored, make sure vim pane is always has more than 80 columns.

### TVIM_SHELL_HEIGHT

If `TVIM_SPLIT` is 'VERTICAL', then this variable defines the height of the shell pane.

## How's it work?

**tmux** makes it all possible.

First `tmux split-window` is used to create the **vim** pane, and the pane id is saved in the tmux environment. This happens on demand - panes are created only when needed.

The **vim** instance is controlled by injecting keystrokes with `tmux send-keys`. To load a file, **tvim** sends `:edit filename<cr>` to the **vim** instance.

Finally, `tmux select-pane` transfers control over to the **vim** pane.

## Bugs?

Probably.

By default, **vim** won't abandon an unsaved file to open another one, instead the user is prompted to save, abandon or cancel. This can throw out the keystroke injection when trying to open multiple files.

To avoid this problem, files are loaded with calls to `:badd` rather than `:edit`. After the last buffer is added, `:buffer` is used to switch to it. This delays the user prompt until the very end, when the user has regained control. This appears to work, but there may still be issues lurking.

When the **vim** pane is created, the current directory is saved in the **tmux** environment. The directory is used when computing relative paths. If the user manually changes the vim working directory, the relative paths will break.
