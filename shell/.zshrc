# =============================================================================
# ~/.zshrc — interactive zsh configuration
# =============================================================================
#
# This is the file that actually shapes your shell. zsh is your login shell, so
# this runs for every terminal you open. (~/.bashrc only exists to hand bash
# sessions over to zsh — nothing in it is live.)
#
# zsh startup order:
#   ~/.zshenv    every zsh, even scripts   -> cargo env, GOPATH, ~/.local/bin
#   ~/.zprofile  login shells only         -> pipx + JetBrains Toolbox PATH
#   ~/.zshrc     interactive shells        -> this file
#
# ORDERING RULES — the two mistakes that are easy to make here:
#
#   1. `source $ZSH/oh-my-zsh.sh` installs its own keybindings and prompt.
#      Anything you set BEFORE that line gets overwritten. Custom bindkey and
#      prompt settings therefore live AFTER it.
#   2. fzf's key-bindings.zsh defines a function named `fzf-file-widget`. If you
#      source fzf after defining your own function of that name, fzf silently
#      replaces yours. fzf is therefore sourced BEFORE the custom widget below.
#
# Both of those were live bugs in an earlier version of this file: the custom
# Ctrl+F preview widget and the arrow-key history bindings were being defined
# and then immediately clobbered. The section order below is what keeps them
# working — if you reorganise this file, preserve it.
# -----------------------------------------------------------------------------


# =============================================================================
# 1. OH MY ZSH
# =============================================================================
# Framework providing the completion system, prompt themes and plugins.
# https://github.com/ohmyzsh/ohmyzsh/wiki

export ZSH="$HOME/.oh-my-zsh"

# Prompt theme. robbyrussell is omz's default: a ➜ arrow that turns red when the
# last command failed, the current directory, and git branch + dirty marker.
# Themes live in $ZSH/themes/. See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Treat - and _ as interchangeable when completing, so typing `foo_bar` matches
# a `foo-bar` command. Requires case-sensitive completion to stay off.
HYPHEN_INSENSITIVE="true"

# Plugins to load from $ZSH/plugins/. Each one costs startup time, so this is
# kept minimal.
#   git — ~150 git aliases plus branch/status completion.
# Worth considering: zsh-autosuggestions (ghost-text completion from history)
# and zsh-syntax-highlighting (colours commands red until they resolve).
plugins=(git)

# yazi ships shell completions into ~/.local/share/zsh/site-functions rather
# than the oh-my-zsh tree, so `omz update` can't wipe them. fpath (the search
# path for completion functions) has to grow BEFORE oh-my-zsh runs compinit,
# because compinit only scans fpath once.
fpath=("$HOME/.local/share/zsh/site-functions" $fpath)

# Loads the framework: runs compinit, applies the theme, sources the plugins.
# Everything above this line is configuration read by this script; everything
# below it is layered on top of what the framework set up.
source $ZSH/oh-my-zsh.sh


# =============================================================================
# 2. FZF — fuzzy finder
# =============================================================================
# Sourced here, after oh-my-zsh but before the custom widget below, for the
# reason given in the header: this file defines `fzf-file-widget` and would
# overwrite a custom definition that came first.
#
# ~/.fzf.zsh adds ~/.fzf/bin to PATH and sources fzf's completion and
# key-binding scripts. Stock bindings: Ctrl+T paste file path, Ctrl+R search
# history, Alt+C cd into a directory.
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Back fzf with fd instead of the default `find`. fd is faster, respects
# .gitignore (so node_modules and build output stay out of results), and
# --strip-cwd-prefix drops the "./" from every path.
if command -v fd >/dev/null; then
	export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix --exclude .git'
	export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# Global fzf appearance.
#   --height=60%     open as a pane below the prompt, not a fullscreen takeover
#   --layout=reverse prompt at the top, results reading downward
#   --ctrl-/         toggle the preview pane on demand
export FZF_DEFAULT_OPTS="
  --height=60% --layout=reverse --border=rounded
  --preview-window=right:50%:wrap
  --bind='ctrl-/:toggle-preview'
