# ============================================================
# Git User Switcher
# ============================================================
# 사용법: gituser <alias>
#
# 계정 설정 파일: ~/.config/gituser/accounts
#   형식: aliases:name:email:ssh_key_path
#   예시: work,w:John:john@company.com:~/.ssh/work_ed25519
#
# 환경변수로 설정 파일 경로 변경 가능:
#   export GITUSER_CONFIG="/path/to/accounts"
# ============================================================

# ── 설정 ────────────────────────────────────────────────────

GITUSER_CONFIG="${GITUSER_CONFIG:-$HOME/.config/gituser/accounts}"

# ── 컬러 헬퍼 ───────────────────────────────────────────────

_gu_green()  { printf "\033[32m%s\033[0m" "$*"; }
_gu_yellow() { printf "\033[33m%s\033[0m" "$*"; }
_gu_red()    { printf "\033[31m%s\033[0m" "$*"; }
_gu_bold()   { printf "\033[1m%s\033[0m" "$*"; }
_gu_dim()    { printf "\033[2m%s\033[0m" "$*"; }
_gu_cyan()   { printf "\033[36m%s\033[0m" "$*"; }

# ── 계정 로딩 ───────────────────────────────────────────────
#
# _GITUSER_MAP: alias → "name:email:key_path"
# _GITUSER_ACCOUNTS_RAW: 원본 줄 목록 (list 출력용)

