# Exit immediately if this shell is non-interactive (e.g., running scripts, SCP, or cron jobs)
# to avoid unnecessary plugin loading or terminal output.
[[ $- != *i* ]] && return

# Helper function: returns true (0) if a command or executable exists in PATH,
# false (1) otherwise. Used throughout to guard optional tools on fresh installs.
_has() {
  command -v "$1" >/dev/null 2>&1
}

# Optional startup visuals (commented out by default to keep shell startup fast).
# Uncomment if you want a system fetch or fortune/cowsay on new terminals.
# clear
# pfetch
# fortune 100% fortunes | cowsay

##########
# Zinit  #
##########
# Where Zinit and its plugins/snippets will live (follows XDG Base Directory spec).
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Auto-bootstrap Zinit on a fresh machine if it isn't installed yet.
if [[ ! -d "$ZINIT_HOME" ]]; then
  if _has git; then
    print -P "%F{cyan}Installing Zinit...%f"
    command mkdir -p "$(dirname "$ZINIT_HOME")"
    # --depth=1 fetches only the latest commit for a fast, lightweight clone.
    command git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
  else
    # Don't fail the shell if git isn't installed yet; we'll fall back to standard compinit below.
    print -P "%F{yellow}Warning: git not found; skipping Zinit installation.%f"
  fi
fi

if [[ -f "${ZINIT_HOME}/zinit.zsh" ]]; then
  source "${ZINIT_HOME}/zinit.zsh"

  # "wait'0' lucid" loads non-critical snippets slightly after the first prompt appears
  # ("turbo mode") without printing extra loading messages ("lucid").
  zinit ice wait"0" lucid
  zinit snippet OMZL::git.zsh

  # Oh My Zsh plugin snippets for common tools and workflows.
  for snippet in OMZP::git OMZP::sudo OMZP::archlinux OMZP::aws OMZP::kubectl OMZP::kubectx OMZP::command-not-found; do
    zinit ice wait"0" lucid
    zinit snippet "$snippet"
  done

  # Plugin load order matters:
  # 1. zsh-completions adds extra completion definitions.
  # 2. fzf-tab replaces default completion menus with an interactive fzf selector.
  # 3. zsh-autosuggestions shows ghost text from history (deferred with turbo mode).
  # 4. zsh-syntax-highlighting MUST load last so it can highlight everything defined before it.
  zinit light zsh-users/zsh-completions
  zinit light Aloxaf/fzf-tab
  zinit ice wait"0" lucid
  zinit light zsh-users/zsh-autosuggestions
  zinit ice wait"0" lucid atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay"
  zinit light zsh-users/zsh-syntax-highlighting
else
  # Fallback if Zinit isn't present: initialize Zsh's built-in completion system directly.
  # '-C' skips security/dump checks for faster startup.
  autoload -Uz compinit && compinit -C
fi

# Case-insensitive completion matching (e.g., typing 'doc' can match 'Documents').
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Colorize completion entries using LS_COLORS if that variable is set.
if [[ -n "$LS_COLORS" ]]; then
  zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
fi

# Disable Zsh's default completion menu because fzf-tab handles interactive selection.
zstyle ':completion:*' menu no

# Show a live directory preview inside fzf-tab when completing `cd` or `zoxide` (`__zoxide_z`).
# Prefers `eza` (maintained `exa` successor), falls back to `exa`, then plain `ls`.
if _has eza; then
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --color=always --icons $realpath'
  zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --color=always --icons $realpath'
elif _has exa; then
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa --color=always --icons $realpath'
  zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'exa --color=always --icons $realpath'
else
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -la --color=always $realpath'
  zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls -la --color=always $realpath'
fi

#######################
# User Configuration  #
#######################

# Enable Vim-style keybindings in the command line (insert/normal mode).
bindkey -v
# Lower Escape timeout from 400ms (default) to 100ms (10 * 10ms) so switching
# from insert mode to normal mode with Esc feels immediate.
export KEYTIMEOUT=10

###########
# History #
###########
HISTSIZE=10000                            # Max commands kept in memory during a session
SAVEHIST=10000                            # Max commands written to the history file
HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history" # Where persistent command history is stored
HISTDUP=erase                             # Remove older duplicate entries when trimming

# Make sure the parent directory of $HISTFILE exists on a brand-new setup.
[[ -d "${HISTFILE:h}" ]] || command mkdir -p "${HISTFILE:h}"

