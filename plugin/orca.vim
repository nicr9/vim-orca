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

function! s:read_to_window(cmd) abort
    " Create new buffer
    bot new

    " Write info to file
    if g:orca_debug
        " if in debug mode, just read contents of current folder
        read ! ls -alF ~/
    else
        exec "read !" . join(a:cmd, ' ')
    endif

    " Delete empty line (0)
    0,1del

    " Configure the buffer
    setlocal buftype=nowrite nomodified readonly nomodifiable

    " Return buffer number
    return bufnr("%")
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

" Section: Dstatus

function! Dexec() abort
    let con_id = matchstr(getline("."), '^[a-fA-F0-9]*')
    if con_id != 'C'
        let cmd = ["exec", "-it", con_id, "/bin/bash"]
        call s:run_cmd(s:docker_cmd(cmd))
    endif
endfunction

function! s:setup_dstatus()
    if s:dstatus_bufnr && bufnr("%") == s:dstatus_bufnr
        resize 10
        set filetype=dstatus
        nmap <buffer> s :call Dexec()<CR>
        echo
    endif
endfunction

function! s:Status() abort
    let s:dstatus_bufnr = s:read_to_window(s:docker_cmd(["ps"]))
    exec s:setup_dstatus()
endfunction

command! Dstatus call s:Status()

" Section: Fup

function! s:Fup() abort
    exec s:run_cmd(s:fig_cmd(["up", "-d"]))
endfunction

command! Fup call s:Fup()
