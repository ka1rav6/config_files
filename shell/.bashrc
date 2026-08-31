# ~/.bashrc: executed by bash for non-login shells

# If not running interactively, don't do anything
case $- in
*i*) ;;
*) return ;;
esac
exec zsh
force_color_prompt=yes
# Enable color support for ls
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias pdf='sioyek'
alias gmd='ghostwriter'
# --------- ALIASES ---------

alias cls='clear'
alias h='history'
alias getasm='gcc -S -O2 -fverbose-asm'
#instead of this use the function: r5asm filename
alias lockssd="fusermount -u ./unlocked"
alias unlockssd="gocryptfs ./encrypted ./unlocked"

# Git aliases- actually use them
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

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
    riscv64-linux-gnu-objdump -d -S "${base}.out" >"${base}.mix"

    echo "Generated:"
    echo "  ${base}.s   → verbose assembly"
    echo "  ${base}.mix → C + ASM (best for learning)"

    vim "${base}.mix"
}
pipinst() {
    python -m pip install --break-system-packages "$@"
}
# mkcd → make directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# --------- PROMPT ---------

# kairav/time format
PS1='\e[32mkairav/\A:\w\$\e[32m '

# --------- HISTORY SEARCH WITH ARROW KEYS ---------

bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
export PATH="$HOME/.local/bin:$PATH"
# test
# test
. "$HOME/.cargo/env"

# Added by jcode installer
export PATH="/home/kairav/.local/bin:$PATH"
