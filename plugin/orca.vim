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
