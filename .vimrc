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
set incsearch     " search as you type
set hlsearch      " search: highlight matches
set ignorecase    " search: Ignore case (affects MATCHES)
set smartcase     " search: Ignore case UNLESS use cap in search
filetype plugin on " Detect file type for syntax and commenting
au FileType * set fo-=c fo-=r fo-=o " Disable auto commenting lines
autocmd BufNewFile,BufRead *.json setfiletype json syntax=javascript " Treat .json files as .js
autocmd BufNewFile,BufRead *.md setlocal filetype=markdown " Treat .md files as Markdown
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

" Centralize backups, swapfiles and undo history
set backupdir=~/.vim/backups
set directory=~/.vim/swaps
if exists("&undodir")
	set undodir=~/.vim/undo
endif

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
command TrimWhiteSpace call TrimWhitespace()
command SudoWriteFile :execute ':silent w !sudo tee % > /dev/null' | :edit!

" Toggle Git Gutters, Line Numbers, Hidden Chars, NERDTree (handy for copying text)
function ToggleGuttersandChars()
	" Is NERDTree in focus?
	if (exists("t:NERDTreeBufName") && bufwinnr(t:NERDTreeBufName) == winnr())
		wincmd p
	endif
	:set invnumber
	:set list!
	:GitGutterSignsToggle
	" Is NERDTree present in current tab?
	if (exists("t:NERDTreeBufName"))
		:NERDTreeToggle
	endif
	" Is NERDTree in focus?
	if (exists("t:NERDTreeBufName") && bufwinnr(t:NERDTreeBufName) == winnr())
		wincmd p
	endif
endfunction
noremap <leader>t<space> :call ToggleGuttersandChars()<CR>

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

" Autostart NERDTree
autocmd vimenter * NERDTree
" Jump to the main window.
autocmd VimEnter * wincmd p
" Close if NERDTree is only other tab
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
" Show hidden files in NERDTree
let NERDTreeShowHidden=1

" TAB switch shortcuts using <leader>+number
noremap <leader>1 1gt
noremap <leader>2 2gt
noremap <leader>3 3gt
noremap <leader>4 4gt
noremap <leader>5 5gt
noremap <leader>6 6gt
noremap <leader>7 7gt
noremap <leader>8 8gt
noremap <leader>9 9gt
noremap <leader>0 :tablast<cr>

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
