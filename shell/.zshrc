# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"
# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
# --------- ALIASES ---------

alias cls='clear'
alias h='history'
alias getasm='gcc -S -O2 -fverbose-asm'

# Git aliases
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

alias lockssd="fusermount -u ./unlocked"
alias unlockssd="gocryptfs ./encrypted ./unlocked"

# --------- FUNCTIONS ---------
r5asm() {
    if [ -z "$1" ]; then
        echo "Usage: r5asm <file.c>"
        return 1
    fi

    file="$1"
    base="${file%.c}"

    # Generate readable assembly
    riscv64-linux-gnu-gcc -S -O0 -g -fverbose-asm "$file" -o "${base}.s"

    # Generate executable
    riscv64-linux-gnu-gcc -O0 -g "$file" -o "${base}.out"

    # Generate mixed view
    riscv64-linux-gnu-objdump -d -S "${base}.out" > "${base}.mix"

    echo "Generated:"
    echo "  ${base}.s   → verbose assembly"
    echo "  ${base}.mix → C + ASM (best for learning)"

    vim "${base}.mix"
}
# mkcd → make directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}
pipinst() {
  python -m pip install --break-system-packages "$@"
}
# --------- PROMPT ---------

# kairav/time format
PS1='\e[32mkairav/\A:\w\$\e[32m '


# --------- HISTORY SEARCH WITH ARROW KEYS ---------

bindkey "^[[A" history-search-backward
bindkey "^[[B" history-search-forward

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
#
export JAVA_HOME=/usr/lib/jvm/default-java
export PATH=$JAVA_HOME/bin:$PATH

# Created by `pipx` on 2026-05-27 16:56:54
export PATH="$PATH:/home/kairav/.local/bin"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PATH="$HOME/bin:$PATH"
export PATH="/opt/zig:$PATH"
export OLLAMA_IGPU_ENABLE=1
export PATH="$HOME/Applications/Godot:$PATH"
export OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=4096

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
# use fd/rg if available — much faster and respects .gitignore
if command -v fd >/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

export FZF_DEFAULT_OPTS="
  --height=60% --layout=reverse --border=rounded
  --preview-window=right:50%:wrap
  --bind='ctrl-/:toggle-preview'
"

# preview file contents with bat if you have it
if command -v bat >/dev/null; then
  export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :100 {}'"
fi

# make ctrl-r layout nicer and dedupe history entries
export FZF_CTRL_R_OPTS="
  --preview 'echo {}' --preview-window down:3:hidden:wrap
  --bind 'ctrl-/:toggle-preview'
  --color header:italic
  --header 'Enter to run, Ctrl+/ to preview'
"
notify-build() {
  local cmd="$*"
  if eval "$cmd"; then
    notify-send -a "Build" -u normal -i software-update-available "Build succeeded" "$cmd"
  else
    notify-send -a "Build" -u critical -i dialog-error "Build failed" "$cmd"
  fi
}