"

# Ctrl+T preview: syntax-highlighted first 100 lines.
#
# NOTE the binary name. On Ubuntu the executable is `batcat`, not `bat` — the
# `bat` name here is a shell *alias*, and aliases do not exist inside the
# subshell fzf spawns to run a preview. This block therefore tests and calls
# batcat directly, and falls back to `cat` so the preview never comes up blank.
if command -v batcat >/dev/null; then
	export FZF_CTRL_T_OPTS="--preview 'batcat --style=numbers --color=always --line-range :100 {} 2>/dev/null || cat {}'"
elif command -v bat >/dev/null; then
	export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :100 {} 2>/dev/null || cat {}'"
fi

# Ctrl+R (history search) appearance. The preview is hidden by default and
# toggled with Ctrl+/ — useful for reading a long pasted command before running.
export FZF_CTRL_R_OPTS="
  --preview 'echo {}' --preview-window down:3:hidden:wrap
  --bind 'ctrl-/:toggle-preview'
  --color header:italic
  --header 'Enter to run, Ctrl+/ to preview'
"


# =============================================================================
# 3. KEYBINDINGS AND CUSTOM WIDGETS
# =============================================================================
# Everything here runs after both oh-my-zsh and fzf, so these definitions win.

# Ctrl+F — fuzzy-find a file below the current directory and insert its path at
# the cursor. Complements fzf's stock Ctrl+T with a larger window and a preview
# pane that is open by default.
#
# A zsh "widget" is a function the line editor (zle) can invoke. LBUFFER is the
# text left of the cursor; appending to it inserts without disturbing anything
# already typed to the right.
fzf-file-widget-preview() {
	local selected

	selected=$(
		# Prefer fd (fast, honours .gitignore); fall back to find.
		if command -v fd >/dev/null; then
			fd --type f --hidden --exclude .git
		else
			find . -type f -not -path '*/.git/*' 2>/dev/null
		fi |
			fzf \
				--height 70% \
				--layout=reverse \
				--border=rounded \
				--preview 'batcat --style=numbers --color=always --line-range=:200 {} 2>/dev/null || cat {} 2>/dev/null || file {}' \
				--preview-window='right:60%'
	) || return  # non-zero exit means Esc/Ctrl+C — leave the line untouched

	LBUFFER="${LBUFFER}${selected#./}"  # ${...#./} strips a leading "./"
	zle reset-prompt                     # repaint the prompt fzf drew over
}

zle -N fzf-file-widget-preview  # register the function as a zle widget
bindkey '^F' fzf-file-widget-preview

# Up/Down search history for entries starting with what you have already typed.
# Type "git com", press Up, and you step only through matching commands.
#
# oh-my-zsh binds these to up-line-or-beginning-search by default, which does
# the same prefix search but also keeps the cursor at the end of the recalled
# line. These lines override that with the simpler history-search variants.
# Delete them to go back to omz's behaviour — it is arguably the better one.
bindkey "^[[A" history-search-backward
bindkey "^[[B" history-search-forward


# =============================================================================
# 4. PROMPT
# =============================================================================
# The live prompt comes from the robbyrussell theme set in section 1. Nothing is
# assigned here.
#
# This file previously carried:
#     PS1='\e[32mkairav/\A:\w\$\e[32m '
# which never took effect for two reasons: it sat above `source oh-my-zsh.sh`
# (which reassigns PS1), and the escapes are bash syntax. zsh does not expand
# \e, \A or \w in a prompt — it would have printed those six characters
# literally. The zsh spelling of the same idea, if you ever want it, is:
#
#     PROMPT='%F{green}kairav/%T:%~%#%f '
#
# with %F{green}/%f for colour, %T for HH:MM, %~ for the cwd and %# for the
# %/# privilege marker. Setting that would replace robbyrussell's prompt,
# including its git branch display.


# =============================================================================
# 5. ALIASES
# =============================================================================

