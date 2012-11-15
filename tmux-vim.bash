#!/bin/bash

#------------------------------------------------------------------------------
# tmux-vim
#
# Persistent vim panes within tmux.
#
# Usage:
#
#   tmux-vim [file [files...]]
#
# Configuration:
#
#   TMUX_VIM_CONFIG   - path to config file (default ~/.tmux-vim.conf)
#   TMUX_VIM_VIM_ARGS - command-line args to pass to vim (default none)
#   TMUX_VIM_VIM_BIN  - executable to use for vim (default vim)
#   TMUX_VIM_TMUX_BIN - executable to use for tmux (default tmux)
#   TMUX_VIM_LAYOUT   - layout options (default mode:shell,orient:horiz,width:132)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Copyright (c) 2012, Stephen Thirlwall
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# * Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
# * The name of Stephen Thirlwall may not be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL STEPHEN THIRLWALL BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#------------------------------------------------------------------------------

# Set these once and for all - they won't change

tmux=${TMUX_VIM_TMUX_BIN:-tmux}

tmux_window_id=$( $tmux lsp -a -F '#{pane_id}=#{window_index}' |\
                    grep ^$TMUX_PANE= | cut -d= -f2 )

_die() {
    echo "$@" 1>&2
    exit 1
}

# _parse_config cfg key default
# - Given a $cfg like key1:value1,key2:value2,key3:value3
#   returns the value matching $key, defaulting to $default
_parse_config() {
    local cfg="$1"
    local key=$2
    local default=$3

    # 1. add a comma at the start and end to avoid special cases
    # 2. sed strips from the start up to our value (or leaves string intact)
    # 3. cut strips from the first comma to the end, leaving our value (or '')
    local value=$( echo ,$cfg, | sed -E 's/^.*,'$key'://' | cut -d, -f 1 )
    echo ${value:-$default}
}

_percent() {
    local percent=$1
    local value=$2

    percent=${percent/\%/} # strip the percent sign
    echo $[ $percent * $value / 100 ]
}

_layout_option() {
    _parse_config "$TMUX_VIM_LAYOUT" "$@"
}

