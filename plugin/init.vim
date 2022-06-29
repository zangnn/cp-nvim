if exists('g:loaded')
  finish
endif

let s:save_cpo = &cpo " save user coptions
set cpo&vim           " reset them to defaults

command! CpParse lua require"init".parse()
command! CpTest lua require"init".test()
command! -nargs=* CpBuild lua require"init".build(<args>)
command! CpRemove lua require"init".remove()
command! CpRemoveAll lua require"init".remove_all()

let &cpo = s:save_cpo " and restore after
unlet s:save_cpo

let g:loaded = 1
