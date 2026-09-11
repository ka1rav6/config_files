" =============================================================================
" ~/.vimrc — plain Vim configuration
" =============================================================================
" This configures /usr/bin/vim only. Neovim is configured entirely separately
" in ~/.config/nvim (a LazyVim setup) and does not read this file.
"
" MUST STAY SAFE UNDER vim.tiny.
" Ubuntu ships several vim builds, and `crontab -e` / `select-editor` can land
" on any of them:
"     vim.gtk3   full build, what /usr/bin/vim points at here
"     vim.basic  no GUI, most features
"     vim.tiny   NO +eval, NO +syntax, almost nothing
" vim.tiny has no scripting engine at all, so `has()`, `if has(...)` and
" `silent!` are themselves unavailable — a config full of feature guards still
" explodes on it.
"
" The fix is Vim's own documented idiom, used in its stock defaults.vim:
" a build without +eval treats `if` as always-false and skips straight to the
" matching `endif` without parsing what is inside. So everything that needs
" scripting, syntax or a colourscheme goes inside `if 1 ... endif`, and only
" universally-supported `set` options live outside it.
"
" Verify after editing — all three must print nothing:
"     vim.tiny  -u ~/.vimrc -c 'qa!'
"     vim.basic -u ~/.vimrc -c 'qa!'
"     vim.gtk3  -u ~/.vimrc -c 'qa!'
"
" Syntax: `"` starts a comment. `set x` enables, `set nox` disables,
" `set x=val` assigns. Check a value with `:set x?`, read docs with `:help x`.
" =============================================================================


" =============================================================================
" PART 1 — options every Vim build understands, including vim.tiny
" =============================================================================

" --- Line numbers ------------------------------------------------------------
set number              " absolute line number in the left gutter

" --- Indentation -------------------------------------------------------------
set tabstop=4           " a literal tab renders 4 columns wide
set shiftwidth=4        " >> and << shift by 4
set expandtab           " pressing Tab inserts spaces, never a tab character
set autoindent          " new lines inherit the previous line's indent
" NOTE: expandtab means Makefiles get spaces, and make *requires* real tabs.
" The autocmd that fixes this needs +eval, so it lives in Part 2 below.

" --- Searching ---------------------------------------------------------------
set ignorecase          " searches are case-insensitive by default
set incsearch           " jump to matches as you type

" --- Scrolling ---------------------------------------------------------------
set scrolloff=8         " keep 8 lines of context above/below the cursor
set nowrap              " long lines run off-screen rather than folding round

" --- Window splitting --------------------------------------------------------
set splitbelow          " :split opens below, not above
set splitright          " :vsplit opens right, not left

" --- Interface ---------------------------------------------------------------
set showcmd             " show the partially-typed command bottom-right
set ruler               " line,column position in the status line
set background=dark     " tell colourschemes to pick their dark variant

" --- Crash safety ------------------------------------------------------------
set swapfile            " recovery journal, also the concurrent-edit guard


" =============================================================================
" PART 2 — everything requiring a scripting engine
" =============================================================================
" `if 1` is not decoration. A Vim compiled without +eval skips this entire
" block without parsing it, which is exactly what makes vim.tiny survive.
" Builds that DO have +eval take the branch and run it all.
if 1

  " --- Syntax highlighting ---------------------------------------------------
  " Guarded again inside: vim.basic has +eval but a build could still lack
  " +syntax, and `syntax on` there raises E319.
  if has('syntax')
    syntax on
    " elflord is a built-in scheme — always present, needs no plugin. Wrapped
    " in silent! so a missing scheme warns nothing and leaves the default.
    silent! colorscheme elflord
  endif

  " 24-bit colour instead of the 256-colour palette. Ghostty supports true
  " colour, so themes render at their intended values. Inside tmux this relies
  " on the terminal-overrides in ~/.tmux.conf, which are set correctly.
  if has('termguicolors')
    set termguicolors
  endif

  " --- Smarter search/indent (need +extra_search / +smartindent) -------------
  if has('extra_search')
    set hlsearch        " keep every match highlighted after searching
    " hlsearch stays lit until the next search. Esc clears it.
    nnoremap <silent> <Esc> :nohlsearch<CR>
  endif
  set smartcase         " a capital in the pattern makes the search exact
  set smartindent       " indent after `{`, outdent on `}`

  " --- Display polish --------------------------------------------------------
  set sidescrolloff=8   " horizontal context when nowrap is on
  set cursorline        " highlight the line the cursor is on
  set wildmenu          " tab-completion for : commands shows a menu

  " Always reserve the sign gutter, so text does not jog sideways when a git or
  " lint sign appears. +signs is not in every build.
  if has('signs')
    set signcolumn=yes
  endif

  " Mouse: click to position, drag to select, drag borders to resize splits.
  " Hold Shift to get Ghostty's own selection back for copying out.
  if has('mouse')
    set mouse=a
  endif

  " --- Persistent files ------------------------------------------------------
  " backup/writebackup/undofile otherwise scatter ~, .un~ and .swp files into
  " whatever directory you are editing, where they show up in git status.
  " These keep them in one place instead. The // suffix encodes the full path
  " into the filename, so same-named files in different projects never collide.
  set backup
  set writebackup
  if has('persistent_undo')
    set undofile
  endif

  " Create the directories on first run — Vim does not make them itself, and
  " silently falls back to the edited file's directory if they are missing.
  if !isdirectory(expand('~/.vim/backup'))
    silent! call mkdir(expand('~/.vim/backup'), 'p', 0700)
  endif
  if !isdirectory(expand('~/.vim/undo'))
    silent! call mkdir(expand('~/.vim/undo'), 'p', 0700)
  endif
  if !isdirectory(expand('~/.vim/swap'))
    silent! call mkdir(expand('~/.vim/swap'), 'p', 0700)
  endif
  set backupdir=~/.vim/backup//
  set directory=~/.vim/swap//
  if has('persistent_undo')
    set undodir=~/.vim/undo//
  endif

  " --- Filetype fixes --------------------------------------------------------
  " Makefiles and Go require real tabs; expandtab above would silently break
  " them. autocmd needs +autocmd, which implies +eval.
  if has('autocmd')
    filetype plugin indent on
    augroup vimrc_filetypes
      autocmd!
      autocmd FileType make,go setlocal noexpandtab
      " Git commit messages: wrap the body at 72 columns, start at the top.
      autocmd FileType gitcommit setlocal textwidth=72 | call cursor(1, 1)
    augroup END
  endif

  " --- Clipboard -------------------------------------------------------------
  " Route yank/put through the system clipboard so y in Vim and Ctrl+V in a
  " browser share a buffer. `unnamedplus` targets CLIPBOARD (Ctrl+C/Ctrl+V);
  " plain `unnamed` would target PRIMARY (middle-click). On Wayland this needs
  " wl-clipboard, which is installed and already used by the cliphist watchers
  " in ~/.config/hypr/autostart.lua.
  if has('clipboard')
    set clipboard=unnamedplus
  endif

  " --- Plugins ---------------------------------------------------------------
  " vim-plug, guarded so this file still loads cleanly where it was never
  " installed. Install it with:
  "   curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  "     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  " then run :PlugInstall
  if filereadable(expand('~/.vim/autoload/plug.vim'))
    call plug#begin('~/.vim/plugged')

    " NERDTree — file-tree sidebar. Ctrl+N toggles it.
    Plug 'preservim/nerdtree'

    call plug#end()
    nnoremap <silent> <C-n> :NERDTreeToggle<CR>
  endif

endif
