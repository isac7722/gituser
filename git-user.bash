# ============================================================
# Git User Switcher — bash 4+ 호환 버전
# ============================================================
# 사용법: gituser <alias | subcommand>
#
# 계정 설정 파일: ~/.config/gituser/accounts
#   형식: aliases:name:email:ssh_key_path
#   예시: work,w:John:john@company.com:~/.ssh/work_ed25519
#
# 환경변수로 설정 파일 경로 변경 가능:
#   export GITUSER_CONFIG="/path/to/accounts"
# ============================================================

# bash 4+ 필요 (associative array 지원)
if ((BASH_VERSINFO[0] < 4)); then
  echo "gituser: bash 4.0 이상이 필요합니다. (현재: $BASH_VERSION)" >&2
  return 1
fi

# ── 설정 ────────────────────────────────────────────────────

GITUSER_CONFIG="${GITUSER_CONFIG:-$HOME/.config/gituser/accounts}"
GITUSER_PROFILES_DIR="${GITUSER_PROFILES_DIR:-$HOME/.config/gituser/profiles}"

# ── 컬러 헬퍼 ───────────────────────────────────────────────

_gu_green()  { printf "\033[32m%s\033[0m" "$*"; }
_gu_yellow() { printf "\033[33m%s\033[0m" "$*"; }
_gu_red()    { printf "\033[31m%s\033[0m" "$*"; }
_gu_bold()   { printf "\033[1m%s\033[0m" "$*"; }
_gu_dim()    { printf "\033[2m%s\033[0m" "$*"; }
_gu_cyan()   { printf "\033[36m%s\033[0m" "$*"; }

# ── 계정 로딩 ───────────────────────────────────────────────
#
# _GITUSER_MAP:   alias → "name:email:key_path"  (associative array)
# _GITUSER_ACCOUNTS_RAW: 원본 줄 목록 (list 출력용)

function _gituser_load() {
  declare -gA _GITUSER_MAP
  declare -ga _GITUSER_ACCOUNTS_RAW
  _GITUSER_MAP=()
  _GITUSER_ACCOUNTS_RAW=()

  if [[ ! -f "$GITUSER_CONFIG" ]]; then
    return 1
  fi

  while IFS= read -r line; do
    # 빈 줄 / 주석 스킵
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue

    local raw_aliases="${line%%:*}"
    local rest="${line#*:}"

    # ~ 경로 확장 (마지막 필드 key_path)
    local key_path="${rest##*:}"
    local name_email="${rest%:*}"
    key_path="${key_path/#\~/$HOME}"
    rest="${name_email}:${key_path}"

    _GITUSER_ACCOUNTS_RAW+=("${raw_aliases}:${rest}")

    # 각 alias를 맵에 등록 (bash IFS 분리)
    local alias_entry
    IFS=',' read -ra alias_list <<< "$raw_aliases"
    for alias_entry in "${alias_list[@]}"; do
      alias_entry="${alias_entry// /}"  # 공백 제거
      _GITUSER_MAP["$alias_entry"]="$rest"
    done
  done < "$GITUSER_CONFIG"
}

# ── 내부: 계정 전환 ─────────────────────────────────────────

function _gituser_switch() {
  local name="$1"
  local email="$2"
  local key_path="$3"
  local scope="${4:---global}"   # --global or --local

  if [[ ! -f "$key_path" ]]; then
    echo "$(_gu_red '✗') SSH 키를 찾을 수 없습니다: $(_gu_yellow "$key_path")"
    echo "  새 컴퓨터라면 README의 'SSH 키 설정' 섹션을 참고하세요."
    return 1
  fi

  git config "$scope" user.name  "$name"
  git config "$scope" user.email "$email"
  git config "$scope" core.sshCommand "ssh -i $key_path"

  if [[ "$scope" == "--global" ]]; then
    unset GIT_SSH_COMMAND
    export GIT_SSH_COMMAND="ssh -i $key_path"
    ssh-add "$key_path" 2>/dev/null
  fi

  local scope_label="global"
  [[ "$scope" == "--local" ]] && scope_label="local (이 저장소만)"

  echo ""
  echo "$(_gu_green '✔') $(_gu_bold 'Git 계정 전환 완료') $(_gu_dim "[$scope_label]")"
  printf "  %-10s %s\n" "이름:"   "$(_gu_bold "$name")"
  printf "  %-10s %s\n" "이메일:" "$email"
  printf "  %-10s %s\n" "SSH 키:" "$(_gu_dim "$key_path")"
  echo ""
}

