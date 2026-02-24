# dotfiles

개인 개발 환경 스크립트 모음. 기존 셸 설정(`.zshrc` / `.bashrc`)을 교체하지 않고, **source 블록만 주입**하는 방식으로 동작합니다.

## 구조

```
dotfiles/
├── git-user.zsh        ← Git 계정 전환 (gituser 커맨드)
├── utils.zsh           ← 개인용 유틸리티 함수
├── config/
│   └── gitusers.example  ← Git 계정 설정 템플릿
├── install.sh          ← 설치 스크립트
└── .gitignore
```

루트의 `*.zsh` 파일이 자동으로 셸에 로드됩니다. 파일을 추가하기만 하면 됩니다.

---

## 설치

### 1. 저장소 클론

```bash
git clone git@github.com:<username>/dotfiles.git ~/dotfiles
```

### 2. 설치 실행

```bash
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

설치 전 변경 내용을 미리 확인하려면:

```bash
./install.sh --dry-run
```

**install.sh가 하는 일:**

1. OS 감지 → macOS면 `~/.zshrc`, Linux면 `~/.bashrc`
2. 해당 RC 파일에 아래 블록을 추가 (이미 있으면 스킵)
   ```bash
   # >>> dotfiles >>>
   DOTFILES_DIR="~/dotfiles"
   for _df_file in "$DOTFILES_DIR"/*.zsh; do
     [ -f "$_df_file" ] && source "$_df_file"
   done
   # <<< dotfiles <<<
   ```
3. `~/.config/gituser/accounts` 설정 파일 생성 (템플릿 복사)

### 3. 적용

```bash
source ~/.zshrc   # macOS
source ~/.bashrc  # Linux
```

---

## Git 계정 설정

install.sh 실행 후 `~/.config/gituser/accounts` 파일을 편집합니다.

```bash
$EDITOR ~/.config/gituser/accounts
```

**파일 형식:**

```
# aliases:name:email:ssh_key_path
isac,i,isac7722:isac7722:57675355+isac7722@users.noreply.github.com:~/.ssh/isac7722_ed25519
pang,p,pangjoong:pangjoong:pangjoong@minirecord.com:~/.ssh/pangjoong_rsa
```

| 필드         | 설명                              |
|------------|-----------------------------------|
| `aliases`  | 쉼표로 구분된 alias 목록 (첫 번째가 표시 이름) |
| `name`     | `git config user.name`            |
| `email`    | `git config user.email`           |
| `ssh_key_path` | SSH 개인키 경로 (`~/` 사용 가능)   |

이 파일은 개인 정보가 포함되어 있어 repo에 커밋되지 않습니다. `config/gitusers.example`을 템플릿으로 사용하세요.

---

## gituser 커맨드

```bash
gituser               # fzf 인터랙티브 선택 (fzf 미설치 시 help 출력)
gituser list          # 등록된 계정 목록 보기 (현재 계정 표시)
gituser current       # 현재 활성 계정 확인
gituser <alias>       # 해당 계정으로 전환
```

**예시:**

```
$ gituser list

 Git User Accounts
──────────────────────────────────────────────
▶ isac7722             57675355+isac7722@users.noreply.github.com  ← current
  aliases: isac,i,isac7722
  pangjoong            pangjoong@minirecord.com
  aliases: pang,p,pangjoong
──────────────────────────────────────────────

$ gituser pang
✔ Git 계정 전환 완료
  이름:      pangjoong
  이메일:    pangjoong@minirecord.com
  SSH 키:    /Users/user/.ssh/pangjoong_rsa
```

### 설정 파일 경로 변경

환경변수로 설정 파일 위치를 변경할 수 있습니다:

```bash
export GITUSER_CONFIG="/path/to/custom/accounts"
```

---

## 커스텀 함수 추가

루트 디렉토리에 `*.zsh` 파일을 추가하면 셸 시작 시 자동으로 로드됩니다.

```bash
touch ~/dotfiles/my-functions.zsh
# 편집 후 source ~/.zshrc 로 적용
```

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
