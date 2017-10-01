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
" colorscheme solarized

	" Badwolf Theme
colorscheme badwolf
let g:badwolf_darkgutter = 1 " Make the gutters darker than the background.
let g:airline_theme='bubblegum'

" Look of VIM
set list                     " Show list characters
set listchars=tab:▸·,trail:· " Tabs as ▸·, trailing spaces as dots
set number                   " Show LINE Numbers
"Highlight Whitespace properly
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/
autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhitespace /\s\+$/
autocmd BufWinLeave * call clearmatches()

"Feel/Behavior of VIM
syntax enable
set wildmenu      " visual autocomplete for command menu
set showmatch     " highlight matching closing item (ie brace, paran, etc)
set hlsearch      " search: highlight matches
filetype plugin on " Detect file type for syntax and commenting
set timeout " Time out of :mappings
set timeoutlen=2500 " Set time out of :mappings (i.e. leader) to 2.5 seconds
set ttimeout " Time out on keycodes

" Collapsing (folding) behavior
set foldenable          " enable folding
set foldlevelstart=10   " open most folds by default
set foldnestmax=10      " 10 nested fold max

" Commenting behavior
let g:NERDCommentEmptyLines = 1 " Allow commenting and inverting empty lines
let g:NERDDefaultAlign = 'left' " Comments are aligned to left instead of code indentation

" Tab Functionality
set tabstop=2     " number of visual spaces per TAB
set softtabstop=2 " number of spaces in tab when editing
set noexpandtab " Tab behavior: noexpandtab = Use tabs not spaces
set binary " Open file in binary mode to avoid manipulating EOL

" Tools/Plugins:

	" Toggle gundo ',u'
nnoremap <leader>u :GundoToggle<CR>

	" Ack - Use Silver Searcher if available
if executable('ag')
	let g:ackprg = 'ag --nogroup --nocolor --column'
endif

" Shortcut keys/commands
command Convert2unix :set ff=unix " convert to unix file endings
command ConvertSpaceTabstoTabs call RetabIndents() " convert indent spaces into tabs
command ToggleGuttersandChars :GitGutterSignsToggle | set invnumber | set list! " Toggle Git Gutter Signs, Line Numbers, Hidden Chars
command TrimWhiteSpace call TrimWhitespace()
noremap <leader>n :ToggleGuttersandChars<CR>

" search: exit highlighted results (,Return)
nnoremap <leader><CR> :nohlsearch<CR>

" open ag.vim (,a)
nnoremap <leader>a :Ack!<space>

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

fun! TrimWhitespace()
    let l:save = winsaveview()
    %s/\s\+$//e
    call winrestview(l:save)
endfun
