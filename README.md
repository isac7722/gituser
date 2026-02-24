# gituser

개인 개발 환경 스크립트 모음. 기존 셸 설정(`.zshrc` / `.bashrc`)을 교체하지 않고, **source 블록만 주입**하는 방식으로 동작합니다.

## 구조

```
gituser/
├── git-user.zsh        ← Git 계정 관리 (zsh / macOS)
├── git-user.bash       ← Git 계정 관리 (bash / Linux)
├── utils.zsh           ← 개인용 유틸리티 함수
├── config/
│   └── gitusers.example  ← Git 계정 설정 템플릿
├── install.sh          ← 설치 스크립트
└── .gitignore
```

루트의 `*.zsh` (macOS) 또는 `*.bash` (Linux) 파일이 자동으로 셸에 로드됩니다.

---

## 설치

### 원라인 설치 (새 머신)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/isac7722/gituser/main/install.sh)
```

자동으로 `~/gituser`에 저장소를 클론하고 설치까지 진행합니다.

> **참고:** `curl ... | bash` 대신 `bash <(curl ...)` 형태를 사용합니다. 전자는 stdin을 파이프가 점유해 인터랙티브 입력이 불가능하고, 후자는 stdin이 터미널에 연결된 채로 동작합니다.

### 수동 설치 (직접 클론)

```bash
git clone git@github.com:isac7722/gituser.git ~/gituser
cd ~/gituser
./install.sh
```

변경 내용을 먼저 확인하려면:

```bash
./install.sh --dry-run
```

**install.sh가 하는 일:**

| 단계 | 내용 |
|------|------|
| OS 감지 | macOS → `~/.zshrc` + `*.zsh` 로드 / Linux → `~/.bashrc` + `*.bash` 로드 |
| source 블록 주입 | RC 파일에 gituser 로드 블록 추가 (이미 있으면 스킵) |
| 설정 파일 생성 | `~/.config/gituser/accounts` 생성 (템플릿 복사) |

### 3. 적용

```bash
source ~/.zshrc   # macOS
source ~/.bashrc  # Linux
```

---

## Git 계정 설정

### 계정 등록 방법

**방법 A: 인터랙티브 등록 (권장)**

```bash
gituser add
```

```
계정 등록 → ~/.config/gituser/accounts

  이름 (git user.name): isac7722
  이메일 (git user.email): 57675355+isac7722@users.noreply.github.com
  SSH 키 경로 (예: ~/.ssh/work_ed25519): ~/.ssh/isac7722_ed25519
  Aliases (쉼표 구분, 첫 번째가 표시 이름): isac,i,isac7722

✔ 계정 추가 완료
```

**방법 B: 설정 파일 직접 편집**

```bash
$EDITOR ~/.config/gituser/accounts
```

파일 형식:

```
# aliases:name:email:ssh_key_path
isac,i,isac7722:isac7722:57675355+isac7722@users.noreply.github.com:~/.ssh/isac7722_ed25519
pang,p,pangjoong:pangjoong:pangjoong@minirecord.com:~/.ssh/pangjoong_rsa
```

| 필드 | 설명 |
|------|------|
| `aliases` | 쉼표로 구분된 alias 목록 (첫 번째가 표시 이름) |
| `name` | `git config user.name` |
| `email` | `git config user.email` |
| `ssh_key_path` | SSH 개인키 경로 (`~/` 사용 가능) |

이 파일은 개인 정보를 포함하므로 repo에 커밋되지 않습니다.

---

## gituser 커맨드

### 기본 전환

```bash
gituser               # fzf 인터랙티브 선택 (fzf 미설치 시 help)
gituser list          # 등록된 계정 목록 (현재 계정 표시)
gituser current       # 현재 활성 계정 확인
gituser <alias>       # 해당 계정으로 전환 (global)
```

```
$ gituser list

 Git User Accounts
──────────────────────────────────────────────
▶ isac7722             57675355+isac7722@...  ← current
  aliases: isac,i,isac7722
  pangjoong            pangjoong@minirecord.com
  aliases: pang,p,pangjoong
──────────────────────────────────────────────
```

### 계정 등록

```bash
gituser add           # 인터랙티브 계정 등록
```

### per-repo 계정 설정

특정 저장소에서만 계정을 적용합니다. global 설정은 변경되지 않습니다.

```bash
cd ~/dev/some-repo
gituser set pang
```

```
✔ Git 계정 전환 완료 [local (이 저장소만)]
  이름:      pangjoong
  이메일:    pangjoong@minirecord.com
  SSH 키:    /Users/user/.ssh/pangjoong_rsa
```

내부적으로 `git config --local`과 `core.sshCommand`를 설정합니다.

### 디렉토리 자동 전환 (rule)

특정 디렉토리 아래 모든 저장소에 자동으로 계정을 적용합니다. 수동 전환 없이 `cd` 만 해도 Git이 올바른 계정을 사용합니다.

```bash
gituser rule add pang ~/dev/personal       # 규칙 추가
gituser rule list                          # 등록된 규칙 보기
gituser rule remove pang ~/dev/personal   # 규칙 제거
```

```
$ gituser rule list

 includeIf 디렉토리 규칙
──────────────────────────────────────────────
  /Users/user/dev/personal/  → pangjoong <pangjoong@minirecord.com>
  /Users/user/dev/work/      → isac7722  <57675355+isac7722@...>
──────────────────────────────────────────────
```

**동작 원리:** `~/.gitconfig`에 `[includeIf "gitdir:..."]` 블록을 추가하고, `~/.config/gituser/profiles/<alias>.gitconfig`에 user/core.sshCommand를 저장합니다. Git 네이티브 기능이므로 셸 세션에 무관하게 영구적으로 동작합니다.

### 계정 지정 clone

```bash
gituser clone pang git@github.com:user/repo.git
gituser clone isac git@github.com:user/repo.git my-repo-dir
```

clone 후 해당 저장소에 `--local` 계정 설정을 자동으로 적용합니다.

---

## 커스텀 함수 추가

루트 디렉토리에 파일을 추가하면 셸 시작 시 자동으로 로드됩니다.

```bash
# macOS (zsh)
touch ~/gituser/my-functions.zsh

# Linux (bash)
touch ~/gituser/my-functions.bash
```

편집 후 `source ~/.zshrc` (또는 `~/.bashrc`)로 적용.

---

## SSH 키 설정

SSH 키는 보안상 이 저장소에 포함되지 않습니다.

**기존 컴퓨터에서 복사:**

```bash
scp ~/.ssh/key_name 새컴퓨터:~/.ssh/key_name
chmod 600 ~/.ssh/key_name
```

**새로 생성:**

```bash
ssh-keygen -t ed25519 -f ~/.ssh/key_name -C "comment"
# 생성 후 GitHub → Settings → SSH Keys 에 공개키(.pub) 등록
```

---

## 설정 파일 경로 변경

환경변수로 기본 경로를 변경할 수 있습니다:

```bash
export GITUSER_CONFIG="/path/to/accounts"
export GITUSER_PROFILES_DIR="/path/to/profiles"
```
