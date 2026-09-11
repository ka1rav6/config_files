# =============================================================================
# ~/.zshenv — read by EVERY zsh, including non-interactive scripts
# =============================================================================
# This is the earliest and most widely-read of the zsh startup files. It runs
# for interactive shells, for `zsh -c '...'`, and for any script with a zsh
# shebang.
#
# Because it runs everywhere, keep it to environment variables only. Anything
# that prints output, prompts, or takes measurable time belongs in ~/.zshrc
# instead — output here breaks scp, rsync and other tools that parse a remote
# shell's stream.
#
# Order: .zshenv (always) -> .zprofile (login) -> .zshrc (interactive)
# =============================================================================

# Collapse duplicate PATH entries.
#
# `path` is zsh's array view of PATH, and the two stay linked. The -U (unique)
# flag makes zsh drop any repeat as it is added, keeping the first occurrence
# and therefore preserving precedence.
#
# This matters here because ~/.local/bin is exported from four different files
# (this one, .zprofile, .zshrc and the jcode installer's line below) and was
# appearing six times in PATH. Every duplicate is another directory the shell
# stats on every command lookup that misses.
typeset -U path PATH

# Rust toolchain: puts ~/.cargo/bin on PATH — cargo, rustc, rustup, plus every
# binary `cargo install` has produced (waycal, among others).
. "$HOME/.cargo/env"

# Added by the jcode installer. Kept ahead of the system directories so
# user-installed tools win over distro ones.
export PATH="/home/kairav/.local/bin:$PATH"

# Go workspace. Overrides the default ~/go, keeping module cache, source and
# compiled binaries under ~/.local/share instead of adding another top-level
# directory to $HOME.
#
# NOTE: $GOPATH/bin is where `go install` places binaries, and it is NOT on
# PATH. If you install Go tools, add:
#     export PATH="$GOPATH/bin:$PATH"
export GOPATH="$HOME/.local/share/go"
