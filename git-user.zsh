# ============================================================
# Git User Switcher — zsh version
# ============================================================
# Usage: gituser <alias | subcommand>
#
# Account config file: ~/.config/gituser/accounts
#   Format: aliases:name:email:ssh_key_path
#   Example: work,w:John:john@company.com:~/.ssh/work_ed25519
#
# Override config path with environment variable:
#   export GITUSER_CONFIG="/path/to/accounts"
# ============================================================

# ── Config ──────────────────────────────────────────────────

GITUSER_CONFIG="${GITUSER_CONFIG:-$HOME/.config/gituser/accounts}"
GITUSER_PROFILES_DIR="${GITUSER_PROFILES_DIR:-$HOME/.config/gituser/profiles}"

# ── Color helpers ────────────────────────────────────────────

_gu_green()  { printf "\033[32m%s\033[0m" "$*"; }
_gu_yellow() { printf "\033[33m%s\033[0m" "$*"; }
_gu_red()    { printf "\033[31m%s\033[0m" "$*"; }
_gu_bold()   { printf "\033[1m%s\033[0m" "$*"; }
_gu_dim()    { printf "\033[2m%s\033[0m" "$*"; }
_gu_cyan()   { printf "\033[36m%s\033[0m" "$*"; }

# ── Account loading ──────────────────────────────────────────
#
# _GITUSER_MAP:          alias → "name:email:key_path"
# _GITUSER_ACCOUNTS_RAW: raw line list (used for list output)

function _gituser_load() {
  typeset -gA _GITUSER_MAP
  typeset -ga _GITUSER_ACCOUNTS_RAW
  _GITUSER_MAP=()
  _GITUSER_ACCOUNTS_RAW=()

  if [[ ! -f "$GITUSER_CONFIG" ]]; then
    return 1
  fi

  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue

    local raw_aliases="${line%%:*}"
    local rest="${line#*:}"

    # Expand ~ in key_path (last field)
    local key_path="${rest##*:}"
    local name_email="${rest%:*}"
    key_path="${key_path/#\\\~/~}"   # \~ → ~ (normalize if saved incorrectly)
    key_path="${key_path/#\~/$HOME}" # ~ → $HOME
    rest="${name_email}:${key_path}"

    _GITUSER_ACCOUNTS_RAW+=("${raw_aliases}:${rest}")

    # Register each alias in the map
    local alias
    for alias in ${(s:,:)raw_aliases}; do
      alias="${alias// /}"
      _GITUSER_MAP[$alias]="$rest"
    done
  done < "$GITUSER_CONFIG"
}

# ── Internal: switch account ─────────────────────────────────

function _gituser_switch() {
  local name="$1"
  local email="$2"
  local key_path="$3"
  local scope="${4:---global}"   # --global or --local

  if [[ ! -f "$key_path" ]]; then
    echo "$(_gu_red '✗') SSH key not found: $(_gu_yellow "$key_path")"
    echo "  On a new machine? See the 'SSH Key Setup' section in the README."
    return 1
  fi

  git config "$scope" user.name  "$name"
  git config "$scope" user.email "$email"
  git config "$scope" core.sshCommand "ssh -i $key_path"

  if [[ "$scope" == "--global" ]]; then
    unset GIT_SSH_COMMAND
    export GIT_SSH_COMMAND="ssh -i $key_path"
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    ssh-add --apple-use-keychain "$key_path" 2>/dev/null || ssh-add "$key_path" 2>/dev/null
  fi

  local scope_label="global"
  [[ "$scope" == "--local" ]] && scope_label="local (this repo only)"

  echo ""
  echo "$(_gu_green '✔') $(_gu_bold 'Git account switched') $(_gu_dim "[$scope_label]")"
  printf "  %-10s %s\n" "Name:"    "$(_gu_bold "$name")"
  printf "  %-10s %s\n" "Email:"   "$email"
  printf "  %-10s %s\n" "SSH Key:" "$(_gu_dim "$key_path")"
  echo ""
}

# ── Internal: list accounts ──────────────────────────────────

