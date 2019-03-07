#!/usr/bin/env bash
set -eu

cd "$(dirname "${BASH_SOURCE[0]}")"
CMUX_HOME="$(dirname "$(pwd)")"
LIB_HOME=$CMUX_HOME/lib
BIN_HOME=$CMUX_HOME/bin
DATA_HOME=$CMUX_HOME/data
CONF_HOME=$CMUX_HOME/config
HRI_HOME=$LIB_HOME/hbase-region-inspector
HT_HOME=$LIB_HOME/hbase-tools
CMUX_YAML=$CONF_HOME/cmux.yaml
ACTIVATE=$CMUX_HOME/activate
PROGRESS_OPT=

# Check OS type
os_type () {
  case "$(uname -s)" in
    Darwin)
      echo
      ;;
    Linux)
      echo
      ;;
    *)
      echo 'Not supported OS'
      exit 0
      ;;
  esac
}

# Check version
check_version () {
  _version () {
    echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
  }

  if [ "$(_version "$1")" -ge "$(_version "$2")" ]; then
    return 0
  else
    return 1
  fi
}

# Check prerequisites
check_prerequisites () {
  FZF_YOUR_VER=$(which fzf > /dev/null && fzf --version || echo '0.0.0')
  FZF_BASE_VER='0.16.6'

  RUBY_YOUR_VER=$(which ruby > /dev/null && ruby --version | awk '{print $2}' || echo '0.0')
  RUBY_BASE_VER='2.0'

  TMUX_YOUR_VER=$(which tmux > /dev/null && tmux -V | awk '{print $2}' || echo '0.0')
  TMUX_BASE_VER='2.1'

  WGET_YOUR_VER=$(which wget > /dev/null && wget --version | head -1 | awk '{print $3}' || echo '0.0')
  WGET_BASE_VER='1.12'

  BOXES_YOUR_VER=$(which boxes > /dev/null && boxes -v | awk '{print $3}' || echo '0.0')

  if check_version "$FZF_YOUR_VER" "$FZF_BASE_VER" \
    && check_version "$RUBY_YOUR_VER" "$RUBY_BASE_VER" \
    && check_version "$TMUX_YOUR_VER" "$TMUX_BASE_VER" \
    && check_version "$WGET_YOUR_VER" "$WGET_BASE_VER"; then
    return 0
  fi

  echo "Please check prerequisites:"
  if ! check_version "$FZF_YOUR_VER" "$FZF_BASE_VER"; then
    if [ "$FZF_YOUR_VER" == '0.0' ]; then
      FZF_YOUR_VER='NONE'
    fi
    printf "  [fzf]   You have %-12s => %s or later\n" $FZF_YOUR_VER $FZF_BASE_VER
  fi

  if ! check_version "$RUBY_YOUR_VER" "$RUBY_BASE_VER"; then
    if [ "$RUBY_YOUR_VER" == '0.0' ]; then
      RUBY_YOUR_VER='NONE'
    fi
    printf "  [ruby]  You have %-12s => %s or later\n" $RUBY_YOUR_VER $RUBY_BASE_VER
  fi

  if ! check_version "$TMUX_YOUR_VER" "$TMUX_BASE_VER"; then
    if [ "$TMUX_YOUR_VER" == '0.0' ]; then
      TMUX_YOUR_VER='NONE'
    fi
    printf "  [tmux]  You have %-12s => %s or later\n" $TMUX_YOUR_VER $TMUX_BASE_VER
  fi

  if ! check_version "$WGET_YOUR_VER" "$WGET_BASE_VER"; then
    if [ "$WGET_YOUR_VER" == '0.0' ]; then
      WGET_YOUR_VER='NONE'
    fi
    printf "  [wget]  You have %-12s => recommand %s or later\n" $WGET_YOUR_VER $WGET_BASE_VER
  fi

  if ! check_version "$BOXES_YOUR_VER" '0.0.1'; then
    if [ "$BOXES_YOUR_VER" == '0.0' ]; then
      WGET_YOUR_VER='NONE'
    fi
    printf "  [boxes] You have %-12s => optional\n" $WGET_YOUR_VER
  fi
  exit
}

# Set CMUX.
set_cmux_env () {
  mkdir -p "$DATA_HOME"
  mkdir -p "$CONF_HOME"
  chmod 700 "$BIN_HOME/cmux"

  echo "> Configure your SSH connection."

  while :; do
    if [ -z "${SSH_USER:-}" ]; then
      read -ep $'  Enter SSH user name (ex: user1): ' SSH_USER
      continue
    else
      break
    fi
  done

  read -ep $'  Enter SSH connection options (default option: -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR -t): ' SSH_OPT

  SSH_OPT_DFT="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR -t"
  echo 'ssh:'                              >  "$CMUX_YAML"
  echo "  user: \"$SSH_USER\""             >> "$CMUX_YAML"
  echo "  opt:  \"$SSH_OPT_DFT $SSH_OPT\"" >> "$CMUX_YAML"
  echo
}

