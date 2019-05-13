" Centralize backups, swapfiles and undo history
set backupdir=~/.vim/backups
set directory=~/.vim/swaps
if exists("&undodir")
	set undodir=~/.vim/undo
endif

let mapleader="," " leader is comma
set viminfo=      " set viminfo file to nothing

" Detect Unix type
if has("unix")
	let s:uname = system("echo -n \"$(uname -s)\"")
endif

" Enable Pathogen (needs to be at top)
execute pathogen#infect()

" Color Theme
set background=dark
colorscheme badwolf
let g:badwolf_darkgutter = 1 " Make the gutters darker than the background.

" VIM Airline:
let g:airline_theme='bubblegum'
let g:airline#extensions#tabline#enabled = 1 " airline: Enable the list of buffers
let g:airline#extensions#tabline#fnamemod = ':t' " airline: Show just the filename
let g:airline#extensions#whitespace#enabled = 0 " airline: Disable whitespace checks

" Look of VIM
set cursorline               " Highlight current line
set list                     " Show list characters
set listchars=tab:▸·,trail:·,eol:¬ " Tabs as ▸·, trailing spaces as dots, and show EOLs
set number                   " Show LINE Numbers
set title                    " Show filename in title
set showcmd                  " Show shortcut/cmd in bottom right as its being typed

" Enable syntax highlighting
if !exists("g:syntax_on")
    syntax enable
endif

"Highlight Whitespace properly
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/
autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhitespace /\s\+$/
autocmd BufWinLeave * call clearmatches()

"Feel/Behavior of VIM
set nostartofline " Don't reset cursor to start of line when moving around
set wildmenu      " visual autocomplete for command menu
set showmatch     " highlight matching closing item (ie brace, paran, etc)

" File type handling
filetype plugin on " Detect file type for syntax and commenting
au FileType * set fo-=c fo-=r fo-=o " Disable auto commenting lines
autocmd BufNewFile,BufRead *.json setfiletype json syntax=javascript " Treat .json files as .js
autocmd BufNewFile,BufRead *.md setlocal filetype=markdown " Treat .md files as Markdown

" Timeout behavior
set timeout " Time out of :mappings
set timeoutlen=2500 " Set time out of :mappings (i.e. leader) to 2.5 seconds
set ttimeout " Time out on keycodes

" Search behavior
set incsearch     " search as you type
set hlsearch      " search: highlight matches
set ignorecase    " search: Ignore case (affects MATCHES)
set smartcase     " search: Ignore case UNLESS use cap in search

" Collapsing (folding) behavior
set foldenable          " enable folding
set foldlevelstart=10   " open most folds by default
set foldnestmax=10      " 10 nested fold max

" Tab Functionality
set tabstop=2     " number of visual spaces per TAB
set softtabstop=2 " number of spaces in tab when editing
set noexpandtab " Tab behavior: noexpandtab = Use tabs not spaces
set binary " Open file in binary mode to avoid manipulating EOL

" Shortcut keys/commands
command Convert2unix :set ff=unix " convert to unix file endings
command ConvertSpaceTabstoTabs call RetabIndents() " convert indent spaces into tabs
command TrimWhiteSpace call TrimWhitespace()
command SudoWriteFile :execute ':silent w !sudo tee % > /dev/null' | :edit!

" Toggle Line Numbers, Hidden Chars (handy for copying text)
function ToggleGuttersandChars()
	:set invnumber
	:set list!
endfunction
noremap <leader>t<space> :call ToggleGuttersandChars()<CR>

" search: exit highlighted results (,Return)
nnoremap <leader><CR> :nohlsearch<CR>

" Select all text (Ctrl+A)
map <C-a> <esc>gg0vG$<CR>

" OSX: Cut/Copy text to clipboard using pbcopy (ctrl+x/ctrl+c)
if !v:shell_error && s:uname == "Darwin"
	vmap <C-x> :!pbcopy<CR>
	vmap <C-c> :w !pbcopy<CR><CR>
endif

" Custom Functions
func! RetabIndents()
		let saved_view = winsaveview()
		execute '%s@^\(\ \{'.&ts.'\}\)\+@\=repeat("\t", len(submatch(0))/'.&ts.')@e'
		call winrestview(saved_view)
endfunc

func! TrimWhitespace()
    let l:save = winsaveview()
    %s/\s\+$//e
    call winrestview(l:save)
endfunc
