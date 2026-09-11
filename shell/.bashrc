# =============================================================================
# ~/.bashrc — bash's per-interactive-shell startup file
# =============================================================================
#
# WHAT THIS FILE ACTUALLY DOES, IN ONE LINE:
#   It hands the session over to zsh and stops. That's it.
#
# Your login shell is already zsh (`getent passwd kairav` ends in /usr/bin/zsh),
# so this file only runs when something explicitly starts *bash* — a script that
# says `#!/bin/bash -i`, an IDE terminal hardcoded to bash, `su`, a docker
# `exec -it ... bash`, etc. In those cases the `exec zsh` below swaps the
# process out for zsh so you get your real environment (see ~/.zshrc).
#
# READ THIS BEFORE EDITING:
#   `exec` REPLACES the current process. Nothing after it in this file is ever
#   reached. Everything below the "DEAD CODE" banner is inert — kept only as a
#   record of the pre-zsh setup. If you want to change an alias, a function or
#   the prompt, edit ~/.zshrc, NOT this file. Changes here do nothing.
#
# Bash startup order, for reference:
#   login shell     -> /etc/profile -> ~/.bash_profile | ~/.bash_login | ~/.profile
#   interactive     -> ~/.bashrc            (this file)
#   Your ~/.profile sources this file when bash is the login shell.
# -----------------------------------------------------------------------------


# --- Bail out early if this shell is not interactive -------------------------
#
# `$-` holds the shell's active option flags; it contains `i` only for
# interactive shells. Non-interactive shells (every `bash script.sh`, every
# `ssh host command`, every build step) return here immediately.
#
# This guard is essential. Without it, the `exec zsh` below would fire inside
# non-interactive bash and break any tool that shells out to `bash -c`, plus
# scp/rsync, which choke on unexpected output from a remote startup file.
case $- in
*i*) ;;  # interactive  -> keep going, fall through to the exec below
*) return ;;  # anything else -> stop reading this file now
esac


# --- Hand the session over to zsh --------------------------------------------
#
# `exec` replaces this bash process with zsh rather than nesting one inside the
# other, so you get a clean single shell: no stacked processes, and `exit`
# leaves the terminal once instead of dropping you back into bash.
#
# The `command -v` guard is a safety catch. A bare `exec zsh` with zsh missing
# or broken kills the shell outright (exec failure in an interactive shell
# terminates it), which would leave you with no working terminal and no obvious
# way to fix it. With the guard, a missing zsh simply leaves you in bash.
if command -v zsh >/dev/null 2>&1; then
	exec zsh
fi


# =============================================================================
# ============================ DEAD CODE BELOW ================================
# =============================================================================
#
# Execution never reaches this point when zsh is installed — the `exec` above
# has already replaced the process.
#
# This is the original bash configuration, preserved verbatim as a fallback for
# the rare case where zsh is missing, and as a historical record. Every alias
# and function here has a live twin in ~/.zshrc; that file is the one that
# actually shapes your shell.
#
# If you ever want this block to run again, move it ABOVE the `exec zsh` line.
# =============================================================================


# --- Prompt colour opt-in ----------------------------------------------------
# Consulted by the stock Ubuntu ~/.bashrc prompt block to decide whether to emit
# colour escapes. That block was removed from this file, so this now only
# matters to anything else that happens to read the variable.
force_color_prompt=yes


# --- Modern replacements for the classic coreutils ---------------------------
# eza: a Rust `ls` with git awareness, tree mode and better colours by default.
alias ls='eza'
alias ll='eza -alF'    # long listing, including dotfiles, with type indicators
alias la='eza -A'      # all entries except . and ..
alias l='eza -CF'      # brief multi-column listing

# --color=auto keeps colour when stdout is a terminal and drops it when piped,
# so `grep x | wc -l` doesn't count escape sequences as characters.
alias grep='grep --color=auto'

# Debian/Ubuntu ship bat as `batcat` because the name `bat` was already taken by
# an unrelated package (bacula-console-qt).
alias bat='batcat'

# NOTE: `alias cat='cat'` used to live here. It expanded to itself and changed
# nothing, so it was dropped. If the intent was to page files through bat, the
# useful form is:  alias cat='batcat --paging=never'
# Left commented because it changes `cat`'s behaviour in pipelines.

# zoxide's `z`: cd that learns the directories you actually use, so `z proj`
# jumps to ~/dev/some/deep/project after you've been there once.
alias cd='z'

# --- App shortcuts -----------------------------------------------------------
alias pdf='sioyek'       # Sioyek: keyboard-driven PDF reader tuned for papers
alias gmd='ghostwriter'  # Markdown editor with live preview

# --- General shortcuts -------------------------------------------------------
alias cls='clear'
alias h='history'

