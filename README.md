# gituser

A shell utility for **easily switching between multiple GitHub accounts**. Designed for developers who maintain separate personal and work GitHub identities, `gituser` lets you switch Git users in seconds — without touching your existing shell config.

It works by **injecting a source block** into your existing `.zshrc` / `.bashrc` rather than replacing it entirely.

---

## Quick Install

### One-liner (new machine)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/isac7722/gituser/main/install.sh)
```

This clones the repo to `~/.gituser` and runs the installer automatically.

> **Note:** We use `bash <(curl ...)` instead of `curl ... | bash`. The latter hijacks stdin via the pipe, making interactive prompts impossible. The former keeps stdin connected to your terminal.

### Manual install

```bash
git clone git@github.com:isac7722/gituser.git ~/.gituser
cd ~/.gituser
./install.sh
```

To preview changes before applying:

```bash
./install.sh --dry-run
```

### Apply

```bash
source ~/.zshrc   # macOS
source ~/.bashrc  # Linux
```

---

## Repository Structure

```
gituser/
├── git-user.zsh        ← Git account management (zsh / macOS)
├── git-user.bash       ← Git account management (bash / Linux)
├── utils.zsh           ← Personal utility functions
├── config/
│   └── gitusers.example  ← Account config template
├── install.sh          ← Installer script
└── .gitignore
```

Root-level `*.zsh` (macOS) or `*.bash` (Linux) files are automatically sourced into your shell.

**What `install.sh` does:**

| Step | Description |
|------|-------------|
| OS detection | macOS → injects into `~/.zshrc` + loads `*.zsh` / Linux → injects into `~/.bashrc` + loads `*.bash` |
| Source block injection | Adds a gituser load block to your RC file (skipped if already present) |
| Config file creation | Creates `~/.config/gituser/accounts` from the template |

---

## Setting Up Git Accounts

### Registering an account

**Option A: Interactive (recommended)**

```bash
gituser add
```

```
Register account → ~/.config/gituser/accounts

  Name (git user.name): isac7722
  Email (git user.email): 57675355+isac7722@users.noreply.github.com
  SSH key path (e.g. ~/.ssh/work_ed25519): ~/.ssh/isac7722_ed25519
  Aliases (comma-separated, first is display name): isac,i,isac7722

✔ Account added
```

**Option B: Edit the config file directly**

```bash
$EDITOR ~/.config/gituser/accounts
```

File format:

```
# aliases:name:email:ssh_key_path
isac,i,isac7722:isac7722:57675355+isac7722@users.noreply.github.com:~/.ssh/isac7722_ed25519
pang,p,pangjoong:pangjoong:pangjoong@minirecord.com:~/.ssh/pangjoong_rsa
```

| Field | Description |
|-------|-------------|
| `aliases` | Comma-separated alias list (first one is the display name) |
| `name` | `git config user.name` |
| `email` | `git config user.email` |
| `ssh_key_path` | Path to SSH private key (`~/` supported) |

This file contains personal information and is not committed to the repo.

---

## gituser Commands

### Switch accounts

```bash
gituser               # Interactive selection via fzf (shows help if fzf not installed)
gituser list          # List registered accounts (highlights current)
gituser current       # Show the currently active account
gituser <alias>       # Switch to the specified account (global)
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

### Add an account

```bash
gituser add           # Interactive account registration
```

### Per-repo account

Apply an account to a specific repository only. Global config is not affected.

```bash
cd ~/dev/some-repo
gituser set pang
```

```
✔ Git account switched [local (this repo only)]
  Name:      pangjoong
  Email:     pangjoong@minirecord.com
  SSH Key:   /Users/user/.ssh/pangjoong_rsa
```

Internally sets `git config --local` and `core.sshCommand` for the repo.

### Auto-switch by directory (rules)

Automatically apply an account to all repos under a given directory. Just `cd` in — no manual switching needed.

```bash
gituser rule add pang ~/dev/personal       # Add a rule
gituser rule list                          # View registered rules
gituser rule remove pang ~/dev/personal   # Remove a rule
```

```
$ gituser rule list

 includeIf Directory Rules
──────────────────────────────────────────────
  /Users/user/dev/personal/  → pangjoong <pangjoong@minirecord.com>
  /Users/user/dev/work/      → isac7722  <57675355+isac7722@...>
──────────────────────────────────────────────
```

**How it works:** Adds `[includeIf "gitdir:..."]` blocks to `~/.gitconfig` and stores user/`core.sshCommand` settings in `~/.config/gituser/profiles/<alias>.gitconfig`. Uses Git's native feature — works permanently regardless of shell session.

### Clone with a specific account

```bash
gituser clone pang git@github.com:user/repo.git
gituser clone isac git@github.com:user/repo.git my-repo-dir
```

Automatically applies the specified account as a `--local` config after cloning.

---

## Adding Custom Shell Functions

Any file added to the root directory is automatically sourced at shell startup.

```bash
# macOS (zsh)
touch ~/.gituser/my-functions.zsh

# Linux (bash)
touch ~/.gituser/my-functions.bash
```

After editing, run `source ~/.zshrc` (or `~/.bashrc`) to apply.

---

## SSH Key Setup

SSH keys are not included in this repo for security reasons.

**Copy from an existing machine:**

```bash
scp ~/.ssh/key_name newmachine:~/.ssh/key_name
chmod 600 ~/.ssh/key_name
```

**Generate a new key:**

```bash
ssh-keygen -t ed25519 -f ~/.ssh/key_name -C "comment"
# Then add the public key (.pub) to GitHub → Settings → SSH Keys
```

---

## Custom Config Paths

Override the default paths with environment variables:

```bash
export GITUSER_CONFIG="/path/to/accounts"
export GITUSER_PROFILES_DIR="/path/to/profiles"
```
