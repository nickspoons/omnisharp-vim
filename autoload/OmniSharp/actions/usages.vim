let s:save_cpo = &cpoptions
set cpoptions&vim

" Find usages of the symbol under the cursor.
" Optional argument:
" Callback: When a callback is passed in, the usage locations will be sent to
"           the callback *instead of* to the configured selector
"           (g:OmniSharp_selector_findusages) or quickfix list.
function! OmniSharp#actions#usages#Find(...) abort
  if a:0 && a:1 isnot 0
    let Callback = a:1
  else
    let target = expand('<cword>')
    let Callback = function('s:CBFindUsages', [target])
  endif

  if g:OmniSharp_server_stdio
    call s:StdioFind(Callback)
  else
    let locs = OmniSharp#py#Eval('findUsages()')
    if OmniSharp#py#CheckForError() | return | endif
    return Callback(locs)
  endif
endfunction

function! s:StdioFind(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioFindRH', [a:Callback]),
  \ 'Parameters': {
  \   'ExcludeDefinition': 1
  \ }
  \}
  call OmniSharp#stdio#Request('/findusages', opts)
endfunction

function! s:StdioFindRH(Callback, response) abort
  if !a:response.Success | return | endif
  let usages = a:response.Body.QuickFixes
  if type(usages) == type([])
    call a:Callback(OmniSharp#locations#Parse(usages))
  else
    call a:Callback([])
  endif
endfunction

function! s:CBFindUsages(target, locations) abort
  let numUsages = len(a:locations)
  if numUsages == 0
    echo 'No usages found'
    return 0
  endif

  let locations = OmniSharp#locations#Modify(a:locations)
  if get(g:, 'OmniSharp_selector_findusages', '') ==? 'fzf'
    call fzf#OmniSharp#FindUsages(locations, a:target)
  elseif get(g:, 'OmniSharp_selector_findusages', '') ==? 'clap'
    call clap#OmniSharp#FindUsages(locations, a:target)
  else
    call OmniSharp#locations#SetQuickfix(locations, 'Usages: ' . a:target)
  endif
  return numUsages
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
