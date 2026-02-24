#!/usr/bin/env bash
# ============================================================
# dotfiles 설치 스크립트
# 사용법: ./install.sh [--dry-run]
#
# 하는 일:
#   1. OS 감지 → 셸 RC 파일 결정 (.zshrc / .bashrc)
#   2. RC 파일에 dotfiles source 블록 주입 (중복 방지)
#   3. Git user 계정 설정 파일 초기화
# ============================================================

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

# ── 옵션 파싱 ──────────────────────────────────────────────

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
  esac
done

# ── 유틸 함수 ──────────────────────────────────────────────

log()     { echo "  $1"; }
success() { echo "✔  $1"; }
warn()    { echo "⚠  $1"; }
error()   { echo "✗  $1"; exit 1; }
section() { echo ""; echo "── $1 ──────────────────────────────"; }

# ── 시작 ───────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       dotfiles 설치 시작              ║"
echo "╚══════════════════════════════════════╝"
$DRY_RUN && warn "DRY-RUN 모드: 실제 변경 없음"

# ── 1. OS 감지 ─────────────────────────────────────────────

section "OS 감지"

case "$(uname -s)" in
  Darwin*)
    OS="macOS"
    RC_FILE="$HOME/.zshrc"
    ;;
  Linux*)
    OS="Linux"
    RC_FILE="$HOME/.bashrc"
    ;;
  *)
    error "지원하지 않는 OS: $(uname -s)"
    ;;
esac

success "감지된 OS: $OS → RC 파일: $RC_FILE"

# ── 2. RC 파일에 source 블록 주입 ──────────────────────────

section "셸 연동 ($RC_FILE)"

MARKER_START="# >>> dotfiles >>>"
MARKER_END="# <<< dotfiles <<<"

# OS에 따라 로드할 파일 확장자 결정
# macOS(zsh): *.zsh 로드  /  Linux(bash): *.bash 로드
if [[ "$OS" == "macOS" ]]; then
  DF_PATTERN="*.zsh"
else
  DF_PATTERN="*.bash"
fi

# 블록 내용 (RC_FILE에 삽입될 내용)
SOURCE_BLOCK="
$MARKER_START
# dotfiles 자동 로드 (install.sh가 생성)
DOTFILES_DIR=\"$DOTFILES_DIR\"
for _df_file in \"\$DOTFILES_DIR\"/$DF_PATTERN; do
  [ -f \"\$_df_file\" ] && source \"\$_df_file\"
done
unset _df_file
$MARKER_END"

if grep -q "$MARKER_START" "$RC_FILE" 2>/dev/null; then
  success "이미 연동됨: $RC_FILE"
else
  if $DRY_RUN; then
    log "[dry-run] $RC_FILE 에 source 블록 추가 예정"
    log "[dry-run] 블록 내용:"
    echo "$SOURCE_BLOCK" | sed 's/^/    /'
  else
    # RC 파일이 없으면 생성
    touch "$RC_FILE"
    printf '%s\n' "$SOURCE_BLOCK" >> "$RC_FILE"
    success "source 블록 추가 완료: $RC_FILE"
  fi
fi

# ── 3. Git user 설정 파일 초기화 ───────────────────────────

section "Git User 설정 파일"

GITUSER_CONFIG_DIR="$HOME/.config/gituser"
GITUSER_CONFIG="$GITUSER_CONFIG_DIR/accounts"
GITUSER_EXAMPLE="$DOTFILES_DIR/config/gitusers.example"

if [[ ! -f "$GITUSER_CONFIG" ]]; then
  if $DRY_RUN; then
    log "[dry-run] $GITUSER_CONFIG 생성 예정"
    log "[dry-run] 템플릿: $GITUSER_EXAMPLE"
  else
    mkdir -p "$GITUSER_CONFIG_DIR"
    cp "$GITUSER_EXAMPLE" "$GITUSER_CONFIG"
    success "설정 파일 생성: $GITUSER_CONFIG"
    echo ""
    log "▶ 계정을 등록하려면 아래 파일을 편집하세요:"
    log "     \$EDITOR $GITUSER_CONFIG"
    log ""
    log "  형식: aliases:name:email:~/.ssh/key_name"
    log "  예시: work,w:John:john@company.com:~/.ssh/work_ed25519"
  fi
else
  success "설정 파일 이미 있음: $GITUSER_CONFIG"
fi

# ── 완료 ───────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       설치 완료!                      ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  다음 명령어로 즉시 적용하세요:"
echo "    source $RC_FILE"
echo ""
echo "  Git 계정 전환:"
echo "    gituser list      # 계정 목록 보기"
echo "    gituser <alias>   # 계정 전환"
echo ""