# Dump x86-64 assembly for a C file: -S stops after compiling, -fverbose-asm
# annotates each instruction with the variable names it came from.
alias getasm='gcc -S -O2 -fverbose-asm'
# For RISC-V, use the r5asm function below instead — it does more.

# --- gocryptfs encrypted directory -------------------------------------------
# Mounts ./encrypted (ciphertext on disk) onto ./unlocked (plaintext view).
# Both are relative paths, so cd into the directory holding them first.
alias unlockssd="gocryptfs ./encrypted ./unlocked"
alias lockssd="fusermount -u ./unlocked"  # unmount; ciphertext stays put

# --- Git shortcuts -----------------------------------------------------------
alias gs='git status'
alias ga='git add .'       # NOTE: stages everything under CWD, not just tracked
alias gc='git commit -m'   # usage: gc "message"
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'


# --- FUNCTIONS ---------------------------------------------------------------

# r5asm <file.c> — cross-compile C to RISC-V and open an interleaved C+asm view.
#
# Produces three files and drops you into the third, which is the one worth
# reading: objdump -S interleaves the original C source with the instructions it
# generated, so you can see what each line costs.
#
# -O0 is deliberate: optimisation reorders and deletes code until the mapping
# back to source is unrecognisable, which defeats the purpose when learning.
r5asm() {
	if [ -z "$1" ]; then
		echo "Usage: r5asm <file.c>"
		return 1
	fi

	file="$1"
	base="${file%.c}"  # strip the .c extension to build sibling filenames

	# Human-readable assembly, annotated with source variable names.
	riscv64-linux-gnu-gcc -S -O0 -g -fverbose-asm "$file" -o "${base}.s"

	# Executable with debug symbols — objdump needs these to interleave source.
	riscv64-linux-gnu-gcc -O0 -g "$file" -o "${base}.out"

	# The interleaved view: -d disassembles, -S pulls in the matching C lines.
	riscv64-linux-gnu-objdump -d -S "${base}.out" >"${base}.mix"

	echo "Generated:"
	echo "  ${base}.s   → verbose assembly"
	echo "  ${base}.mix → C + ASM (best for learning)"

	vim "${base}.mix"
}

# pipinst <pkg> — pip install into the system Python on Ubuntu 24.04.
#
# 24.04 marks its Python as "externally managed" (PEP 668) and refuses pip
# installs that could fight with apt-managed packages. --break-system-packages
# overrides that. It is the blunt instrument; a venv or `pipx install` is the
# safe option for anything you intend to keep.
pipinst() {
	python -m pip install --break-system-packages "$@"
}

# mkcd <dir> — create a directory (including parents) and cd into it.
mkcd() {
	mkdir -p "$1" && cd "$1"
}


# --- PROMPT ------------------------------------------------------------------
#
# Format: green "kairav/HH:MM:/current/dir$ ".
#   \e[32m  ANSI green      \A  24-hour HH:MM      \w  cwd, ~ abbreviated
#
# Two known flaws, left as-is because this block is dead anyway:
#   1. Colour is never reset — the trailing \e[32m re-opens green instead of
#      closing it with \e[0m, so typed commands inherit the colour.
#   2. The escapes are not wrapped in \[ \], so bash counts them toward the
#      prompt's printed width and miscalculates where the cursor is. That
#      corrupts the display when recalling long history lines.
#   A correct version would be: PS1='\[\e[32m\]kairav/\A:\w\$\[\e[0m\] '
PS1='\e[32mkairav/\A:\w\$\e[32m '


# --- History search on the arrow keys ----------------------------------------
# Up/Down search history for entries starting with what is already typed,
# instead of stepping blindly through every past command. Type "git c", press
# Up, and you walk only your git commits.
#   \e[A = Up arrow, \e[B = Down arrow
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'


# --- Toolchains and PATH -----------------------------------------------------

# nvm — Node Version Manager. Installs Node per-project rather than system-wide.
# Sourcing nvm.sh defines the `nvm` shell function and puts the active Node on
# PATH. It is slow (~0.5 s); see ~/.zshrc for the lazy-loading version.
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # loads completions

# pipx shims, cargo binaries, and other user-installed executables.
export PATH="$HOME/.local/bin:$PATH"

# Rust: puts ~/.cargo/bin (cargo, rustc, rustup, and everything `cargo install`
# has ever built) on PATH.
. "$HOME/.cargo/env"

# Added by the jcode installer — duplicates the ~/.local/bin line above.
export PATH="/home/kairav/.local/bin:$PATH"

# config_backup.py lives here; keeping it on PATH lets you call it by name.
export PATH=$PATH:/home/kairav/.local/share/config-backup/
