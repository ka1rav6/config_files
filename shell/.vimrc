" =============================================================================
" ~/.vimrc — plain Vim configuration
" =============================================================================
" This configures /usr/bin/vim only. Neovim is configured entirely separately
" in ~/.config/nvim (a LazyVim setup) and does not read this file.
"
" Vim here is the fast-path editor: git commit messages, a quick sudoedit, and
" the `r5asm` function in ~/.zshrc which opens generated assembly. Neovim is the
" one to reach for on real work.
"
" Syntax: `"` starts a comment. `set x` enables, `set nox` disables,
" `set x=val` assigns. Check any current value with `:set x?`, and read the
" documentation for any option with `:help x`.
" =============================================================================


" --- Line numbers ------------------------------------------------------------
set number              " absolute line number in the left gutter
" Consider also: `set relativenumber`, which numbers lines relative to the
" cursor and turns motions into direct reads — 7j instead of counting rows.


" --- Indentation -------------------------------------------------------------
set tabstop=4           " a literal tab character renders 4 columns wide
set shiftwidth=4        " >> and << shift by 4; autoindent uses this too
set expandtab           " pressing Tab inserts spaces, never a tab character
set autoindent          " new lines inherit the previous line's indent
set smartindent         " additionally indent after `{`, and outdent on `}`
" NOTE: expandtab means this file's own indentation is spaces. In a repository
" that requires real tabs (Go, Makefiles), Vim will silently do the wrong thing
" — Makefiles in particular *require* tabs and will break. Guard with:
"   autocmd FileType make,go setlocal noexpandtab


" --- Searching ---------------------------------------------------------------
set ignorecase          " searches are case-insensitive by default
set smartcase           " ...unless the pattern contains a capital, then exact.
                        " Together: /error matches Error, /Error matches only Error.
set incsearch           " jump to matches as you type, before pressing Enter
set hlsearch            " keep every match highlighted after the search
" hlsearch leaves the screen lit up until the next search. Clear it with :noh —
" worth mapping:  nnoremap <silent> <Esc> :noh<CR>


" --- Colours -----------------------------------------------------------------
syntax on               " enable syntax highlighting
set termguicolors       " use 24-bit colour rather than the 256-colour palette.
                        " Ghostty supports true colour, so this makes themes
                        " render at their intended colours. Inside tmux it
                        " depends on the terminal-overrides in ~/.tmux.conf,
                        " which are set correctly.
set background=dark     " tells colourschemes to pick their dark variant
colorscheme elflord     " a built-in scheme — always present, no plugin needed


" --- Persistent files --------------------------------------------------------
set undofile            " undo history survives closing the file. Written to
                        " ~/.vim/undodir if it exists, otherwise beside the
                        " file as .file.un~ — clutter worth avoiding. See below.
set backup              " keep a backup of the previous version after writing
set writebackup         " write to a temp file first, then rename over the
                        " original, so a crash mid-write cannot truncate it
set swapfile            " crash-recovery journal, also the multiple-edit guard
" These three scatter .un~, ~ and .swp files into whatever directory you are
" editing, which then show up in git status. Corral them centrally with:
"   set undodir=~/.vim/undo//
"   set backupdir=~/.vim/backup//
"   set directory=~/.vim/swap//
" (create those directories first; the trailing // encodes the full path into
" the filename so same-named files in different projects do not collide)


" --- Window splitting --------------------------------------------------------
set splitbelow          " :split puts the new window below, not above
set splitright          " :vsplit puts the new window right, not left
                        " Matches the reading order most people expect.


" --- Scrolling and display ---------------------------------------------------
set scrolloff=8         " keep 8 lines visible above/below the cursor, so you
                        " always have context instead of editing at the edge
set sidescrolloff=8     " same, horizontally, when nowrap is on
set nowrap              " long lines run off-screen rather than folding round.
                        " Good for code, awkward for prose — toggle with :set wrap
set signcolumn=yes      " always reserve the sign gutter. Without this the text
                        " jogs one column sideways whenever a git or lint sign
                        " appears, which is visually noisy.


" --- Interface ---------------------------------------------------------------
set cursorline          " highlight the line the cursor is on
set showcmd             " show the partially-typed command bottom-right, so a
                        " half-finished `d2` is visible rather than a mystery
set ruler               " show line,column position in the status line
set wildmenu            " tab-completion for : commands shows a scrollable menu
set mouse=a             " enable the mouse in all modes: click to position,
                        " drag to select, drag borders to resize splits.
                        " Note this takes over selection from the terminal —
                        " hold Shift to get Ghostty's own selection back for
                        " copying out.


" --- Plugins -----------------------------------------------------------------
" vim-plug, guarded so this file still loads cleanly on a machine where the
" plugin manager was never installed. Without the guard, Vim throws an error on
" every startup — which is exactly the kind of breakage that makes a config feel
" fragile when you are on a fresh box.
"
" To install vim-plug:
"   curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
"     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
" Then run :PlugInstall
if filereadable(expand('~/.vim/autoload/plug.vim'))
  call plug#begin('~/.vim/plugged')

  " NERDTree — a file-tree sidebar, toggled with :NERDTreeToggle.
  " (Not currently bound to a key; `nnoremap <C-n> :NERDTreeToggle<CR>` is the
  " conventional binding if you want one.)
  Plug 'preservim/nerdtree'

  call plug#end()
endif


" --- Clipboard ---------------------------------------------------------------
" Route yank and put through the system clipboard, so y in Vim and Ctrl+V in a
" browser are the same buffer.
"
" `unnamedplus` is the correct choice on Linux: it targets the CLIPBOARD
" selection (Ctrl+C/Ctrl+V), whereas plain `unnamed` targets PRIMARY
" (middle-click). On Wayland this needs a bridge binary — wl-clipboard, i.e.
" wl-copy/wl-paste, which is installed here and already used by the cliphist
" watchers in ~/.config/hypr/autostart.lua. Verify with :echo has('clipboard').
set clipboard=unnamedplus
