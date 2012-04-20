tvim_running() { tmux lsp -F '#{pane_id}' | grep -q '^'$TVIM'$'; }

# tvim [number-of-panes]
# - split a new tmux pane and start vim in it
# - the pane id is stored in $TVIM
tvim() {
    if [[ -n $TVIM ]] && tvim_running; then
        # TVIM already exists - try to select that pane
        tmux select-pane -t $TVIM && return

        # If we get here, that pane no longer exists, so fall thru
        # (shouldn't happen)
    fi

    local width=$1
    if [[ -z $width ]]; then
        # /dev/pts/0: 0 [364x89 xterm-color] (utf8)
        #                ^^^ width
        local scwidth=$(tmux lsc -t $TMUX_PANE |\
            egrep -o '[0-9]+x[0-9]+' | cut -d x -f 2 )
        if [[ $scwidth -ge 242 ]]; then
            width=2
        else
            width=1
        fi
    fi

    # Split a new pane, start vim in it, and record the pane index
    local tvim_pane=$(tmux split-window -P -h -l $[ 81 * $width - 1 ] \
                        "exec vim -O$width")

    # Extract just the pane index from session:window.pane
    local tvim_index=$(echo $tvim_pane | cut -d . -f 2)

    # Now convert the pane index into a global persistent id
    # 1: [100x88] [history 0/10000, 0 bytes] %2
    # ^^ index                           id  ^^
    export TDIR="$PWD"
    export TVIM=$(tmux lsp | grep ^${tvim_index}: | grep -o '%[0-9]\+')
}

# invim [keystrokes...]
# - sends keystrokes to the vim instance created by tvim
# - if no vim instance exists, one is created
# - keystroke syntax is the same as tmux send-keys
invim() {
    ( [[ -n $TVIM ]] && tmux send-keys -t $TVIM escape ) || tvim
    tmux send-keys -t $TVIM escape
    tmux send-keys -t $TVIM "$@"
}

# relpath <directory> <filepath>
# - if filepath is reachable from directory, returns the relative path
# - otherwise returns the full path
relpath() {
    perl -MPath::Class=file,dir -E '$f=dir(shift)->absolute;$t=file(shift)->absolute;say $f->subsumes($t)?$t->relative($f):$t' "$@" ;
}

# vi [files...]
# - if no existing tvim instance is running, a new one is spawned
# - opens the listed files inside the tvim instance
unset -f vi
vi() {
    tvim
    for file in "$@"; do
        local newfile=$( relpath "$TDIR" "$file" )
        #echo $TDIR '+' $file '=>' $newfile
        invim :e space "${newfile// /\\ }" enter
    done
    tmux select-pane -t $TVIM
}
