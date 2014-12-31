" Section: config

if !exists("g:orca_debug")
    let g:orca_debug = 1
endif

if !exists("g:orca_sudo")
    let g:orca_sudo = 1
endif

" Section: utils

function! s:docker_run(args) abort
    if g:orca_sudo
        let cmd = ["sudo", "docker"]
    else
        let cmd = ["docker"]
    endif

    let cmd += a:args
    let full_cmd = join(cmd, ' ')

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
        read ! a:cmd
    endif

    " Delete empty line (0)
    0,1del

    " Configure the buffer
    setlocal buftype=nowrite nomodified readonly nomodifiable
endfunction

" Section: Docker

function! s:Docker(...) abort
    exec s:docker_run(a:000)
endfunction

command! -nargs=+ Docker call s:Docker(<f-args>)

" Section: Dbuild

function! s:Build(image_tag) abort
    let cmd = ["build", "-t", a:image_tag, '.']
    exec s:docker_run(cmd)
endfunction

command! -nargs=1 Dbuild call s:Build(<f-args>)

" Section: Dshell

function! s:Shell(image_tag) abort
    let cmd = ["run", "-it", a:image_tag, '/bin/bash']
    exec s:docker_run(cmd)
endfunction

command! -nargs=1 Dshell call s:Shell(<f-args>)

" Section: Dstatus

function! s:Status() abort
    let cmd = ["ps"]
    exec s:read_to_window(cmd)
endfunction

command! Dstatus call s:Status()
