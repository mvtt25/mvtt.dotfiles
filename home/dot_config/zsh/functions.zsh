# Interactive helpers carried over from the previous ~/.zshrc.

# Fzf-based listening ports
ports() {
  local opener
  if command -v open >/dev/null; then
    opener="open"
  else
    opener="xdg-open"
  fi

  local selection key line pid port

  selection=$(
    lsof -iTCP -sTCP:LISTEN -Pn 2>/dev/null \
    | awk 'NR>1 {
        port = substr($9, match($9, /[^:]*$/))
        printf "%s\t%s\t%s\n", $2, $1, port
      }' \
    | fzf \
        --prompt="Porte in ascolto > " \
        --height=40% \
        --delimiter='\t' \
        --with-nth=2,3 \
        --expect=enter,space
  )

  key=$(echo "$selection" | head -n1)
  line=$(echo "$selection" | sed -n '2p')

  [[ -z "$line" ]] && return

  pid=$(echo "$line" | cut -f1)
  port=$(echo "$line" | cut -f3)

  case "$key" in
    enter)
      kill "$pid"
      ;;
    space)
      "$opener" "http://localhost:$port" >/dev/null 2>&1
      ;;
  esac
}

# y: yazi as a navigator. Quitting leaves the shell in the folder yazi was showing;
# files open in nvim, as in TUIOS's yazi popup. Inside, z jumps with zoxide.
y() {
  local tmp cwd
  tmp=$(mktemp -t yazi-cwd.XXXXXX)
  EDITOR=nvim yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [[ -n $cwd && $cwd != "$PWD" ]] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

# AWS profiles: pick one with fzf and export it for this shell. `awsp --here` ties it to
# the project instead (the repo's root, or this folder): the pair lives in
# ~/.local/state/awsp/projects, outside every repo, so git never sees it. On every cd the
# profile is set inside the project and taken back outside; `awsp --forget` unties the
# project. `awsp <command>` runs one command with the profile. An SSO profile whose
# session expired logs in first, so the prompt only shows a profile that works.
_awsp_projects=~/.local/state/awsp/projects

awsp() {
    local mode=
    [[ $1 == --here || $1 == --forget ]] && { mode=$1; shift; }
    local root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

    if [[ $mode == --forget ]]; then
        [[ -f $_awsp_projects ]] &&
            awk -F '\t' -v r="$root" '$1 != r' "$_awsp_projects" > "$_awsp_projects.new" &&
            mv "$_awsp_projects.new" "$_awsp_projects"
        echo "${root/#$HOME/~}: no AWS profile of its own"
        _awsp_chpwd
        return
    fi

    local profiles=()
    [[ -f ~/.aws/credentials ]] && profiles+=($(grep '^\[' ~/.aws/credentials | tr -d '[]'))
    [[ -f ~/.aws/config ]] && profiles+=($(grep '^\[profile' ~/.aws/config | sed 's/\[profile //' | tr -d ']'))
    profiles=($(echo "${profiles[@]}" | tr ' ' '\n' | sort -u))

    if [[ ${#profiles[@]} -eq 0 ]]; then
        echo "No AWS profiles found."
        return 1
    fi

    local selected
    if command -v fzf &> /dev/null; then
        selected=$(printf '%s\n' "${profiles[@]}" | fzf --prompt="Profilo AWS: " --height=40% --reverse)
    else
        echo "Select profile"
        select p in "${profiles[@]}"; do selected="$p"; break; done
    fi

    [[ -z "$selected" ]] && return 1

    # One call to AWS (about a second): if the profile does not answer and is SSO
    # (sso_session or sso_start_url in its section), log in; any other failure
    # (credentials, network) only warns.
    if ! aws sts get-caller-identity --profile "$selected" >/dev/null 2>&1; then
        local section="[profile $selected]"
        [[ $selected == default ]] && section="[default]"
        if awk -v s="$section" '$0 == s {in_s = 1; next} /^\[/ {in_s = 0}
              in_s && /^sso_(session|start_url)/ {sso = 1} END {exit !sso}' ~/.aws/config 2>/dev/null; then
            aws sso login --profile "$selected" || return 1
        else
            echo "awsp: $selected does not answer: check its credentials or the network" >&2
        fi
    fi

    if [[ $mode == --here ]]; then
        mkdir -p "${_awsp_projects:h}"
        { [[ -f $_awsp_projects ]] && awk -F '\t' -v r="$root" '$1 != r' "$_awsp_projects"
          printf '%s\t%s\n' "$root" "$selected"; } > "$_awsp_projects.new" &&
            mv "$_awsp_projects.new" "$_awsp_projects"
        echo "AWS_PROFILE=$selected inside ${root/#$HOME/~}"
        _awsp_chpwd
    elif [[ $# -gt 0 ]]; then
        echo "[$selected] -> $@"
        AWS_PROFILE="$selected" "$@"
    else
        export AWS_PROFILE="$selected"
        echo "AWS_PROFILE=$selected (session)"
    fi
}

# On every cd: the profile of the project this folder is in (the deepest one), if any.
# Outside, the shell gets back what it had before; a profile exported by hand or with
# plain awsp while inside stays.
_awsp_chpwd() {
    local r p want= want_root=
    [[ -r $_awsp_projects ]] && while IFS=$'\t' read -r r p; do
        [[ ($PWD == "$r" || $PWD == "$r"/*) && ${#r} -gt ${#want_root} ]] && { want=$p want_root=$r; }
    done < "$_awsp_projects"
    if [[ -n $want ]]; then
        [[ -z $_awsp_set || ${AWS_PROFILE-} != "$_awsp_set" ]] && _awsp_before=${AWS_PROFILE-}
        export AWS_PROFILE=$want
        _awsp_set=$want
    elif [[ -n $_awsp_set ]]; then
        if [[ ${AWS_PROFILE-} == "$_awsp_set" ]]; then
            if [[ -n $_awsp_before ]]; then export AWS_PROFILE=$_awsp_before; else unset AWS_PROFILE; fi
        fi
        _awsp_set=
    fi
}
typeset -g _awsp_set= _awsp_before=
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _awsp_chpwd
_awsp_chpwd