setopt append_history     # Append to history file rather than overwriting it
setopt share_history      # Share history in real time across open Zsh sessions
setopt hist_ignore_space  # Don't record commands starting with a space (useful for secrets)
setopt hist_ignore_all_dups # Remove older duplicates if a new command matches an old one
setopt hist_save_no_dups  # Don't write duplicate events to the history file
setopt hist_ignore_dups   # Don't record an event if it's identical to the previous one
setopt hist_find_no_dups  # Skip duplicates when searching history with Ctrl+R / line editor

##########
# Exports #
##########

# Pick the best available terminal editor so tools like `git commit` or `sudoedit`
# always have a working fallback on fresh installs.
if _has nvim; then
  export EDITOR='nvim'
  export VISUAL='nvim'
elif _has vim; then
  export EDITOR='vim'
  export VISUAL='vim'
elif _has vi; then
  export EDITOR='vi'
  export VISUAL='vi'
else
  export EDITOR='nano'
  export VISUAL='nano'
fi

# Format man pages with `bat` (syntax-highlighted pager) if available, otherwise use `less`.
if _has bat; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p --paging always'"
elif _has batcat; then
  # Debian/Ubuntu sometimes name the `bat` binary `batcat`.
  export MANPAGER="sh -c 'col -bx | batcat -l man -p --paging always'"
else
  export MANPAGER="less -R"
fi

# `typeset -U path PATH` ties Zsh's `path` array to `$PATH` and automatically
# deduplicates entries while preserving the first occurrence.
typeset -U path PATH

# Candidate directories for user scripts, SDKs, and runtimes.
local -a candidate_paths=(
  "$HOME/.local/bin"
  "$HOME/.cargo/bin"
  "$HOME/.luarocks/bin"
  "$HOME/.config/emacs/bin"
  "$HOME/.config/script"
  "$HOME/.opencode/bin"
  "$HOME/Dev/Flutt/flutter/bin"
  "$HOME/Dev/android-studio/bin"
  "$HOME/Applications/jdk-25.0.5+8/bin"
  "$HOME/Games"
)

# Only add directories that actually exist so $PATH stays clean on fresh machines.
local p
for p in "${candidate_paths[@]}"; do
  [[ -d "$p" ]] && path=("$p" $path)
done

# Keep existing system/environment PATH entries and optionally append Spicetify.
path+=($path)
[[ -d "$HOME/.spicetify" ]] && path+=("$HOME/.spicetify")
unset candidate_paths p

# Ollama performance & VRAM tuning (only set when `ollama` is installed).
if _has ollama; then
  export OLLAMA_FLASH_ATTENTION=1       # Faster attention & lower VRAM usage
  export OLLAMA_KV_CACHE_TYPE=q8_0      # Quantizes KV cache to cut context memory ~50%
  export OLLAMA_NUM_PARALLEL=1          # Avoids allocating duplicate KV caches per request
  export OLLAMA_MAX_LOADED_MODELS=1     # Prevents keeping multiple models in VRAM at once
  export OLLAMA_KEEP_ALIVE=30m          # Keeps the active model loaded for 30m while coding
fi

###########
# Aliases #
###########

# Run a dedicated 32-bit Wine prefix cleanly without typing env vars each time.
if _has wine; then
  alias w32='WINEPREFIX="$HOME/prefix32" WINEARCH=win32'
fi

# Directory listing aliases with fallback chain: eza -> exa -> standard ls.
if _has eza; then
  alias l='eza --icons'
  alias ls='eza --icons'
  alias la='eza -a --icons'
  alias ll='eza -alFh --icons'
  alias tree='eza --tree -alFh --icons'
elif _has exa; then
  alias l='exa --icons'
  alias ls='exa --icons'
  alias la='exa -a --icons'
  alias ll='exa -alFh --icons'
  alias tree='exa --tree -alFh'
else
  alias l='ls --color=auto'
  alias ls='ls --color=auto'
  alias la='ls -A --color=auto'
  alias ll='ls -alFh --color=auto'
  _has tree || alias tree='find . -maxdepth 3'
fi

# Convenience shortcuts that follow whichever editor was chosen above.
alias v="$EDITOR"
alias vi="$EDITOR"
alias vim="$EDITOR"

# Modern Rust/CLI replacements with fallbacks where appropriate.
if _has bat; then
  alias cat='bat'
elif _has batcat; then
  alias cat='batcat'
fi

_has dust && alias du='dust'     # Visual disk usage analyzer
_has rg && alias grep='rg'       # ripgrep for fast recursive text search
if _has fd; then
  alias find='fd'                # Fast, user-friendly file finder
