" fugitive.vim - A Git wrapper so awesome, it should be illegal
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      2.4
" GetLatestVimScripts: 2975 1 :AutoInstall: fugitive.vim

if exists('g:loaded_fugitive')
  finish
endif
let g:loaded_fugitive = 1

function! s:shellslash(path) abort
  if &shell =~? 'cmd' || exists('+shellslash') && !&shellslash
    return tr(a:path, '\', '/')
  else
    return a:path
  endif
endfunction

function! FugitiveGitDir(...) abort
  if !a:0 || a:1 ==# -1
    return get(b:, 'git_dir', '')
  elseif type(a:1) == type(0)
    return getbufvar(a:1, 'git_dir')
  elseif type(a:1) == type('')
    return substitute(s:shellslash(a:1), '/$', '', '')
  else
    return ''
  endif
endfunction

function! FugitiveIsGitDir(path) abort
  let path = substitute(a:path, '[\/]$', '', '') . '/'
  return getfsize(path.'HEAD') > 10 && (
        \ isdirectory(path.'objects') && isdirectory(path.'refs') ||
        \ getftype(path.'commondir') ==# 'file')
endfunction

let s:worktree_for_dir = {}
let s:dir_for_worktree = {}
function! FugitiveWorkTree(...) abort
  let dir = substitute(s:shellslash(a:0 ? a:1 : get(b:, 'git_dir', '')), '/$', '', '')
  if dir =~# '/\.git$'
    return len(dir) ==# 5 ? '/' : dir[0:-6]
  endif
  if !has_key(s:worktree_for_dir, dir)
    let s:worktree_for_dir[dir] = ''
    let config_file = dir . '/config'
    if filereadable(config_file)
      let config = readfile(config_file,'',10)
      call filter(config,'v:val =~# "^\\s*worktree *="')
      if len(config) == 1
        let worktree = matchstr(config[0], '= *\zs.*')
      endif
    elseif filereadable(dir . '/gitdir')
      let worktree = fnamemodify(readfile(dir . '/gitdir')[0], ':h')
      if worktree ==# '.'
        unlet! worktree
      endif
    endif
    if exists('worktree')
      let s:worktree_for_dir[dir] = worktree
      let s:dir_for_worktree[s:worktree_for_dir[dir]] = dir
    endif
  endif
  if s:worktree_for_dir[dir] =~# '^\.'
    return simplify(dir . '/' . s:worktree_for_dir[dir])
  else
    return s:worktree_for_dir[dir]
  endif
endfunction

function! FugitiveReal(...) abort
  let file = a:0 ? a:1 : @%
  if file =~? '^fugitive:' || a:0 > 1
    return call('fugitive#Real', [file] + a:000[1:-1])
  elseif file =~# '^/\|^\a\+:\|^$'
    return file
  else
    return fnamemodify(file, ':p' . (file =~# '[\/]$' ? '' : ':s?[\/]$??'))
  endif
endfunction

function! FugitivePath(...) abort
  if a:0 > 1
    return fugitive#Path(a:1, a:2, FugitiveGitDir(a:0 > 2 ? a:3 : -1))
  else
    return FugitiveReal(a:0 ? a:1 : @%)
  endif
endfunction

function! FugitiveGenerate(...) abort
  if a:0 && s:shellslash(a:0) =~# '^\%(\a\a\+:\)\=\%(a:\)\=/\|^[~$]'
    return a:1
  endif
  return fugitive#repo(FugitiveGitDir(a:0 > 1 ? a:2 : -1)).translate(a:0 ? a:1 : '', 1)
endfunction

function! FugitiveRoute(...) abort
  return call('FugitiveGenerate', a:000)
endfunction

function! FugitiveParse(...) abort
  let path = s:shellslash(a:0 ? a:1 : @%)
  let vals = matchlist(path, '\c^fugitive:\%(//\)\=\(.\{-\}\)\%(//\|::\)\(\x\{40\}\|[0-3]\)\(/.*\)\=$')
  if len(vals)
    return [(vals[2] =~# '^.$' ? ':' : '') . vals[2] . substitute(vals[3], '^/', ':', ''), vals[1]]
  endif
  let v:errmsg = 'fugitive: invalid Fugitive URL ' . path
  throw v:errmsg
endfunction

function! FugitiveConfig(key, ...) abort
  return fugitive#Config(a:key, FugitiveGitDir(a:0 ? a:1 : -1))
endfunction

function! FugitiveRemoteUrl(...) abort
  return fugitive#RemoteUrl(a:0 ? a:1 : '', FugitiveGitDir(a:0 > 1 ? a:2 : -1))
endfunction

function! FugitiveHead(...) abort
  let dir = FugitiveGitDir(a:0 > 1 ? a:2 : -1)
  if empty(dir)
    return ''
  endif
  return fugitive#repo(dir).head(a:0 ? a:1 : 0)
endfunction

function! FugitiveStatusline(...) abort
  if !exists('b:git_dir')
    return ''
  endif
  return fugitive#Statusline()
endfunction

function! FugitiveTreeForGitDir(path) abort
  return FugitiveWorkTree(a:path)
endfunction

function! FugitiveExtractGitDir(path) abort
  let path = s:shellslash(a:path)
  if path =~# '^fugitive:'
    return matchstr(path, '\C^fugitive:\%(//\)\=\zs.\{-\}\ze\%(//\|::\|$\)')
  elseif isdirectory(path)
    let path = fnamemodify(path, ':p:s?/$??')
  else
    let path = fnamemodify(path, ':p:h:s?/$??')
  endif
  let pre = substitute(matchstr(path, '^\a\a\+\ze:'), '^.', '\u&', '')
  if len(pre) && exists('*' . pre . 'Real')
    let path = s:shellslash({pre}Real(path))
  endif
  let root = resolve(path)
  if root !=# path
    silent! exe haslocaldir() ? 'lcd .' : 'cd .'
  endif
  let previous = ""
  while root !=# previous
    if root =~# '\v^//%([^/]+/?)?$'
      break
    endif
    if index(split($GIT_CEILING_DIRECTORIES, ':'), root) >= 0
      break
    endif
    if root ==# $GIT_WORK_TREE && FugitiveIsGitDir($GIT_DIR)
      return simplify(fnamemodify($GIT_DIR, ':p:s?[\/]$??'))
    endif
    if FugitiveIsGitDir($GIT_DIR)
      call FugitiveWorkTree(simplify(fnamemodify($GIT_DIR, ':p:s?[\/]$??')))
      if has_key(s:dir_for_worktree, root)
        return s:dir_for_worktree[root]
      endif
    endif
    let dir = substitute(root, '[\/]$', '', '') . '/.git'
    let type = getftype(dir)
    if type ==# 'dir' && FugitiveIsGitDir(dir)
      return dir
    elseif type ==# 'link' && FugitiveIsGitDir(dir)
      return resolve(dir)
    elseif type !=# '' && filereadable(dir)
      let line = get(readfile(dir, '', 1), 0, '')
      if line =~# '^gitdir: \.' && FugitiveIsGitDir(root.'/'.line[8:-1])
        return simplify(root.'/'.line[8:-1])
      elseif line =~# '^gitdir: ' && FugitiveIsGitDir(line[8:-1])
        return line[8:-1]
      endif
    elseif FugitiveIsGitDir(root)
      return root
    endif
    let previous = root
    let root = fnamemodify(root, ':h')
  endwhile
  return ''
endfunction

function! FugitiveDetect(path) abort
  if exists('b:git_dir') && b:git_dir =~# '^$\|/$\|^fugitive:'
    unlet b:git_dir
  endif
  if !exists('b:git_dir')
    let dir = FugitiveExtractGitDir(a:path)
    if dir !=# ''
      let b:git_dir = dir
    endif
  endif
  if exists('b:git_dir')
    return fugitive#Init()
  endif
endfunction

augroup fugitive
  autocmd!

  autocmd BufNewFile,BufReadPost * call FugitiveDetect(expand('<amatch>:p'))
  autocmd FileType           netrw call FugitiveDetect(fnamemodify(get(b:, 'netrw_curdir', expand('<amatch>')), ':p'))
  autocmd User NERDTreeInit,NERDTreeNewRoot
        \ if exists('b:NERDTree.root.path.str') |
        \   call FugitiveDetect(b:NERDTree.root.path.str()) |
        \ endif
  autocmd VimEnter * if empty(expand('<amatch>'))|call FugitiveDetect(getcwd())|endif
  autocmd CmdWinEnter * call FugitiveDetect(expand('#:p'))

  autocmd FileType git
        \ if exists('b:git_dir') |
        \   call fugitive#MapJumps() |
        \   call fugitive#MapCfile() |
        \ endif
  autocmd FileType gitcommit
        \ if exists('b:git_dir') |
        \   call fugitive#MapCfile('fugitive#StatusCfile()') |
        \ endif
  autocmd FileType gitrebase
        \ let &l:include = '^\%(pick\|squash\|edit\|reword\|fixup\|drop\|[pserfd]\)\>' |
        \ if exists('b:git_dir') |
        \   let &l:includeexpr = 'v:fname =~# ''^\x\{4,40\}$'' ? FugitiveGenerate(v:fname) : ' .
        \   (len(&l:includeexpr) ? &l:includeexpr : 'v:fname') |
        \ endif |
        \ let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe') . '|setl inex= inc='

  autocmd BufReadCmd index{,.lock}
        \ if FugitiveIsGitDir(expand('<amatch>:p:h')) |
        \   let b:git_dir = s:shellslash(expand('<amatch>:p:h')) |
        \   exe fugitive#BufReadStatus() |
        \ elseif filereadable(expand('<amatch>')) |
        \   read <amatch> |
        \   1delete_ |
        \ endif
  autocmd BufReadCmd    fugitive://*//*             exe fugitive#BufReadCmd()
  autocmd BufWriteCmd   fugitive://*//[0-3]/*       exe fugitive#BufWriteCmd()
  autocmd FileReadCmd   fugitive://*//*             exe fugitive#FileReadCmd()
  autocmd FileWriteCmd  fugitive://*//[0-3]/*       exe fugitive#FileWriteCmd()
  if exists('##SourceCmd')
    autocmd SourceCmd     fugitive://*//*    nested exe fugitive#SourceCmd()
  endif

  autocmd User Flags call Hoist('buffer', function('FugitiveStatusline'))
augroup END
