# Configuration variables.
#
# TVIM_PANE_WIDTH - how wide a single vim pane is (default 80)
# TVIM_PANES - how many vim panes to create
#
# If TVIM_PANES is not set, then it will be set as large as possible while
# keeping the shell pane width at least TVIM_SHELL_MIN_WIDTH (default 132)

_tvim_panes() {
    local shell_min_width=${TVIM_SHELL_MIN_WIDTH:-132}
    local vim_pane_width=${TVIM_PANE_WIDTH:-80}
    local screen_width=$( tmux lsc -t $TMUX_PANE -F '#{client_height}' )

    #TODO: change client_height to client_width when tmux 1.7 arrives

    local panes=$[ ( $screen_width - $shell_min_width ) / ( $vim_pane_width + 1 ) ]
    echo $[ $panes > 0 ? $panes : 1 ]
}

_tvim_is_running() { tmux lsp -F '#{pane_id}' | grep -q '^'$TVIM'$'; }

# _tvim_start [number-of-panes]
# - split a new tmux pane and start vim in it
# - the pane id is stored in $TVIM
_tvim_start() {
    if [[ -n $TVIM ]] && _tvim_is_running; then
        # TVIM already exists - try to select that pane
        tmux select-pane -t $TVIM && return

        # If we get here, that pane no longer exists, so fall thru
        # (shouldn't happen)
    fi

    local vim_panes=${1:-${TVIM_PANES:-$(_tvim_panes)}}
    local vim_pane_width=${TVIM_PANE_WIDTH:-80}
    local split_width=$[ ($vim_pane_width + 1) * $vim_panes - 1 ]

    local vim_args=''
    #vim_args+=" -O$vim_panes"  # this is annoying me - turning it off

    # Split a new pane, start vim in it, and record the pane index
    local tvim_pane=$(tmux split-window -P -h -l $split_width \
                        "exec vim $vim_args")

    # Now convert the pane index into a global persistent id
    # 0:1.1: [100x88] [history 0/10000, 0 bytes] %2
    # ^^^^^ $tvim_pane                    $TVIM  ^^
    export TVIM=$(tmux lsp -a | grep ^${tvim_pane}: | grep -o '%[0-9]\+')
    export TDIR="$PWD"
}

# _tvim_send_keys [keystrokes...]
# - sends keystrokes to the vim instance created by tvim
# - keystroke syntax is the same as tmux send-keys
_tvim_send_keys() {
    tmux send-keys -t $TVIM "$@"
}
# _tvim_op <op> <file>
# - does _tvim_send_keys :$op space $file
# - escapes spaces correctly in $file
_tvim_op() {
    # Backslash escape all spaces in the file name
    _tvim_send_keys :$1 space "${2// /\\ }" enter
}

# tvim [files...]
# - if no existing tvim instance is running, a new one is spawned
# - opens the listed files inside the tvim instance
tvim() {
    _tvim_start
    _tvim_send_keys escape  # make sure we're in command mode

    if [[ $# -gt 0 ]]; then

        # If we are now in a different directory than $TDIR, we want to make
        # vim switch to this directory temporarily before opening the files.
        # This obviates any relative path computations.
        # (don't go switching directories if we have no files though...)
        [[ "$PWD" != "$TDIR" ]] && _tvim_op cd "$PWD"

        # Rather than :edit each file in turn, :badd each file into a new
        # buffer, and then finally switch to the last one with :buffer.
        # This is to handle the situation where the current buffer is unsaved,
        # and an :edit command will cause vim to prompt the user to save,
        # abandon or cancel.
        # If we just :edit each file, things just don't work out naturally;
        # cancel works, but yes/no end up with only the first file opened.
        # Errant escape keys cause the whole open to just silently fail.
        # This approach pushes the user interaction right to the end.
        for file in "$@"; do
            _tvim_op badd "$file"   # load a buffer for each file
        done

        [[ "$PWD" != "$TDIR" ]] && _tvim_op cd -

        _tvim_op buffer "${!#}"       # switch to the final file
    fi

    tmux select-pane -t $TVIM
}
