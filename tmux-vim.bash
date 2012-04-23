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

    echo $[ ( $screen_width - $shell_min_width ) / ( $vim_pane_width + 1 ) ]
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

    # Split a new pane, start vim in it, and record the pane index
    local tvim_pane=$(tmux split-window -P -h -l $split_width \
                        "exec vim -O$vim_panes")

    # Now convert the pane index into a global persistent id
    # 0:1.1: [100x88] [history 0/10000, 0 bytes] %2
    # ^^^^^ $tvim_pane                    $TVIM  ^^
    export TVIM=$(tmux lsp -a | grep ^${tvim_pane}: | grep -o '%[0-9]\+')
    export TDIR="$PWD"
}

# _tvim_send_keys [keystrokes...]
# - sends keystrokes to the vim instance created by tvim
# - if no vim instance exists, one is created
# - keystroke syntax is the same as tmux send-keys
_tvim_send_keys() {
    ( [[ -n $TVIM ]] && tmux send-keys -t $TVIM escape ) || tvim
    tmux send-keys -t $TVIM escape
    tmux send-keys -t $TVIM "$@"
}

# _fullpath <file or dir>
# - expands a file or directory into its full path spec
_fullpath() {
    if [ -d "$1" ]; then
        echo $( cd "$1" ; echo "$PWD" )
    else
        echo $( cd $( dirname "$1" ); echo $PWD/$( basename "$1" ) )
    fi
}

# _relpath <directory> <filepath>
# - if filepath is reachable from directory, returns the relative path,
#   otherwise returns the full path
_relpath() {
    local d=$( _fullpath "$1" )
    local f=$( _fullpath "$2" )
    echo "${f#$d/}"
}

# tvim [files...]
# - if no existing tvim instance is running, a new one is spawned
# - opens the listed files inside the tvim instance
tvim() {
    _tvim_start
    for file in "$@"; do
        local newfile=$( _relpath "$TDIR" "$file" )
        #echo $TDIR '+' $file '=>' $newfile
        _tvim_send_keys :e space "${newfile// /\\ }" enter
    done
    tmux select-pane -t $TVIM
}
