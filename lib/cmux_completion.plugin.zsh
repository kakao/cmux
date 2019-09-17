#!/usr/bin/env zsh
# CMUX interactive command completion for Z Shell

fzf_default_opts="$FZF_DEFAULT_OPTS --no-multi --inline-info --reverse"

# Find the height of the FZF window to display search results
#
# Globals:
#   None
# Arguments:
#   $1 number of lines of search results
# Returns:
#   the height fo the FZF window
cmux::fzf::height() {
  echo $(( $1 + 2 ))
}

# Select the CMUX command
#
# Globals:
#   fzf_default_opts fzf_query_str
# Arguments:
#   None
# Returns:
#   CMUX command
cmux::completion::commands() {
  local cmux_cmds

  cmux_cmds=(
    "${(@f)$(
      cmux |
      sed $'s/\xc2\xa0/ /g' |
      sed '1,/Commands:$/d;/^$/,$d;s/^ *//g'
    )}"
  )

  printf '%s\n' "${cmux_cmds[@]}" |
  FZF_DEFAULT_OPTS="$fzf_default_opts" \
  fzf --header="COMMANDS" \
      --query="$fzf_query_str" \
      --height="$(cmux::fzf::height "${#cmux_cmds[@]}")" |
  awk '{print $1}'
}

# Select the CMUX command option
#
# Globals:
#   current fzf_default_opts comp_words
# Arguments:
#   None
# Returns:
#   CMUX command option
cmux::completion::options() {
  local scmagent_cmd cmux_cmd_opts _comp_words

  if echo "${comp_words[@]}" | grep -E " -h| --help" > /dev/null ; then
    return 0
  fi

  case "${comp_words[2]}" in
    ssh-tmux|tssh)
      # If only one command option can be selected
      [[ $current -gt 3 ]] && return 0
      ;;
    manage-cloudera-scm-agent|scmagent)
      if [[ $current -eq 3 ]]; then
        scmagent_cmd=(
          "${(@f)$(
            cmux "${comp_words[2]}" --help |
            sed '1,/Scmagent commands:$/d;/^$/,$d;s/[^a-z_]/ /g' |
            xargs -n 1
          )}"
        )

        printf '%s\n' "${scmagent_cmd[@]}" |
        FZF_DEFAULT_OPTS="$fzf_default_opts" \
        fzf --header="COMMAND" \
            --query="$fzf_query_str" \
            --height="$(cmux::fzf::height "${#scmagent_cmd[@]}")" |
        awk '{print $1}'
        return 0
      fi
      ;;
  esac

  # Command options
  cmux_cmd_opts=(
    "${(@f)$(
      cmux "${comp_words[2]}" --help |
      sed '1,/Options:$/d;/^$/,$d;s/^ *//g'
    )}"
  )

  if [[ -n $fzf_query_str ]]; then
    _comp_words=(${comp_words[3, -2]})
  else
    _comp_words=(${comp_words[3, -1]})
  fi

  # Remove selected option from command options
  for opt in "${cmux_cmd_opts[@]}"; do
    for comp_word in ${_comp_words[@]}; do
      if echo "$opt" | grep -w -- "$comp_word" > /dev/null; then
        cmux_cmd_opts=(${cmux_cmd_opts#$opt})
      fi
    done
  done

  printf '%s\n' "${cmux_cmd_opts[@]}" |
  FZF_DEFAULT_OPTS="$fzf_default_opts" \
  fzf --header="OPTIONS" \
      --query="$fzf_query_str" \
      --height="$(cmux::fzf::height "${#cmux_cmd_opts[@]}")" |
  awk '{print $2}'
}

# CMUX interactive command completion for Z Shell
#
# Globals:
#   cmux_default_completion
# Arguments:
#   None
# Returns:
#   None
cmux::completion () {
  local token

  # An array containing the words on the command line
  comp_words=(${(z)LBUFFER})

  # The word at which the cursor is positioned
  if [[ $LBUFFER[$CURSOR] == ' ' ]]; then
    current=$(( ${#comp_words[@]} + 1 ))
  else
    current=${#comp_words[@]}
  fi

  # FZF query string
  fzf_query_str="${comp_words[$current]}"

  # If first word on the command line is not 'cmux', use the CMUX default
  # completion or 'expand-or-complete'
  if [[ ${comp_words[1]} != 'cmux' ]]; then
    zle ${cmux_default_completion:-expand-or-complete}
    return
  fi

  # If an index of current typing word is ...
  case $current in
    1) return 0 ;;
    2) token=$(cmux::completion::commands) ;;
    *) token=$(cmux::completion::options) ;;
  esac

  # Remove query string from the command line
  [[ -n $fzf_query_str ]] && comp_words="${comp_words[1, -2]}"

  # Redisplay the command line with new LBUFFER
  [[ -n "$token" ]] && LBUFFER="${comp_words[@]} $token "
  zle redisplay

  typeset -f zle-line-init >/dev/null && zle zle-line-init
}

# Set CMUX default completion as the default zle wiget for '^I'
if [[ -z "$cmux_default_completion" ]]; then
  binding=$(bindkey '^I')
  [[ $binding =~ 'undefined-key' ]] ||
    cmux_default_completion=$binding[(s: :w)2]
  unset binding
fi

zle -N cmux::completion
bindkey '^I' cmux::completion