elif _has fdfind; then
  alias find='fdfind'            # Debian/Ubuntu binary name for `fd`
fi

# Everyday quality-of-life shortcuts.
alias :q='exit'                  # Habitual Vim exit command in the shell
alias reload='exec zsh'          # Replace current shell with a fresh Zsh process
alias ..='cd ..'                 # Quick step up one directory
_has aria2c && alias dl='aria2c' # Multi-connection downloader
[[ -d "/media/cxabd/Data" ]] && alias Data='cd /media/cxabd/Data' # Jump to Data drive if mounted
_has systemctl && alias restart-audio='systemctl --user restart pipewire pipewire-pulse wireplumber'

# Specific Godot binary shortcut (only created if that exact binary is in PATH).
_has Godot_v4.7.2-stable_linux.x86_64 && alias godot='Godot_v4.7.2-stable_linux.x86_64'

# Live-refreshing `spfetch` display (updates once per second via a temp file).
if _has spfetch; then
  alias spf='while sleep 1; do spfetch > /tmp/spf && clear && /bin/cat /tmp/spf; done'
fi

####################
# Package Managers #
####################
# Prefer `nala` (prettier APT frontend) if installed; otherwise fall back to
# the system's native package manager so `update` works across distros.
if _has nala; then
  alias apt='nala'
  alias update='nala upgrade'
elif _has apt; then
  alias update='sudo apt update && sudo apt upgrade'
elif _has pacman; then
  alias update='sudo pacman -Syu'
elif _has dnf; then
  alias update='sudo dnf upgrade'
fi

#######
# Fzf #
#######
# Load fzf keybindings/completion script if generated by the fzf installer.
[[ -f "${HOME}/.fzf.zsh" ]] && source "${HOME}/.fzf.zsh"

# Apply Tokyonight color palette to fzf (appends safely if FZF_DEFAULT_OPTS already exists).
if _has fzf; then
  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }"'
--color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7
--color=fg+:#c0caf5,bg+:#1a1b26,hl+:#7dcfff
--color=info:#7aa2f7,prompt:#7dcfff,pointer:#7dcfff
--color=marker:#9ece6a,spinner:#9ece6a,header:#9ece6a'
fi

##########
# Zoxide #
##########
# Smarter `cd` that learns frequently visited directories (`--cmd cd` replaces `cd` with `z`).
if _has zoxide; then
  eval "$(zoxide init --cmd cd zsh)"
fi

#####################
# Custom Functions  #
#####################
# Automatically list directory contents whenever you change directories (`cd` / `z`),
# but skip auto-listing if there are over 100 entries to prevent lag or clutter.
chpwd() {
  local count
  count=$(command ls -A 2>/dev/null | wc -l)
  if (( count <= 100 )); then
    ls
  else
    print -P "%F{yellow}Directory has $count items; skipping auto-ls.%f"
  fi
}

##########
# Prompt #
##########
# Use Oh My Posh with your custom Tokyonight config if both exist; fall back to
# Oh My Posh's default prompt if the config file is missing; or fall back to a
# clean plain Zsh prompt if Oh My Posh isn't installed yet.
if _has oh-my-posh && [[ -f "$HOME/.config/omp/tokyo.toml" ]]; then
  eval "$(oh-my-posh init zsh --config "$HOME/.config/omp/tokyo.toml")"
elif _has oh-my-posh; then
  eval "$(oh-my-posh init zsh)"
else
  autoload -Uz promptinit && promptinit 2>/dev/null
  PROMPT='%F{cyan}%n@%m%f:%F{blue}%~%f%# '
fi

# Lazy-load NVM so opening a new shell stays fast. The first time you run one of
# these commands, it unloads the stub functions, sources `nvm.sh`, and runs your command.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  _nvm_lazy_load() {
    unset -f nvm node npm npx yarn pnpm 2>/dev/null
    source "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
  }
  for cmd in nvm node npm npx yarn pnpm; do
    eval "${cmd}() { _nvm_lazy_load; ${cmd} \"\$@\"; }"
  done
  unset cmd
fi

# Optional per-machine overrides: put host-specific paths, work env vars, or
# secrets in `~/.zshrc.local` so this main `.zshrc` stays clean and portable.
[[ -f "${ZDOTDIR:-$HOME}/.zshrc.local" ]] && source "${ZDOTDIR:-$HOME}/.zshrc.local"