# ── 내부: 계정 목록 출력 ────────────────────────────────────

function _gituser_list() {
  _gituser_load

  local current_name current_email
  current_name="$(git config --global user.name 2>/dev/null)"
  current_email="$(git config --global user.email 2>/dev/null)"

  echo ""
  echo "$(_gu_bold ' Git User Accounts')"
  echo "$(_gu_dim '──────────────────────────────────────────────')"

  if [[ ${#_GITUSER_ACCOUNTS_RAW[@]} -eq 0 ]]; then
    echo "  $(_gu_yellow '⚠') 등록된 계정이 없습니다."
    echo "  $GITUSER_CONFIG 파일을 확인하거나 'gituser add'로 추가하세요."
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

# ── 내부: 도움말 출력 ───────────────────────────────────────

function _gituser_help() {
  _gituser_load

  echo ""
  echo "$(_gu_bold 'Usage:') gituser <alias | subcommand>"
  echo ""
  echo "$(_gu_bold 'Subcommands:')"
  printf "  %-18s %s\n" "list"              "등록된 모든 계정 보기"
  printf "  %-18s %s\n" "current"           "현재 git 계정 확인"
  printf "  %-18s %s\n" "add"               "인터랙티브 계정 등록"
  printf "  %-18s %s\n" "set <alias>"       "현재 저장소에만 계정 적용 (--local)"
  printf "  %-18s %s\n" "ssh-key <a> [path]" "SSH 키 경로 조회/변경"
  printf "  %-18s %s\n" "rule <sub>"        "디렉토리 자동 전환 규칙 관리"
  printf "  %-18s %s\n" "clone <alias> <url>" "계정 지정 clone"
  printf "  %-18s %s\n" "update"            "dotfiles repo git pull"
  printf "  %-18s %s\n" "<alias>"           "해당 계정으로 전환 (--global)"
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
    echo "$(_gu_yellow '⚠') 설정 파일에 등록된 계정이 없습니다: $GITUSER_CONFIG"
    echo "  'gituser add' 로 계정을 추가하세요."
    echo ""
  fi
}

# ── 내부: alias로 실제 전환 수행 ────────────────────────────

function _gituser_do() {
  local alias_key="$1"
  local scope="${2:---global}"
  _gituser_load

  if [[ -z "${_GITUSER_MAP[$alias_key]+x}" ]]; then
    echo "$(_gu_red '✗') 알 수 없는 alias: '$(_gu_yellow "$alias_key")'"
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

# ── 내부: 인터랙티브 계정 등록 ──────────────────────────────

function _gituser_add() {
  echo ""
  echo "$(_gu_bold '계정 등록') → $GITUSER_CONFIG"
  echo "$(_gu_dim '──────────────────────────────')"
  echo ""

  local gu_name gu_email gu_key gu_aliases

  printf "  이름 $(_gu_dim '(git user.name)'): "
  read -r gu_name
  [[ -z "$gu_name" ]] && echo "$(_gu_red '✗') 이름을 입력하세요." && return 1

  printf "  이메일 $(_gu_dim '(git user.email)'): "
  read -r gu_email
  [[ -z "$gu_email" ]] && echo "$(_gu_red '✗') 이메일을 입력하세요." && return 1

  printf "  SSH 키 경로 $(_gu_dim '(예: ~/.ssh/work_ed25519)'): "
  read -r gu_key
  gu_key="${gu_key/#\~/$HOME}"
  if [[ ! -f "$gu_key" ]]; then
    echo "$(_gu_yellow '⚠') SSH 키를 찾을 수 없습니다: $gu_key"
    printf "  계속 진행할까요? $(_gu_dim '[y/N]'): "
    read -r confirm
    [[ "${confirm,,}" != "y" ]] && echo "취소됨." && return 0
  fi

  printf "  Aliases $(_gu_dim '(쉼표 구분, 첫 번째가 표시 이름)'): "
  read -r gu_aliases
  [[ -z "$gu_aliases" ]] && gu_aliases="$gu_name"

  local new_line="${gu_aliases}:${gu_name}:${gu_email}:${gu_key/#$HOME/~}"

  mkdir -p "$(dirname "$GITUSER_CONFIG")"
  echo "$new_line" >> "$GITUSER_CONFIG"

  echo ""
  echo "$(_gu_green '✔') 계정 추가 완료"
  printf "  %-10s %s\n" "이름:"    "$(_gu_bold "$gu_name")"
  printf "  %-10s %s\n" "이메일:" "$gu_email"
  printf "  %-10s %s\n" "Aliases:" "$gu_aliases"
  echo ""
}

# ── 내부: SSH 키 경로 변경 ───────────────────────────────────

function _gituser_ssh_key() {
  local alias_key="$1"
  local new_key="$2"

  if [[ -z "$alias_key" ]]; then
    echo "$(_gu_bold 'Usage:') gituser ssh-key <alias> [new_path]"
    echo ""
    echo "  alias만 입력하면 현재 SSH 키 경로를 표시합니다."
    echo "  new_path를 입력하면 해당 경로로 변경합니다."
    echo ""
    return 1
  fi

  _gituser_load

  if [[ -z "${_GITUSER_MAP[$alias_key]+x}" ]]; then
    echo "$(_gu_red '✗') 알 수 없는 alias: '$(_gu_yellow "$alias_key")'"
    return 1
  fi

  local entry="${_GITUSER_MAP[$alias_key]}"
  local name="${entry%%:*}"
  local rest="${entry#*:}"
  local email="${rest%%:*}"
  local old_key="${rest#*:}"

  # 경로만 조회
  if [[ -z "$new_key" ]]; then
    echo ""
    printf "  %-10s %s\n" "계정:"    "$(_gu_bold "$name") $(_gu_dim "<$email>")"
    printf "  %-10s %s\n" "SSH 키:" "$old_key"
    if [[ -f "$old_key" ]]; then
      printf "  %-10s %s\n" "상태:" "$(_gu_green '파일 존재')"
    else
      printf "  %-10s %s\n" "상태:" "$(_gu_red '파일 없음')"
    fi
    echo ""
    return 0
  fi

  # 새 경로 처리
  new_key="${new_key/#\~/$HOME}"
  if [[ ! -f "$new_key" ]]; then
    echo "$(_gu_yellow '⚠') SSH 키를 찾을 수 없습니다: $new_key"
    printf "  계속 진행할까요? $(_gu_dim '[y/N]'): "
    read -r confirm
    [[ "${confirm,,}" != "y" ]] && echo "취소됨." && return 0
  fi

  # 설정 파일에서 해당 계정 줄의 SSH 키 경로 교체
  local old_key_pattern="${old_key/#$HOME/~}"
  local new_key_display="${new_key/#$HOME/~}"

  local tmp_file
  tmp_file="$(mktemp)"
  local matched=false

  while IFS= read -r line; do
    if [[ -z "$line" || "${line:0:1}" == "#" ]]; then
      echo "$line" >> "$tmp_file"
      continue
    fi

    local line_aliases="${line%%:*}"
    local found=false
    IFS=',' read -ra check_list <<< "$line_aliases"
    local a
    for a in "${check_list[@]}"; do
      [[ "${a// /}" == "$alias_key" ]] && found=true && break
    done

    if $found; then
      local line_rest="${line%:*}"
      echo "${line_rest}:${new_key_display}" >> "$tmp_file"
      matched=true
    else
      echo "$line" >> "$tmp_file"
    fi
  done < "$GITUSER_CONFIG"

  if ! $matched; then
    rm -f "$tmp_file"
    echo "$(_gu_red '✗') 설정 파일에서 계정을 찾을 수 없습니다."
    return 1
  fi

  mv "$tmp_file" "$GITUSER_CONFIG"

  # includeIf 프로파일이 있으면 함께 갱신
  local profile_file="$GITUSER_PROFILES_DIR/${alias_key}.gitconfig"
  if [[ -f "$profile_file" ]]; then
    cat > "$profile_file" <<EOF
[user]
    name = $name
    email = $email
[core]
    sshCommand = ssh -i $new_key
EOF
    echo "  $(_gu_dim "프로파일 갱신: $profile_file")"
  fi

  echo ""
  echo "$(_gu_green '✔') SSH 키 경로 변경 완료"
  printf "  %-10s %s\n" "계정:"   "$(_gu_bold "$name")"
  printf "  %-10s %s\n" "이전:"   "$(_gu_dim "$old_key")"
  printf "  %-10s %s\n" "변경:"   "$(_gu_bold "$new_key")"
  echo ""
}

# ── 내부: per-repo 로컬 설정 ────────────────────────────────

function _gituser_set() {
  local alias_key="$1"

  if [[ -z "$alias_key" ]]; then
    echo "$(_gu_red '✗') 사용법: gituser set <alias>"
    return 1
  fi

  if ! git rev-parse --git-dir &>/dev/null; then
    echo "$(_gu_red '✗') 현재 디렉토리가 git 저장소가 아닙니다."
    return 1
  fi

  _gituser_do "$alias_key" "--local"
}

# ── 내부: includeIf 규칙 관리 ───────────────────────────────

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
      printf "  %-26s %s\n" "rule add <alias> <dir>"    "디렉토리에 계정 규칙 추가"
      printf "  %-26s %s\n" "rule list"                 "등록된 규칙 목록 보기"
      printf "  %-26s %s\n" "rule remove <alias> <dir>" "규칙 제거"
      echo ""
      ;;
  esac
}

function _gituser_rule_add() {
  local alias_key="$1"
  local target_dir="$2"

  if [[ -z "$alias_key" || -z "$target_dir" ]]; then
    echo "$(_gu_red '✗') 사용법: gituser rule add <alias> <directory>"
    return 1
  fi

  _gituser_load

  if [[ -z "${_GITUSER_MAP[$alias_key]+x}" ]]; then
    echo "$(_gu_red '✗') 알 수 없는 alias: '$(_gu_yellow "$alias_key")'"
    return 1
  fi

  local entry="${_GITUSER_MAP[$alias_key]}"
  local name="${entry%%:*}"
  local rest="${entry#*:}"
  local email="${rest%%:*}"
  local key_path="${rest#*:}"

  # 절대 경로 변환 + trailing slash 보장
  target_dir="$(cd "$target_dir" 2>/dev/null && pwd || echo "${target_dir/#\~/$HOME}")"
  target_dir="${target_dir%/}/"

  # 프로파일 파일 생성
  mkdir -p "$GITUSER_PROFILES_DIR"
  local profile_file="$GITUSER_PROFILES_DIR/${alias_key}.gitconfig"
  cat > "$profile_file" <<EOF
[user]
    name = $name
    email = $email
[core]
    sshCommand = ssh -i $key_path
EOF

  # ~/.gitconfig에 includeIf 추가
  local gitconfig="$HOME/.gitconfig"
  local marker="# gituser:rule:${alias_key}:${target_dir}"

  if grep -qF "$marker" "$gitconfig" 2>/dev/null; then
    echo "$(_gu_yellow '⚠') 이미 동일한 규칙이 있습니다: $alias_key → $target_dir"
    return 0
  fi

  cat >> "$gitconfig" <<EOF

$marker
[includeIf "gitdir:${target_dir}"]
    path = $profile_file
EOF

  echo ""
  echo "$(_gu_green '✔') 규칙 추가 완료"
  printf "  %-10s %s\n" "계정:"    "$(_gu_bold "$name") $(_gu_dim "<$email>")"
  printf "  %-10s %s\n" "디렉토리:" "$target_dir"
  printf "  %-10s %s\n" "프로파일:" "$(_gu_dim "$profile_file")"
  echo ""
  echo "  $(_gu_dim "해당 디렉토리 내 모든 git 저장소에 자동 적용됩니다.")"
  echo ""
}

function _gituser_rule_remove() {
  local alias_key="$1"
  local target_dir="$2"

  if [[ -z "$alias_key" ]]; then
    echo "$(_gu_red '✗') 사용법: gituser rule remove <alias> [directory]"
    return 1
  fi

  local gitconfig="$HOME/.gitconfig"

  if [[ ! -f "$gitconfig" ]]; then
    echo "$(_gu_yellow '⚠') ~/.gitconfig 파일이 없습니다."
    return 1
  fi

  if [[ -n "$target_dir" ]]; then
    target_dir="$(cd "$target_dir" 2>/dev/null && pwd || echo "${target_dir/#\~/$HOME}")"
    target_dir="${target_dir%/}/"
    local marker="# gituser:rule:${alias_key}:${target_dir}"
  else
    local marker="# gituser:rule:${alias_key}:"
  fi

  if ! grep -qF "$marker" "$gitconfig" 2>/dev/null; then
    echo "$(_gu_yellow '⚠') 해당 규칙을 찾을 수 없습니다: $alias_key"
    return 1
  fi

  # 마커 라인 + 다음 2줄(includeIf 블록) 제거
  # 빈 줄 포함하여 4줄 제거
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

  echo "$(_gu_green '✔') 규칙 제거 완료: $alias_key"
  echo ""
}

function _gituser_rule_list() {
  local gitconfig="$HOME/.gitconfig"

  echo ""
  echo "$(_gu_bold ' includeIf 디렉토리 규칙')"
  echo "$(_gu_dim '──────────────────────────────────────────────')"

  if [[ ! -f "$gitconfig" ]]; then
    echo "  $(_gu_yellow '⚠') ~/.gitconfig 파일이 없습니다."
    echo ""
    return
  fi

  local found=false
  local alias_key target_dir
  while IFS= read -r line; do
    if [[ "$line" =~ ^#\ gituser:rule:([^:]+):(.+)$ ]]; then
      alias_key="${BASH_REMATCH[1]}"
      target_dir="${BASH_REMATCH[2]}"
      _gituser_load
      local entry="${_GITUSER_MAP[$alias_key]:-}"
      local name email
      if [[ -n "$entry" ]]; then
        name="${entry%%:*}"
        rest="${entry#*:}"
        email="${rest%%:*}"
      else
        name="(계정 없음)"
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
    echo "  등록된 규칙이 없습니다."
    echo "  'gituser rule add <alias> <dir>' 로 추가하세요."
  fi

  echo "$(_gu_dim '──────────────────────────────────────────────')"
  echo ""
}

# ── 내부: 계정 지정 clone ───────────────────────────────────

function _gituser_clone() {
  local alias_key="$1"
  local repo_url="$2"
  shift 2
  local extra_args=("$@")

  if [[ -z "$alias_key" || -z "$repo_url" ]]; then
    echo "$(_gu_red '✗') 사용법: gituser clone <alias> <url> [git-clone-options...]"
    return 1
  fi

  _gituser_load

  if [[ -z "${_GITUSER_MAP[$alias_key]+x}" ]]; then
    echo "$(_gu_red '✗') 알 수 없는 alias: '$(_gu_yellow "$alias_key")'"
    return 1
  fi

  local entry="${_GITUSER_MAP[$alias_key]}"
  local name="${entry%%:*}"
  local rest="${entry#*:}"
  local email="${rest%%:*}"
  local key_path="${rest#*:}"

  if [[ ! -f "$key_path" ]]; then
    echo "$(_gu_red '✗') SSH 키를 찾을 수 없습니다: $key_path"
    return 1
  fi

  echo ""
  echo "$(_gu_bold 'clone') $(_gu_dim "as $name <$email>")"
  echo "  $repo_url"
  echo ""

  GIT_SSH_COMMAND="ssh -i $key_path" git clone "$repo_url" "${extra_args[@]}"
  local clone_status=$?

  if [[ $clone_status -ne 0 ]]; then
    echo "$(_gu_red '✗') clone 실패"
    return $clone_status
  fi

  # clone된 디렉토리 이름 추출
  local repo_dir
  # extra_args 마지막 인자가 있으면 그게 target dir일 수 있음
  if [[ ${#extra_args[@]} -gt 0 && "${extra_args[-1]}" != -* ]]; then
    repo_dir="${extra_args[-1]}"
  else
    repo_dir="$(basename "$repo_url" .git)"
  fi

  # 로컬 설정 자동 적용
  if [[ -d "$repo_dir/.git" ]]; then
    (
      cd "$repo_dir"
      git config --local user.name  "$name"
      git config --local user.email "$email"
      git config --local core.sshCommand "ssh -i $key_path"
    )
    echo ""
    echo "$(_gu_green '✔') 로컬 계정 설정 완료: $repo_dir"
    printf "  %-10s %s\n" "이름:"   "$(_gu_bold "$name")"
    printf "  %-10s %s\n" "이메일:" "$email"
    echo ""
  fi
}

# ── 내부: dotfiles repo 업데이트 ────────────────────────────

function _gituser_update() {
  if [[ -z "$DOTFILES_DIR" ]]; then
    echo "$(_gu_red '✗') DOTFILES_DIR 변수가 설정되지 않았습니다."
    echo "  install.sh를 먼저 실행하세요."
    return 1
  fi

  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    echo "$(_gu_red '✗') $DOTFILES_DIR 가 git 저장소가 아닙니다."
    return 1
  fi

  echo ""
  echo "$(_gu_bold 'dotfiles 업데이트')"
  echo "$(_gu_dim '──────────────────────────────')"
  printf "  %-10s %s\n" "경로:" "$(_gu_dim "$DOTFILES_DIR")"
  echo ""

  local pull_output
  pull_output="$(git -C "$DOTFILES_DIR" pull 2>&1)"
  local pull_status=$?

  if [[ $pull_status -ne 0 ]]; then
    echo "$(_gu_red '✗') git pull 실패"
    echo "$pull_output" | sed 's/^/  /'
    return $pull_status
  fi

  if echo "$pull_output" | grep -q "Already up to date"; then
    echo "$(_gu_green '✔') 이미 최신 상태입니다."
  else
    echo "$(_gu_green '✔') 업데이트 완료"
    echo "$pull_output" | sed 's/^/  /'
    echo ""
    echo "  $(_gu_dim '변경사항을 적용하려면:')"
    echo "    source ~/.bashrc"
  fi
  echo ""
}

# ── 메인 커맨드 ─────────────────────────────────────────────

function gituser() {
  case "$1" in
    "")
      _gituser_help
      ;;
    list)
      _gituser_list
      ;;
    current|now)
      local name email
      name="$(git config --global user.name 2>/dev/null)"
      email="$(git config --global user.email 2>/dev/null)"
      echo ""
      echo "$(_gu_bold '현재 Git 계정 (global)')"
      echo "$(_gu_dim '──────────────────────────────')"
      printf "  %-10s %s\n" "이름:"   "$(_gu_bold "${name:-설정 없음}")"
      printf "  %-10s %s\n" "이메일:" "${email:-설정 없음}"
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