function _gituser_list() {
  _gituser_load

  local current_name current_email
  current_name="$(git config --global user.name 2>/dev/null)"
  current_email="$(git config --global user.email 2>/dev/null)"

  echo ""
  echo "$(_gu_bold ' Git User Accounts')"
  echo "$(_gu_dim '──────────────────────────────────────────────')"

  if [[ ${#_GITUSER_ACCOUNTS_RAW[@]} -eq 0 ]]; then
    echo "  $(_gu_yellow '⚠') No accounts registered."
    echo "  Check $GITUSER_CONFIG or run 'gituser add' to add one."
    echo ""
    return
  fi

  local entry aliases rest name email key_path
  for entry in "${_GITUSER_ACCOUNTS_RAW[@]}"; do
    aliases="${entry%%:*}"
    rest="${entry#*:}"
    name="${rest%%:*}"
    rest="${rest#*:}"
    email="${rest%%:*}"
    key_path="${rest#*:}"

    local marker="  " label
    if [[ "$name" == "$current_name" && "$email" == "$current_email" ]]; then
      marker="$(_gu_green '▶ ')"
      label="$(_gu_bold "$name")"
    else
      label="$name"
    fi

    printf "%s%-20s %s" "$marker" "$label" "$(_gu_dim "$email")"

    if [[ "$name" == "$current_name" && "$email" == "$current_email" ]]; then
      printf "  %s" "$(_gu_cyan '← current')"
    fi
    echo ""
    printf "  %s %s\n" "$(_gu_dim 'aliases:')" "$(_gu_dim "$aliases")"
  done

  echo "$(_gu_dim '──────────────────────────────────────────────')"
  echo ""
}

# ── Internal: print help ─────────────────────────────────────

function _gituser_help() {
  _gituser_load

  echo ""
  echo "$(_gu_bold 'Usage:') gituser <alias | subcommand>"
  echo ""
  echo "$(_gu_bold 'Subcommands:')"
  printf "  %-28s %s\n" "list"                "List all registered accounts"
  printf "  %-28s %s\n" "current"             "Show the current git account"
  printf "  %-28s %s\n" "add"                 "Interactively register an account"
  printf "  %-28s %s\n" "set <alias>"         "Apply account to current repo only (--local)"
  printf "  %-28s %s\n" "ssh-key <a> [path]"  "View or update SSH key path"
  printf "  %-28s %s\n" "rule add <a> <dir>"  "Add auto-switch rule for a directory"
  printf "  %-28s %s\n" "rule list"           "List registered rules"
  printf "  %-28s %s\n" "rule remove <a> <dir>" "Remove a rule"
  printf "  %-28s %s\n" "clone <alias> <url>" "Clone with a specific account"
  printf "  %-28s %s\n" "update"              "git pull the dotfiles repo"
  printf "  %-28s %s\n" "<alias>"             "Switch to the specified account (--global)"
  echo ""

  if [[ ${#_GITUSER_ACCOUNTS_RAW[@]} -gt 0 ]]; then
    echo "$(_gu_bold 'Available accounts:')"
    local entry aliases rest name
    for entry in "${_GITUSER_ACCOUNTS_RAW[@]}"; do
      aliases="${entry%%:*}"
      rest="${entry#*:}"
      name="${rest%%:*}"
      printf "  %-24s → %s\n" "$(_gu_cyan "$aliases")" "$name"
    done
    echo ""
  else
    echo "$(_gu_yellow '⚠') No accounts found in config: $GITUSER_CONFIG"
    echo "  Run 'gituser add' to add an account."
    echo ""
  fi
}

# ── Internal: fzf interactive selection ──────────────────────

function _gituser_fzf() {
  _gituser_load

  if [[ ${#_GITUSER_ACCOUNTS_RAW[@]} -eq 0 ]]; then
    echo "$(_gu_yellow '⚠') No accounts registered. Run 'gituser add' to add one."
    return 1
  fi

  local current_name
  current_name="$(git config --global user.name 2>/dev/null)"

  local options=()
  local entry aliases rest name email key_path mark
  for entry in "${_GITUSER_ACCOUNTS_RAW[@]}"; do
    aliases="${entry%%:*}"
    rest="${entry#*:}"
    name="${rest%%:*}"
    rest="${rest#*:}"
    email="${rest%%:*}"
    key_path="${rest#*:}"
    mark=""
    [[ "$name" == "$current_name" ]] && mark=" ✔"
    options+=("${aliases%%,*}  ${name}  <${email}>${mark}")
  done

  local selected
  selected="$(printf '%s\n' "${options[@]}" | fzf \
    --prompt="  Git User > " \
    --header="Select an account (Enter: switch, Esc: cancel)" \
    --height=40% \
    --reverse \
    --no-info)"

  [[ -z "$selected" ]] && return 0

  local chosen_alias="${selected%% *}"
  _gituser_do "$chosen_alias"
}

# ── Internal: perform switch by alias ────────────────────────

function _gituser_do() {
  local alias_key="$1"
  local scope="${2:---global}"
  _gituser_load

  if [[ -z "${_GITUSER_MAP[$alias_key]}" ]]; then
    echo "$(_gu_red '✗') Unknown alias: '$(_gu_yellow "$alias_key")'"
    _gituser_help
    return 1
  fi

  local entry="${_GITUSER_MAP[$alias_key]}"
  local name="${entry%%:*}"
  local rest="${entry#*:}"
  local email="${rest%%:*}"
  local key_path="${rest#*:}"

  _gituser_switch "$name" "$email" "$key_path" "$scope"
}

# ── Internal: interactive account registration ───────────────

function _gituser_add() {
  echo ""
  echo "$(_gu_bold 'Register account') → $GITUSER_CONFIG"
  echo "$(_gu_dim '──────────────────────────────')"
  echo ""

  local gu_name gu_email gu_key gu_aliases

  printf "  Name $(_gu_dim '(git user.name)'): "
  read -r gu_name
  [[ -z "$gu_name" ]] && echo "$(_gu_red '✗') Name is required." && return 1

  printf "  Email $(_gu_dim '(git user.email)'): "
  read -r gu_email
  [[ -z "$gu_email" ]] && echo "$(_gu_red '✗') Email is required." && return 1

  printf "  SSH key path $(_gu_dim '(e.g. ~/.ssh/work_ed25519)'): "
  read -r gu_key
  gu_key="${gu_key/#\~/$HOME}"
  if [[ ! -f "$gu_key" ]]; then
    echo "$(_gu_yellow '⚠') SSH key not found: $gu_key"
    printf "  Continue anyway? $(_gu_dim '[y/N]'): "
    read -r confirm
    [[ "${confirm:l}" != "y" ]] && echo "Cancelled." && return 0
  fi

  printf "  Aliases $(_gu_dim '(comma-separated, first is display name)'): "
  read -r gu_aliases
  [[ -z "$gu_aliases" ]] && gu_aliases="$gu_name"

  local new_line="${gu_aliases}:${gu_name}:${gu_email}:${gu_key/#$HOME/~}"

  mkdir -p "$(dirname "$GITUSER_CONFIG")"
  echo "$new_line" >> "$GITUSER_CONFIG"

  echo ""
  echo "$(_gu_green '✔') Account added"
  printf "  %-10s %s\n" "Name:"    "$(_gu_bold "$gu_name")"
  printf "  %-10s %s\n" "Email:"   "$gu_email"
  printf "  %-10s %s\n" "Aliases:" "$gu_aliases"
  echo ""
}

# ── Internal: update SSH key path ───────────────────────────

function _gituser_ssh_key() {
  local alias_key="$1"
  local new_key="$2"

  if [[ -z "$alias_key" ]]; then
    echo "$(_gu_bold 'Usage:') gituser ssh-key <alias> [new_path]"
    echo ""
    echo "  Providing only an alias shows the current SSH key path."
    echo "  Providing new_path updates it to that path."
    echo ""
    return 1
  fi

  _gituser_load

  if [[ -z "${_GITUSER_MAP[$alias_key]}" ]]; then
    echo "$(_gu_red '✗') Unknown alias: '$(_gu_yellow "$alias_key")'"
    return 1
  fi

  local entry="${_GITUSER_MAP[$alias_key]}"
  local name="${entry%%:*}"
  local rest="${entry#*:}"
  local email="${rest%%:*}"
  local old_key="${rest#*:}"

  # View path only
  if [[ -z "$new_key" ]]; then
    echo ""
    printf "  %-10s %s\n" "Account:"  "$(_gu_bold "$name") $(_gu_dim "<$email>")"
    printf "  %-10s %s\n" "SSH Key:"  "$old_key"
    if [[ -f "$old_key" ]]; then
      printf "  %-10s %s\n" "Status:" "$(_gu_green 'File exists')"
    else
      printf "  %-10s %s\n" "Status:" "$(_gu_red 'File not found')"
    fi
    echo ""
    return 0
  fi

  # Handle new path
  new_key="${new_key/#\~/$HOME}"
  if [[ ! -f "$new_key" ]]; then
    echo "$(_gu_yellow '⚠') SSH key not found: $new_key"
    printf "  Continue anyway? $(_gu_dim '[y/N]'): "
    read -r confirm
    [[ "${confirm:l}" != "y" ]] && echo "Cancelled." && return 0
  fi

  # Replace SSH key path for the matching account line in the config file
  local old_key_pattern="${old_key/#$HOME/~}"
  local new_key_display="${new_key/#$HOME/~}"

  local tmp_file
  tmp_file="$(mktemp)"
  local matched=false

  while IFS= read -r line; do
    if [[ -z "$line" || "$line" == \#* ]]; then
      echo "$line" >> "$tmp_file"
      continue
    fi

    local line_aliases="${line%%:*}"
    local found=false
    local a
    for a in ${(s:,:)line_aliases}; do
      [[ "${a// /}" == "$alias_key" ]] && found=true && break
    done

    if $found; then
      # Replace only the last field (ssh key path)
      local line_rest="${line%:*}"
      echo "${line_rest}:${new_key_display}" >> "$tmp_file"
      matched=true
    else
      echo "$line" >> "$tmp_file"
    fi
  done < "$GITUSER_CONFIG"

  if ! $matched; then
    rm -f "$tmp_file"
    echo "$(_gu_red '✗') Account not found in config file."
    return 1
  fi

  mv "$tmp_file" "$GITUSER_CONFIG"

  # Also update the includeIf profile if it exists
  local profile_file="$GITUSER_PROFILES_DIR/${alias_key}.gitconfig"
  if [[ -f "$profile_file" ]]; then
    cat > "$profile_file" <<EOF
[user]
    name = $name
    email = $email
[core]
    sshCommand = ssh -i $new_key
EOF
    echo "  $(_gu_dim "Profile updated: $profile_file")"
  fi

  echo ""
  echo "$(_gu_green '✔') SSH key path updated"
  printf "  %-10s %s\n" "Account:" "$(_gu_bold "$name")"
  printf "  %-10s %s\n" "Before:"  "$(_gu_dim "$old_key")"
  printf "  %-10s %s\n" "After:"   "$(_gu_bold "$new_key")"
  echo ""
}

# ── Internal: per-repo local config ──────────────────────────

function _gituser_set() {
  local alias_key="$1"

  if [[ -z "$alias_key" ]]; then
    echo "$(_gu_red '✗') Usage: gituser set <alias>"
    return 1
  fi

  if ! git rev-parse --git-dir &>/dev/null; then
    echo "$(_gu_red '✗') Current directory is not a git repository."
    return 1
  fi

  _gituser_do "$alias_key" "--local"
}

# ── Internal: includeIf rule management ──────────────────────

function _gituser_rule() {
  local subcmd="$1"
  shift

  case "$subcmd" in
    add)    _gituser_rule_add "$@" ;;
    remove) _gituser_rule_remove "$@" ;;
    list)   _gituser_rule_list ;;
    *)
      echo "$(_gu_bold 'Usage:') gituser rule <add|list|remove>"
      echo ""
      printf "  %-28s %s\n" "rule add <alias> <dir>"    "Add an auto-switch rule for a directory"
      printf "  %-28s %s\n" "rule list"                 "List registered rules"
      printf "  %-28s %s\n" "rule remove <alias> <dir>" "Remove a rule"
      echo ""
      ;;
  esac
}

function _gituser_rule_add() {
  local alias_key="$1"
  local target_dir="$2"

  if [[ -z "$alias_key" || -z "$target_dir" ]]; then
    echo "$(_gu_red '✗') Usage: gituser rule add <alias> <directory>"
    return 1
  fi

  _gituser_load

  if [[ -z "${_GITUSER_MAP[$alias_key]}" ]]; then
    echo "$(_gu_red '✗') Unknown alias: '$(_gu_yellow "$alias_key")'"
    return 1
  fi

  local entry="${_GITUSER_MAP[$alias_key]}"
  local name="${entry%%:*}"
  local rest="${entry#*:}"
  local email="${rest%%:*}"
  local key_path="${rest#*:}"

  # Resolve to absolute path and ensure trailing slash
  target_dir="$(cd "$target_dir" 2>/dev/null && pwd || echo "${target_dir/#\~/$HOME}")"
  target_dir="${target_dir%/}/"

  # Create profile file
  mkdir -p "$GITUSER_PROFILES_DIR"
  local profile_file="$GITUSER_PROFILES_DIR/${alias_key}.gitconfig"
  cat > "$profile_file" <<EOF
[user]
    name = $name
    email = $email
[core]
    sshCommand = ssh -i $key_path
EOF

  # Add includeIf block to ~/.gitconfig
  local gitconfig="$HOME/.gitconfig"
  local marker="# gituser:rule:${alias_key}:${target_dir}"

  if grep -qF "$marker" "$gitconfig" 2>/dev/null; then
    echo "$(_gu_yellow '⚠') Rule already exists: $alias_key → $target_dir"
    return 0
  fi

  cat >> "$gitconfig" <<EOF

$marker
[includeIf "gitdir:${target_dir}"]
    path = $profile_file
EOF

  echo ""
  echo "$(_gu_green '✔') Rule added"
  printf "  %-12s %s\n" "Account:"   "$(_gu_bold "$name") $(_gu_dim "<$email>")"
  printf "  %-12s %s\n" "Directory:" "$target_dir"
  printf "  %-12s %s\n" "Profile:"   "$(_gu_dim "$profile_file")"
  echo ""
  echo "  $(_gu_dim "Applies automatically to all git repos under that directory.")"
  echo ""
}

function _gituser_rule_remove() {
  local alias_key="$1"
  local target_dir="$2"

  if [[ -z "$alias_key" ]]; then
    echo "$(_gu_red '✗') Usage: gituser rule remove <alias> [directory]"
    return 1
  fi

  local gitconfig="$HOME/.gitconfig"

  if [[ ! -f "$gitconfig" ]]; then
    echo "$(_gu_yellow '⚠') ~/.gitconfig not found."
    return 1
  fi

  local marker
  if [[ -n "$target_dir" ]]; then
    target_dir="$(cd "$target_dir" 2>/dev/null && pwd || echo "${target_dir/#\~/$HOME}")"
    target_dir="${target_dir%/}/"
    marker="# gituser:rule:${alias_key}:${target_dir}"
  else
    marker="# gituser:rule:${alias_key}:"
  fi

  if ! grep -qF "$marker" "$gitconfig" 2>/dev/null; then
    echo "$(_gu_yellow '⚠') Rule not found: $alias_key"
    return 1
  fi

  local tmp_file
  tmp_file="$(mktemp)"
  awk -v marker="$marker" '
    /^$/ { blank=$0; next }
    $0 ~ marker { skip=3; next }
    skip > 0 { skip--; next }
    blank != "" { print blank; blank="" }
    { print }
  ' "$gitconfig" > "$tmp_file"
  mv "$tmp_file" "$gitconfig"

  echo "$(_gu_green '✔') Rule removed: $alias_key"
  echo ""
}

function _gituser_rule_list() {
  local gitconfig="$HOME/.gitconfig"

  echo ""
  echo "$(_gu_bold ' includeIf Directory Rules')"
  echo "$(_gu_dim '──────────────────────────────────────────────')"

  if [[ ! -f "$gitconfig" ]]; then
    echo "  $(_gu_yellow '⚠') ~/.gitconfig not found."
    echo ""
    return
  fi

  local found=false
  local alias_key target_dir entry name rest email
  while IFS= read -r line; do
    if [[ "$line" =~ '^# gituser:rule:([^:]+):(.+)$' ]]; then
      alias_key="${match[1]}"
      target_dir="${match[2]}"
      _gituser_load
      entry="${_GITUSER_MAP[$alias_key]:-}"
      if [[ -n "$entry" ]]; then
        name="${entry%%:*}"
        rest="${entry#*:}"
        email="${rest%%:*}"
      else
        name="(account not found)"
        email=""
      fi
      printf "  %-30s → %s %s\n" \
        "$(_gu_cyan "$target_dir")" \
        "$(_gu_bold "$name")" \
        "$(_gu_dim "<$email>")"
      found=true
    fi
  done < "$gitconfig"

  if ! $found; then
    echo "  No rules registered."
    echo "  Run 'gituser rule add <alias> <dir>' to add one."
  fi

  echo "$(_gu_dim '──────────────────────────────────────────────')"
  echo ""
}

# ── Internal: clone with a specific account ──────────────────

function _gituser_clone() {
  local alias_key="$1"
  local repo_url="$2"
  shift 2
  local extra_args=("$@")

  if [[ -z "$alias_key" || -z "$repo_url" ]]; then
    echo "$(_gu_red '✗') Usage: gituser clone <alias> <url> [git-clone-options...]"
    return 1
  fi

  _gituser_load

  if [[ -z "${_GITUSER_MAP[$alias_key]}" ]]; then
    echo "$(_gu_red '✗') Unknown alias: '$(_gu_yellow "$alias_key")'"
    return 1
  fi

  local entry="${_GITUSER_MAP[$alias_key]}"
  local name="${entry%%:*}"
  local rest="${entry#*:}"
  local email="${rest%%:*}"
  local key_path="${rest#*:}"

  if [[ ! -f "$key_path" ]]; then
    echo "$(_gu_red '✗') SSH key not found: $key_path"
    return 1
  fi

  echo ""
  echo "$(_gu_bold 'clone') $(_gu_dim "as $name <$email>")"
  echo "  $repo_url"
  echo ""

  GIT_SSH_COMMAND="ssh -i $key_path" git clone "$repo_url" "${extra_args[@]}"
  local clone_status=$?

  if [[ $clone_status -ne 0 ]]; then
    echo "$(_gu_red '✗') Clone failed"
    return $clone_status
  fi

  # Determine the cloned directory name
  local repo_dir
  if [[ ${#extra_args[@]} -gt 0 && "${extra_args[-1]}" != -* ]]; then
    repo_dir="${extra_args[-1]}"
  else
    repo_dir="$(basename "$repo_url" .git)"
  fi

  # Automatically apply local config
  if [[ -d "$repo_dir/.git" ]]; then
    (
      cd "$repo_dir"
      git config --local user.name  "$name"
      git config --local user.email "$email"
      git config --local core.sshCommand "ssh -i $key_path"
    )
    echo ""
    echo "$(_gu_green '✔') Local account configured: $repo_dir"
    printf "  %-10s %s\n" "Name:"  "$(_gu_bold "$name")"
    printf "  %-10s %s\n" "Email:" "$email"
    echo ""
  fi
}

# ── Internal: update dotfiles repo ───────────────────────────

function _gituser_update() {
  if [[ -z "$DOTFILES_DIR" ]]; then
    echo "$(_gu_red '✗') DOTFILES_DIR is not set."
    echo "  Run install.sh first."
    return 1
  fi

  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    echo "$(_gu_red '✗') $DOTFILES_DIR is not a git repository."
    return 1
  fi

  echo ""
  echo "$(_gu_bold 'Update dotfiles')"
  echo "$(_gu_dim '──────────────────────────────')"
  printf "  %-10s %s\n" "Path:" "$(_gu_dim "$DOTFILES_DIR")"
  echo ""

  local pull_output
  pull_output="$(git -C "$DOTFILES_DIR" pull 2>&1)"
  local pull_status=$?

  if [[ $pull_status -ne 0 ]]; then
    echo "$(_gu_red '✗') git pull failed"
    echo "$pull_output" | sed 's/^/  /'
    return $pull_status
  fi

  if echo "$pull_output" | grep -q "Already up to date"; then
    echo "$(_gu_green '✔') Already up to date."
  else
    echo "$(_gu_green '✔') Updated"
    echo "$pull_output" | sed 's/^/  /'
    echo ""
    echo "  $(_gu_dim 'To apply changes:')"
    echo "    source ~/.zshrc"
  fi
  echo ""
}

# ── Main command ─────────────────────────────────────────────

function gituser() {
  case "$1" in
    "")
      if command -v fzf &>/dev/null; then
        _gituser_fzf
      else
        _gituser_help
      fi
      ;;
    list)
      _gituser_list
      ;;
    current|now)
      local name email
      name="$(git config --global user.name 2>/dev/null)"
      email="$(git config --global user.email 2>/dev/null)"
      echo ""
      echo "$(_gu_bold 'Current Git Account (global)')"
      echo "$(_gu_dim '──────────────────────────────')"
      printf "  %-10s %s\n" "Name:"  "$(_gu_bold "${name:-(not set)}")"
      printf "  %-10s %s\n" "Email:" "${email:-(not set)}"
      echo ""
      ;;
    add)
      _gituser_add
      ;;
    set)
      shift
      _gituser_set "$@"
      ;;
    ssh-key)
      shift
      _gituser_ssh_key "$@"
      ;;
    rule)
      shift
      _gituser_rule "$@"
      ;;
    clone)
      shift
      _gituser_clone "$@"
      ;;
    update)
      _gituser_update
      ;;
    help|-h|--help)
      _gituser_help
      ;;
    *)
      _gituser_do "$1"
      ;;
  esac
}
