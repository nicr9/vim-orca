" Section: config

if !exists("g:orca_debug")
    let g:orca_debug = 1
endif

if !exists("g:orca_verbose")
    let g:orca_verbose = 0
endif

if !exists("g:orca_sudo")
    let g:orca_sudo = 1
endif

" Section: useful constants

let g:orca_path = expand('<sfile>:p:h:h')

let s:multi_ws_re = '\s\s\+'
let s:con_id_re = '^[a-fA-F0-9]*'

" Section: utils

function! s:docker_cmd(args) abort
    if g:orca_sudo
        let cmd = ["sudo", "docker"]
    else
        let cmd = ["docker"]
    endif

    let cmd += a:args
    return cmd
endfunction

function! s:fig_cmd(args) abort
    if g:orca_sudo
        let cmd = ["sudo", "fig"]
    else
        let cmd = ["fig"]
    endif

    if g:orca_verbose
        call add(cmd, '--verbose')
    endif

    let cmd += a:args
    return cmd
endfunction

function! s:run_cmd(cmd_args) abort
    let full_cmd = join(a:cmd_args, ' ')

    if g:orca_debug
        echom full_cmd
    else
        exec '!' . full_cmd
    endif
endfunction

function! s:debug_file(cmd) abort
    let filename = g:orca_sudo ? a:cmd[2:] : a:cmd[1:]
    let full_name = g:orca_path . "/debug/" .join(filename, '.')
    return full_name
endfunction

function! s:preview(cmd)
    let tmp = tempname()

    " Write info to file
    if g:orca_debug
        " if in debug mode, just copy a debug file
        let src = s:debug_file(a:cmd)
        execute ":silent ! cp " . src . " " . tmp
    else
        execute ":silent ! " . join(a:cmd, ' ') . " > " . tmp . " 2>&1"
    endif

    " Open preview
    execute ":pedit! " . tmp
    execute "normal \<C-W>p"
endfunction

function! s:line_columns(columns)
    let matches = split(getline("."), s:multi_ws_re)
    let results = []

    for indx in a:columns
        call add(results, matches[indx])
    endfor

    return results
endfunction

function! s:verify_con_id(con_id)
    return matchstr(a:con_id, s:con_id_re) ? 1 : 0
endfunction

" Section: Docker

function! s:Docker(...) abort
    exec s:run_cmd(s:docker_cmd(a:000))
endfunction

command! -nargs=+ Docker call s:Docker(<f-args>)

" Section: Dbuild

function! s:Build(image_tag) abort
    let cmd = ["build", "-t", a:image_tag, '.']
    exec s:run_cmd(s:docker_cmd(cmd))
endfunction

command! -nargs=1 Dbuild call s:Build(<f-args>)

" Section: Dshell

function! s:Shell(image_tag) abort
    let cmd = ["run", "-it", a:image_tag, '/bin/bash']
    exec s:run_cmd(s:docker_cmd(cmd))
endfunction

command! -nargs=1 Dshell call s:Shell(<f-args>)

" Section: Dexec

function! s:Dexec(con_id) abort
    if s:verify_con_id(a:con_id)
        let cmd = ["exec", "-it", a:con_id, "/bin/bash"]
        call s:run_cmd(s:docker_cmd(cmd))
    endif
endfunction

command! -nargs=1 Dexec call s:Dexec(<f-args>)

" Section: Dstatus

function! s:setup_dstatus()
    setlocal buftype=nowrite nomodified readonly nomodifiable
    setlocal bufhidden=delete
    set filetype=dstatus
    nmap <buffer> s :call <SID>Dexec(<SID>line_columns([0])[0])<CR>
endfunction

function! s:Status() abort
    exec s:preview(s:docker_cmd(["ps"]))
    exec s:setup_dstatus()
endfunction

command! Dstatus call s:Status()

" Section: Fup

function! s:Fup() abort
    exec s:run_cmd(s:fig_cmd(["up", "-d"]))
endfunction

command! Fup call s:Fup()