# Set progress option accordingly
wget_progress_opt () {
wget --help | grep -q '\--show-progress' && \
  PROGRESS_OPT="-q --show-progress" || PROGRESS_OPT=""
}

# Install hbase_region_inspector.
install_hbase_region_inspector () {
  local HRI="hbase-region-inspector"
  local HRI_VER="0.3.7"
  local HBASE_VERS=("-cdh4" "")
  local BASE_URL="https://github.com/kakao/$HRI"
  local DOWNLOAD_URL="$BASE_URL/releases/download/v$HRI_VER"

  echo "> Install $HRI v$HRI_VER."

  for HBASE_VER in "${HBASE_VERS[@]}"; do
    FILE="$HRI-$HRI_VER$HBASE_VER"
    if [ -e "$HRI_HOME/$FILE" ]; then
      echo "  └─ $FILE is already installed."
    else
      wget $PROGRESS_OPT -P "$HRI_HOME" "$DOWNLOAD_URL/$FILE" &
    fi
  done

  wait

  for HBASE_VER in "${HBASE_VERS[@]}"; do
    FILE="$HRI-$HRI_VER$HBASE_VER"
    if [ -e "$HRI_HOME/$FILE" ]; then
      echo "  └─ $FILE was successfully installed.(*)"
    else
      echo "  └─ $FILE was NOT successfully installed.(*)"
    fi
  done

  if [ -d "$HRI_HOME" ]; then
    find "$HRI_HOME"/* ! -name "hbase-region-inspector-$HRI_VER*" -exec rm {} \;
    chmod 700 "$HRI_HOME"/*
  fi
  echo
}

# Install hbase-tools.
install_hbase_tools () {
  local HT=("hbase-manager" "hbase-table-stat")
  local HT_VER="1.5.3"
  local HBASE_VERS=("0.94" "0.96" "0.98" "1.0" "1.2")
  local BASE_URL="https://github.com/kakao/hbase-tools"
  local DOWNLOAD_URL="$BASE_URL/releases/download/v$HT_VER"

  echo "> Install hbase-tools v$HT_VER."

  for HT in "${HT[@]}"; do
    for HBASE_VER in "${HBASE_VERS[@]}"; do
      FILE="$HT-$HBASE_VER-$HT_VER.jar"
      if [ -e "$HT_HOME/$FILE" ]; then
        echo "  └─ $FILE is already installed."
      else
        wget $PROGRESS_OPT -P "$HT_HOME" "$DOWNLOAD_URL/$FILE" &
      fi
    done
  done

  wait

  for HT in "${HT[@]}"; do
    for HBASE_VER in "${HBASE_VERS[@]}"; do
      FILE="$HT-$HBASE_VER-$HT_VER.jar"
      if [ -e "$HT_HOME/$FILE" ]; then
        echo "  └─ $FILE was successfully installed.(*)"
      else
        echo "  └─ $FILE was NOT successfully installed.(*)"
      fi
    done
  done

  if [ -d "$HT_HOME" ]; then
    find "$HT_HOME"/* ! -name "*$HT_VER.jar" -exec rm {} \;
  fi
  echo
}

run_install () {
  echo "********************"
  echo "*   Install CMUX   *"
  echo "********************"

  os_type
  check_prerequisites
  set_cmux_env
  wget_progress_opt
  install_hbase_region_inspector
  install_hbase_tools

  echo "> Installation completed."
  echo
  echo '                        AFTER THE INSTALLATION'
  echo
  echo '1. Add the following command to your shell configuration file and'
  echo '   reload configuration. Then you should be able to see all commands'
  echo '   of the CMUX by running "cmux"'
  echo
  echo "   source $ACTIVATE"
  echo
  echo '2. Write Cloudera Manager Server list on "cm.yaml".'
  echo
  echo 'See "How to install" on the README.'
  echo
}

run_upgrade () {
  echo "********************"
  echo "*   Update CMUX    *"
  echo "********************"
  echo

  os_type
  check_prerequisites
  wget_progress_opt
  install_hbase_region_inspector
  install_hbase_tools

  echo $'> Upgrade completed.'
}

if [ "${1:-}" = "-u" ]; then
  run_upgrade
else
  run_install
fi
