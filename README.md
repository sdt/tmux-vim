# tmux-vim

`tvim` is a bash function which I use in conjunction with **tmux** to create a persistent **vim** pane within a **tmux** window.

![screenshot](http://sdt.github.com/tmux-vim/img/tvim-screenshot.png)

## Installation

From your .bashrc:

`source tmux-vim/tmux-vim.bash`

## Usage

`tvim [file] [files...]`

Thats it. Use **tvim** just like you'd use **vim**.

The first time you run it, a new pane will be created on the right hand side of your **tmux** window, running an instance of **vim**.

Further calls to **tvim** will open the files in new buffers in the same **vim** session.

If you close that **vim** session, the pane will be destroyed. The next call to **tvim** will create a new one.

## Configuration

By default **tvim** will create as many 80-column **vim** panes as possible, while leaving at least 132-columns for the shell session on the left.

This behaviour can be adjusted with the following environment variables.

### TVIM_PANE_WIDTH
* width of a single **vim** pane in columns (default 80)

### TVIM_PANES
* optionally specify a fixed number of **vim** panes with this

### TVIM_SHELL_MIN_WIDTH
* if `TVIM_PANES` is not set, panes will be created to leave a shell pane of at least `TVIM_SHELL_MIN_WIDTH` columns
* on narrow displays, one **vim** pane will always be created, even if this means we leave less that `TVIM_SHELL_MIN_WIDTH` columns for the shell

## How's it work?

**tmux** makes it all possible.

First `tmux split-window` is used to create the **vim** pane, with the pane id saved in **$TVIM**. This happens on demand - panes are created only when needed.

Then keystrokes are injected into **vim** with `tmux send-keys`. Loading a file means sending keystrokes to force **vim** to do `:edit filename<cr>`. Once **vim** is running, this keystroke-injection is how **vim** gets controlled.

Finally, `tmux select-pane` transfers control over to the **vim** pane.

## Bugs?

Probably.

I'd really like to do a **zsh** port.

By default, **vim** won't abandon an unsaved file to open another one, instead it'll prompt the user to save, abandon or cancel. This can throw out the keystroke stuffing when trying to open multiple files.

Rather than using the `:edit` command, the files are loaded with multiple calls to `:badd`, finally switching to the last one with `:buffer`. If the current buffer is unsaved, the prompt happens now, after all the keystroke stuffing. This seems to work, but there may be combinations that still break.

When the **vim** pane is created, the current directory is saved. When opening files, the current directory is compared to the stored one. If these differ, `:cd` is used in **vim** to temporarily change back to the original directory before opening the files. This avoids any sticky relative path computations, but breaks if the user does a `:cd` manuall within **vim**.
