let mapleader=","       " leader is comma

" Enable Pathogen (needs to be at top)
execute pathogen#infect()

" Theme (Look/Colors)
set background=dark
" colorscheme solarized

  " Badwolf Theme
colorscheme badwolf
let g:badwolf_darkgutter = 1 " Make the gutters darker than the background.

" Feel of VIM
syntax enable
set wildmenu      " visual autocomplete for command menu
set showmatch     " highlight matching closing item (ie brace, paran, etc)
set hlsearch      " search: highlight matches

" Code collapsing (folding) behavior
set foldenable          " enable folding
set foldlevelstart=10   " open most folds by default
set foldnestmax=10      " 10 nested fold max

set number        " LINE Numbers


" Functionality
set tabstop=2     " number of visual spaces per TAB
set softtabstop=2 " number of spaces in tab when editing
set expandtab     " tabs are spaces
command Convert2unix :set ff=unix " convert to unix file endings

" Tools/Plugins:

  " Toggle gundo ',u'
nnoremap <leader>u :GundoToggle<CR>

  " Ack - Use Silver Searcher if available
if executable('ag')
  let g:ackprg = 'ag --vimgrep'
endif



" Shortcut keys

" search: exit highlighted results (,a)
nnoremap <leader><CR> :nohlsearch<CR>

" open ag.vim (,a)
nnoremap <leader>a :Ack!<space>