# --- Modern coreutils replacements -------------------------------------------
# eza: Rust `ls` with git integration, tree mode and better default colours.
alias ls='eza'
alias ll='eza -alF'  # long listing, dotfiles included, type indicators
alias la='eza -A'    # all entries except . and ..
alias l='eza -CF'    # brief multi-column listing

# --color=auto keeps colour on a terminal and drops it when piped, so escape
# codes never end up counted by `wc` or matched by a downstream grep.
alias grep='grep --color=auto'

# Ubuntu ships bat as `batcat`; the `bat` name belongs to another package.
# Remember this alias is interactive-only — scripts and fzf previews must call
# batcat directly (see the FZF_CTRL_T_OPTS note above).
alias bat='batcat'

# zoxide's `z`: a cd that ranks directories by how often you visit them, so
# `cd proj` lands in ~/dev/some/deep/project once you have been there. Plain
# paths, `cd ..` and `cd -` all still work. Initialised in section 7.
alias cd='z'

# --- Application shortcuts ---------------------------------------------------
alias pdf='sioyek'       # keyboard-driven PDF reader, good for papers
alias gmd='ghostwriter'  # markdown editor with live preview

# --- General -----------------------------------------------------------------
alias cls='clear'
alias h='history'

# x86-64 assembly for a C file: -S stops after compilation, -fverbose-asm
# annotates instructions with the source variables they came from.
alias getasm='gcc -S -O2 -fverbose-asm'
# For RISC-V use the r5asm function in section 6 — it does considerably more.

# --- gocryptfs encrypted directory -------------------------------------------
# Mounts ./encrypted (ciphertext at rest) as ./unlocked (plaintext view).
# Both paths are relative, so cd to the directory containing them first.
alias unlockssd="gocryptfs ./encrypted ./unlocked"
alias lockssd="fusermount -u ./unlocked"  # unmount; ciphertext is untouched

# --- Git ---------------------------------------------------------------------
# The omz git plugin already provides gst/gaa/gcmsg/etc.; these are the shorter
# spellings you actually type. Defined after the plugin loads, so they win.
alias gs='git status'
alias ga='git add .'      # stages everything under CWD — check `gs` first
alias gc='git commit -m'  # usage: gc "message"
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'


# =============================================================================
# 6. FUNCTIONS
# =============================================================================

# r5asm <file.c> — cross-compile C to RISC-V and open an interleaved C+asm view.
#
# Writes three files and opens the third, which is the interesting one: objdump
# -S interleaves each C line with the instructions it produced.
#
# -O0 is deliberate. With optimisation on, gcc reorders, inlines and deletes
# code until the mapping back to source is unreadable — which defeats the point.
r5asm() {
	if [ -z "$1" ]; then
		echo "Usage: r5asm <file.c>"
		return 1
	fi

	file="$1"
	base="${file%.c}"  # drop the .c to name the sibling outputs

	# Readable assembly, annotated with the originating variable names.
	riscv64-linux-gnu-gcc -S -O0 -g -fverbose-asm "$file" -o "${base}.s"

	# Executable with debug info — objdump needs it to interleave source.
	riscv64-linux-gnu-gcc -O0 -g "$file" -o "${base}.out"

	# -d disassembles; -S pulls the matching C lines in alongside.
	riscv64-linux-gnu-objdump -d -S "${base}.out" >"${base}.mix"

	echo "Generated:"
	echo "  ${base}.s   → verbose assembly"
	echo "  ${base}.mix → C + ASM (best for learning)"

	vim "${base}.mix"
}

# mkcd <dir> — create a directory tree and enter it.
#
# `builtin cd` is used rather than plain `cd` on purpose. zsh expands aliases
# when a function is *parsed*, and `alias cd='z'` above is already in effect by
# then, so a bare `cd` here would compile to `z` and route a brand-new directory
# through zoxide's ranking database. `builtin` bypasses both alias and function
# lookup and calls zsh's own cd.
mkcd() {
	mkdir -p "$1" && builtin cd "$1"
}

