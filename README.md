# tmux-vim

`tvim` is a bash function which I use in conjunction with tmux to create a persistent vim pane within a tmux window.

## Usage

`tvim [file] [files...]`

Thats it. Use **tvim** just like you'd use **vim**.

The first time you run it, a new pane will be created on the right hand side of your **tmux** window, running an instance of **vim**.

Further calls to **tvim** will open the files in new buffers in the same **vim** session.

If you close that **vim** session, the pane will be destroyed. The next call to **tvim** will create a new one.

## Configuration

By default **tvim** will create as many 80-column vim panes as possible, while
leaving at least 132-columns for the shell session on the left.

This behaviour can be adjusted with the following environment variables.

### TVIM_PANE_WIDTH
* width of a single **vim** pane in columns (default 80)

### TVIM_PANES
* optionally specify a fixed number of vim panes with this

### TVIM_SHELL_MIN_WIDTH
* if `TVIM_PANES` is not set, panes will be created to leave a shell pane of at least `TVIM_SHELL_MIN_WIDTH` columns
* on narrow displays, one **vim** pane will always be created, even if this means we leave less that `TVIM_SHELL_MIN_WIDTH` columns for the shell
