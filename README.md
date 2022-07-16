**Only support C++**

**Default timeout for TLE is 2s**

## Install via [vim-plug](https://github.com/junegunn/vim-plug)

```
Plug 'zangnn/cp-nvim'
```

## Basic setup

```
nnoremap <leader>cp :CpParse<CR>
augroup cpgroup
  autocmd!
  autocmd filetype cpp nnoremap <leader>1 :CpBuild "g++ --std=c++14 -O2 -Wshadow -Wall -Wextra -DLOCAL"<CR>
  autocmd filetype cpp nnoremap <leader>` :CpTest<CR>
augroup end
```