# pipinst <pkg> — pip install into the system Python.
#
# Ubuntu 24.04 marks its Python "externally managed" (PEP 668) and blocks pip
# installs that could collide with apt-managed packages. This flag overrides
# that guard. Fine for a throwaway; for anything you intend to keep, prefer a
# venv or `pipx install`, which cannot break system packages.
pipinst() {
	python -m pip install --break-system-packages "$@"
}

# notify-build <command…> — run a command and raise a desktop notification with
# the result. Useful for long builds you walk away from:
#     notify-build make -j8
# Notifications are rendered by mako (~/.config/mako/config), which has an
# app-name="Build" rule making a click focus the Ghostty window.
notify-build() {
	local cmd="$*"
	if eval "$cmd"; then
		notify-send -a "Build" -u normal -i software-update-available "Build succeeded" "$cmd"
	else
		notify-send -a "Build" -u critical -i dialog-error "Build failed" "$cmd"
	fi
}

# y — yazi wrapper that leaves the shell in the directory you browsed to.
#
# yazi writes its final directory to the --cwd-file path on exit; this reads it
# and cd's there. Quitting with Q skips that write, so Q means "leave my shell
# where it was" and q means "follow me". `builtin cd` for the same reason as in
# mkcd: the `cd` alias would otherwise route this through zoxide.
function y() {
	local tmp cwd
	tmp="$(mktemp -t "yazi-cwd.XXXXXX")" || return
	yazi "$@" --cwd-file="$tmp"
	if IFS= read -r -d '' cwd <"$tmp" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd" || return
	fi
	rm -f -- "$tmp"
}


# =============================================================================
# 7. TOOLCHAINS, PATH AND ENVIRONMENT
# =============================================================================
#
# NOTE: several entries below are already exported by ~/.zshenv and ~/.zprofile,
# which run first. zsh does not deduplicate PATH by default, so ~/.local/bin
# currently appears six times. It is harmless but it does mean six stat() calls
# per directory on every command lookup. To collapse duplicates, add:
#     typeset -U path PATH
# near the top of ~/.zshenv — the -U (unique) flag makes zsh drop repeats
# automatically, keeping the first occurrence.

# --- Java --------------------------------------------------------------------
# default-java is a symlink managed by update-alternatives, so this keeps
# pointing at whichever JDK is current instead of a hardcoded version.
export JAVA_HOME=/usr/lib/jvm/default-java
export PATH=$JAVA_HOME/bin:$PATH

# --- pipx --------------------------------------------------------------------
# pipx installs Python CLI tools into isolated venvs and shims them here.
export PATH="$PATH:/home/kairav/.local/bin"

# --- Node / nvm --------------------------------------------------------------
# nvm manages multiple Node versions side by side. Sourcing nvm.sh defines the
# `nvm` function and puts the selected version's bin directory on PATH.
#
# PERFORMANCE: this is by far the most expensive thing in this file — roughly
# 840 ms of the ~1 s shell startup, mostly nvm_auto resolving the default
# version. Lazy-loading it (defining stub functions that source nvm.sh on first
# use of node/npm/npx) removes essentially all of that.
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                    # loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # completions

# --- Other toolchains --------------------------------------------------------
# ~/bin was merged into ~/.local/bin, which .zshenv already puts on PATH.
export PATH="/opt/zig:$PATH"                   # Zig compiler, manual install
export PATH="$HOME/.local/opt/godot:$PATH"     # Godot engine, manual install

# Lets Ollama offload model layers onto the Intel integrated GPU rather than
# running purely on CPU.
export OLLAMA_IGPU_ENABLE=1

# Caps opencode's per-response output. Keeps replies short and cheap; raise it
# if you find answers getting truncated mid-thought.
export OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=4096

# config_backup.py lives here — the script `just backup` drives.
export PATH=$PATH:/home/kairav/.local/share/config-backup/

# --- zoxide ------------------------------------------------------------------
# Defines the `z` function that `alias cd='z'` above points at, and installs the
# hook that records each directory you visit. Must come after PATH is settled so
# the zoxide binary in ~/.local/bin is findable.
eval "$(zoxide init zsh --cmd z)"
