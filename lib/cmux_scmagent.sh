#! /usr/bin/env bash
set -eu

is_rhel7() {
  uname -a | grep '.el7' > /dev/null
}

run_cmd() {
  sudo -i service cloudera-scm-agent $1 > /dev/null
}

status() {
  sudo -i service cloudera-scm-agent status
}

process() {
  if is_rhel7; then
    case $1 in
      clean_start)    run_cmd next_start_clean
                      run_cmd start
      ;;
      clean_restart)  run_cmd next_start_clean
                      run_cmd restart
      ;;
      hard_stop)      run_cmd next_stop_hard
                      run_cmd stop
      ;;
      hard_restart)   run_cmd next_stop_hard
                      run_cmd restart
      ;;
      status)
      ;;
      *)              run_cmd $1
      ;;
    esac
  else
    case $1 in
      hard_stop)      run_cmd hard_stop_confirmed
      ;;
      hart_restart)   run_cmd hard_restart_confirmed
      ;;
      clean_restart)  run_cmd clean_restart_confirmed
      ;;
      status)
      ;;
      *)              run_cmd $1
      ;;
    esac
  fi
  status
}

process $1