# _tmux_fetch_or_store key [value]
# - appends window id to key so this is a per-window setting
# - if value supplied, stores key=value, otherwise retrieves it
# - many thanks to Romain Francoise for help with this!
_tmux_fetch_or_store() {
    local key="${1}_$tmux_window_id"
    if [[ $# -gt 1 ]]; then
        $tmux set-environment $key "$2"
    else
        $tmux show-environment | grep "^$key=" | cut -d= -f2-
    fi
}

# _tmux_pane_size width|height
# - gets height or width of current pane
_tmux_pane_size() {
    $tmux lsp -F "#{pane_id}=#{pane_$1}" | grep ^$TMUX_PANE= | cut -d= -f2
}

# _vim_pane_id [id]
# - fetch or store the id for the vim pane
_vim_pane_id() {
    _tmux_fetch_or_store tmux_vim_pane "$@"
}

_vim_cwd() {
    local vim_pane_id=$( _vim_pane_id )
    local vim_pid=$( tmux lsp -F '#{pane_id}=#{pane_pid}' |\
                     grep ^$vim_pane_id= | cut -d= -f2 )

    lsof -p $vim_pid -a -d cwd -Fn | grep ^n | cut -c 2-
}

# _vim_send_keys [keystrokes...]
# - sends keystrokes to the vim instance created by tmux_vim
# - keystroke syntax is the same as tmux send-keys
_vim_send_keys() {
    $tmux send-keys -t $( _vim_pane_id ) "$@"
}

_tmux_is_running() {
    local pane_id=$( _vim_pane_id )
    [[ -n $pane_id ]] && $tmux lsp -F '#{pane_id}' | grep -q ^$pane_id$
}

# _tmux_version
# - return the current tmux version
# - only works for tmux >= 1.5 (but we already checked that)
_tmux_version() {
    $tmux -V | cut -d' ' -f2
}

# _pre_flight_checks
# - make sure all requirements are okay before continuing
_pre_flight_checks() {
    # Check that tmux is actually running
    if [[ -z "$TMUX" ]]; then
        _die tmux session not detected
    fi

    # Check that tmux supports the -V command (>= v1.5)
    if ! $tmux -V 1>/dev/null 2>/dev/null ; then
        _die tmux 1.6 or greater is required
    fi

    # Check tmux is v1.6 or greater
    if [[ $( _tmux_version ) < 1.6 ]]; then
        _die tmux 1.6 or greater is required
    fi

    return 0
}

# _munge_filename <string>
# - workaround for missing -l flag to tmux send-keys in v1.5
# - converts filename to f i l e n a m e (so that files that look like tmux key
#   names are not interpreted as key codes)
# - spaces in the filename are converted to "\ space"
_munge_filename() {
    # Note that we double-escape the backslashes, once for sed, again for
    # passing it out to tmux.
    echo $@ | sed -e 's/./& /g' | sed -e "s/  / \\\\ space/g"
}

# _vim_op <op> <file>
# - does _vim_send_keys :$op space $file
# - escapes spaces correctly in $file
_vim_op() {
    # Backslash escape all spaces in the file name
    _vim_send_keys :$1 space $( _munge_filename "$2" ) enter
}

# _vim_start <files>
# - spawns a new vim instance if necessary
# - returns 1 if vim is already running, 0 if a new instance was started
_vim_start() {
    if _tmux_is_running; then
        # tmux_vim already exists - try to select that pane
        $tmux select-pane -t $( _vim_pane_id ) && return 1

        # If we get here, that pane no longer exists, so fall thru
        # (shouldn't happen)
    fi

    local vim_args=$TMUX_VIM_VIM_ARGS

    #   +----------------+--------:--------+
    #   |                #        :        |
    #   |   shell        # vim 0  : vim 1  |
    #   |                #        :        |
    #   +----------------+--------:--------+
    #    |----- sw -----| |- vw -| |- vw -|
    #                     |----- ss ------|
    #    |------------- ww ---------------|
    #
    # ww = window width
    # sw = shell width
    # vw = vim width
    # vc = vim sub-window count
    # ss = split size (actual tmux param)
    #
    # ww = sw + (vc * (vw + 1))
    # sw = ww - (vc * (vw + 1))
    # vw = ((ww - sw) / vc) - 1
    # vc = (ww - sw) / (vw + 1)
    #
    # ss = ww - sw - 1
    #    = vc * (vw + 1) - 1
    #
    # Note:
    #   1 column border between shell & vim
    #   1 column border between vim sub-windows

    local layout_pos=$( _layout_option vim-pos right )
    local layout_mode=$( _layout_option mode shell )
    case $layout_mode in

    shell)

        # Handle the horizontal/vertical differences
        if [[ $layout_pos == left || $layout_pos == right ]]; then
            local win=$( _tmux_pane_size width )
            local shell=$( _layout_option size 132 )
            local split_method='h'
        else
            local win=$( _tmux_pane_size height )
            local shell=$( _layout_option size 15 )
            local split_method='v'
        fi

        # Convert size from percentage if necessary
        if [[ ${shell: -1:1} == '%' ]]; then
            shell=$( _percent $shell $win )
        fi

        # Handle the pane swapping
        if [[ $layout_pos == left || $layout_pos == top ]]; then
            local split_size=$[ $shell ]
            local do_swap=1
        else
            local split_size=$[ $win - $shell - 1 ]
        fi
        ;;

    vim)

        # Handle the horizontal/vertical differences
        if [[ $layout_pos == left || $layout_pos == right ]]; then
            local win=$( _tmux_pane_size width )
            local vim=$( _layout_option size 80 )
            local shell=$( _layout_option reserve 132 )
            local split_method='h'
            local window_method='O'
        else
            local win=$( _tmux_pane_size height )
            local vim=$( _layout_option size 24 )
            local shell=$( _layout_option reserve 15 )
            local split_method='v'
            local window_method='o'
        fi

        # Convert size from percentage if necessary
        if [[ ${vim: -1:1} == '%' ]]; then
            vim=$( _percent $vim $win )
        fi

        # Factor in the vim sub-window count
        local count=$( _layout_option count 1 )
        if [[ $count == 'auto' ]]; then
            count=$[ ($win - $shell) / ($vim + 1) ]
            [[ $count < 1 ]] && count=1
        fi
        vim=$[ ($vim + 1) * $count - 1 ]

        # Handle the pane swapping
        if [[ $layout_pos == left || $layout_pos == top ]]; then
            local split_size=$[ $win - $vim - 1 ]
            local do_swap=1
        else
            local split_size=$[ $vim ]
        fi

        # Vim sub-window autosplitting
        local autosplit=$( _layout_option autosplit '' )
        [[ $autosplit > 0 ]] && vim_args+=" -$window_method$count"
        ;;

    *)
        _die Unknown TMUX_VIM_LAYOUT:mode "$layout_args"
        ;;

    esac

    local vim_bin=${TMUX_VIM_VIM_BIN:-vim}

    if [[ $# -gt 0 ]]; then
        # Add any files to the vim command-line. When autosplit is enabled,
        # this means we get a different file in each pane.
        local vim_files=$( printf '%q ' "$@" )
    fi

    # Split a new pane, start vim in it, and record the pane index
    local tmux_vim_pane=$( $tmux split-window -P -$split_method -l $split_size \
                        "exec $vim_bin $vim_args $vim_files" )

    # Now convert the pane index into a global persistent id
    # 0:1.1: [100x88] [history 0/10000, 0 bytes] %2
    # ^^^^^ $tmux_vim_pane              pane_id  ^^
    _vim_pane_id $( $tmux lsp -a | grep ^$tmux_vim_pane: | grep -o '%[0-9]\+' )

    # Swap the panes if necessary. tmux only does right/bottom
    [[ $do_swap == 1 ]] && $tmux swap-pane -D

    return 0
}

# tmux_vim [files...]
# - if no existing tmux_vim instance is running, a new one is spawned
# - opens the listed files inside the tmux_vim instance
tmux_vim() {
    local rcfile=${TMUX_VIM_CONFIG:-"$HOME/.tmux-vim.conf"}
    [[ -f "$rcfile" ]] && source "$rcfile"

    _pre_flight_checks || exit 1

    if ( ! _vim_start "$@" ) && [[ $# -gt 0 ]]; then

        _vim_send_keys escape  # make sure we're in command mode

        # If we are now in a different directory than $TDIR, we want to make
        # vim switch to this directory temporarily before opening the files.
        # This obviates any relative path computations.
        local vim_cwd=$( _vim_cwd )
        [[ "$PWD" != "$vim_cwd" ]] && _vim_op cd "$PWD"

        # Rather than :edit each file in turn, use :badd for all but the last
        # file, and then use :edit on that.
        # This is to handle the situation where the current buffer is unsaved,
        # and an :edit command will cause vim to prompt the user to save,
        # abandon or cancel.
        # If we just :edit each file, things just don't work out naturally;
        # cancel works, but yes/no end up with only the first file opened.
        # Errant escape keys cause the whole open to just silently fail.
        # This approach pushes the user interaction right to the end.
        while [[ $# -gt 1 ]]; do
            _vim_op badd "$1"
            shift
        done

        _vim_op edit "$1"

        [[ "$PWD" != "$vim_cwd" ]] && _vim_op cd -
    fi

    $tmux select-pane -t $( _vim_pane_id )
}

tmux_vim "$@"

