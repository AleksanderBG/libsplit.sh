#!/bin/bash

ctrl() {
  printf "\\033[%s" "$1"
}

clear-line() {
  ctrl 2K # clear entire current line
  ctrl G # move cursor to the beginning of current line
}

put() {
  printf "%s" "$1"
}

spin() {
  case $1 in
      0)
        echo - ;;
      1)
        echo \\ ;;
      2)
        echo \| ;;
      3)
        echo / ;;
  esac
}

declare -a split_arr=()
declare -a split_cmd_arr=()
declare -a split_log_arr=()
split_tmux_window=
split_description=

split-begin() {
  split_arr=()
  split_cmd_arr=()
  split_log_arr=()
}

split() {
  "$@" &
  split_arr+=($!)
  split_cmd_arr+=("$*")
  split_log_arr+=(/dev/null)
}

split-say-log() {
  local logfile=$1
  mkdir -p "$(dirname "$logfile")"
  shift
  "$@" > "$logfile" 2>&1 &
  split_arr+=($!)
  split_cmd_arr+=("$*")
  split_log_arr+=("$logfile")
  if [[ -z $split_description ]]
  then echo "Started ($!): $*"
  else echo "Started ($!): $split_description"
  fi
}

watch-logs() {
  [[ -z $TMUX ]] && return
  local window
  window=$(tmux new-window -d -P tail -f -n +1 "${split_log_arr[0]}")
  split_tmux_window=$window
  for log in "${split_log_arr[@]:1}"
  do
    tmux split-window -d -h -t "$window" tail -f -n +1 "$log"
  done
  tmux select-layout -t "$window" even-horizontal
  tmux select-window -t "$window"
}

end-watch-logs() {
  tmux kill-window -t "$split_tmux_window"
}

stat-split() {
  local ok=yes
  for i in $(seq 0 $((${#split_arr[@]}-1)))
  do
    local pid="${split_arr[$i]}"
    local cmd="${split_cmd_arr[$i]}"
    wait "$pid"
    local s=$?
    echo "Exit status of ($pid) $cmd: $s"
    if [[ $s != 0 ]]
    then ok=no
    fi
  done
  [[ $ok == yes ]] # set return status
}

split-wait() {
  local spinner=0
  watch-logs
  while :
  do
    clear-line
    put "$(spin "$spinner") "
    (( spinner=(spinner+1)%4 ))
    put "Waiting for:"
    local still_waiting=
    for pid in "${split_arr[@]}"
    do
      if ps -p "$pid" > /dev/null
      then
        put " $pid"
        still_waiting=yes
      fi
    done
    if [[ -n $still_waiting ]]
    then sleep 1
    else break
    fi
  done
  clear-line
  echo "Done."
  end-watch-logs
  stat-split
}