function _gituser_load() {
  typeset -gA _GITUSER_MAP
  typeset -ga _GITUSER_ACCOUNTS_RAW
  _GITUSER_MAP=()
  _GITUSER_ACCOUNTS_RAW=()

  if [[ ! -f "$GITUSER_CONFIG" ]]; then
    return 1
  fi

  while IFS= read -r line; do
    # 빈 줄 / 주석 스킵
    [[ -z "$line" || "$line" == \#* ]] && continue

    local raw_aliases="${line%%:*}"
    local rest="${line#*:}"

    # ~ 경로 확장 (마지막 필드 key_path)
    local key_path="${rest##*:}"
    local name_email="${rest%:*}"
    key_path="${key_path/#\~/$HOME}"
    rest="${name_email}:${key_path}"

    _GITUSER_ACCOUNTS_RAW+=("${raw_aliases}:${rest}")

    # 각 alias를 맵에 등록
    local alias
    for alias in ${(s:,:)raw_aliases}; do
      alias="${alias// /}"  # 공백 제거
      _GITUSER_MAP[$alias]="$rest"
    done
  done < "$GITUSER_CONFIG"
}

# ── 내부: 계정 전환 ─────────────────────────────────────────

function _gituser_switch() {
  local name="$1"
  local email="$2"
  local key_path="$3"

  if [[ ! -f "$key_path" ]]; then
    echo "$(_gu_red '✗') SSH 키를 찾을 수 없습니다: $(_gu_yellow "$key_path")"
    echo "  새 컴퓨터라면 README의 'SSH 키 설정' 섹션을 참고하세요."
    return 1
  fi

  git config --global user.name  "$name"
  git config --global user.email "$email"

  unset GIT_SSH_COMMAND
  export GIT_SSH_COMMAND="ssh -i $key_path"

  eval "$(ssh-agent -s)" > /dev/null 2>&1
  ssh-add --apple-use-keychain "$key_path" 2>/dev/null || ssh-add "$key_path" 2>/dev/null

  echo ""
  echo "$(_gu_green '✔') $(_gu_bold 'Git 계정 전환 완료')"
  printf "  %-10s %s\n" "이름:"   "$(_gu_bold "$name")"
  printf "  %-10s %s\n" "이메일:" "$email"
  printf "  %-10s %s\n" "SSH 키:" "$(_gu_dim "$key_path")"
  echo ""
}

# ── 내부: 계정 목록 출력 ────────────────────────────────────

function _gituser_list() {
  _gituser_load

  local current_name
  current_name="$(git config --global user.name 2>/dev/null)"
  local current_email
  current_email="$(git config --global user.email 2>/dev/null)"

  echo ""
  echo "$(_gu_bold ' Git User Accounts')"
  echo "$(_gu_dim '──────────────────────────────────────────────')"

  if [[ ${#_GITUSER_ACCOUNTS_RAW[@]} -eq 0 ]]; then
    echo "  $(_gu_yellow '⚠') 등록된 계정이 없습니다."
    echo "  $GITUSER_CONFIG 파일을 확인하세요."
    echo ""
    return
  fi

  local aliases name email key_path rest
  for entry in "${_GITUSER_ACCOUNTS_RAW[@]}"; do
    aliases="${entry%%:*}"
    rest="${entry#*:}"
    name="${rest%%:*}"
    rest="${rest#*:}"
    email="${rest%%:*}"
    key_path="${rest#*:}"

    local marker="  "
    local label
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
  printf "  %-16s %s\n" "list"    "등록된 모든 계정 보기"
  printf "  %-16s %s\n" "current" "현재 git 계정 확인"
  printf "  %-16s %s\n" "<alias>" "해당 계정으로 전환"
  echo ""

  if [[ ${#_GITUSER_ACCOUNTS_RAW[@]} -gt 0 ]]; then
    echo "$(_gu_bold 'Available accounts:')"
    local aliases rest name
    for entry in "${_GITUSER_ACCOUNTS_RAW[@]}"; do
      aliases="${entry%%:*}"
      rest="${entry#*:}"
      name="${rest%%:*}"
      printf "  %-24s → %s\n" "$(_gu_cyan "$aliases")" "$name"
    done
    echo ""
  else
    echo "$(_gu_yellow '⚠') 설정 파일에 등록된 계정이 없습니다: $GITUSER_CONFIG"
    echo ""
  fi
}

# ── 내부: fzf 인터랙티브 선택 ───────────────────────────────

function _gituser_fzf() {
  _gituser_load

  if [[ ${#_GITUSER_ACCOUNTS_RAW[@]} -eq 0 ]]; then
    echo "$(_gu_yellow '⚠') 등록된 계정이 없습니다."
    return 1
  fi

  local current_name
  current_name="$(git config --global user.name 2>/dev/null)"

  local options=()
  local entry aliases rest name email key_path
  for entry in "${_GITUSER_ACCOUNTS_RAW[@]}"; do
    aliases="${entry%%:*}"
    rest="${entry#*:}"
    name="${rest%%:*}"
    rest="${rest#*:}"
    email="${rest%%:*}"
    key_path="${rest#*:}"
    local mark=""
    [[ "$name" == "$current_name" ]] && mark=" ✔"
    options+=("${aliases%%,*}  ${name}  <${email}>${mark}")
  done

  local selected
  selected="$(printf '%s\n' "${options[@]}" | fzf \
    --prompt="  Git User > " \
    --header="계정을 선택하세요 (Enter: 전환, Esc: 취소)" \
    --height=40% \
    --reverse \
    --no-info)"

  [[ -z "$selected" ]] && return 0

  # 첫 번째 토큰이 첫 alias
  local chosen_alias="${selected%% *}"
  _gituser_do "$chosen_alias"
}

# ── 내부: alias로 실제 전환 수행 ────────────────────────────

function _gituser_do() {
  local alias="$1"
  _gituser_load

  if [[ -z "${_GITUSER_MAP[$alias]}" ]]; then
    echo "$(_gu_red '✗') 알 수 없는 alias: '$(_gu_yellow "$alias")'"
    _gituser_help
    return 1
  fi

  local entry="${_GITUSER_MAP[$alias]}"
  local name="${entry%%:*}"
  local rest="${entry#*:}"
  local email="${rest%%:*}"
  local key_path="${rest#*:}"

  _gituser_switch "$name" "$email" "$key_path"
}

# ── 메인 커맨드 ─────────────────────────────────────────────

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
      echo "$(_gu_bold '현재 Git 계정 (global)')"
      echo "$(_gu_dim '──────────────────────────────')"
      printf "  %-10s %s\n" "이름:"   "$(_gu_bold "${name:-설정 없음}")"
      printf "  %-10s %s\n" "이메일:" "${email:-설정 없음}"
      echo ""
      ;;
    help|-h|--help)
      _gituser_help
      ;;
    *)
      _gituser_do "$1"
      ;;
  esac
}
