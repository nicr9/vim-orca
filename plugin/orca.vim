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

if !exists("g:orca_default_repo")
    let g:orca_default_repo = ""
endif

" Section: useful constants

let g:orca_version = "v0.1"
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
    let g:orca_last_preview = a:cmd
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
    execute "pclose!"
    execute "pedit! " . tmp
    execute "normal \<C-W>p"
    execute "redraw!"
endfunction

function! s:preview_refresh()
    execute s:preview(g:orca_last_preview)
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
    let m = matchstr(a:con_id, s:con_id_re)
    return strlen(m) == 12 ? 1 : 0
endfunction

" Section: Docker

function! s:Docker(...) abort
    exec s:run_cmd(s:docker_cmd(a:000))
endfunction

command! -nargs=+ Docker call s:Docker(<f-args>)

" Section: Dbuild

function! s:DockerBuild(image_tag) abort
    let cmd = ["build", "--rm=false", "-t", a:image_tag, '.']
    exec s:run_cmd(s:docker_cmd(cmd))
endfunction

command! -nargs=1 Dbuild call s:DockerBuild(<f-args>)

" Section: Dshell

function! s:DockerShell(image_tag) abort
    let cmd = ["run", "-it", a:image_tag, '/bin/bash']
    exec s:run_cmd(s:docker_cmd(cmd))
endfunction

command! -nargs=1 Dshell call s:DockerShell(<f-args>)

" Section: Dexec

function! s:DockerExec(con_id) abort
    if s:verify_con_id(a:con_id)
        let cmd = ["exec", "-it", a:con_id, "/bin/bash"]
        call s:run_cmd(s:docker_cmd(cmd))
    endif
endfunction

command! -nargs=1 Dexec call s:DockerExec(<f-args>)

" Section: Dpull

function! s:DockerPull(image) abort
    let image = a:image
    if strlen(g:orca_default_repo) != 0
        let image = g:orca_default_repo . image
    endif
    call s:run_cmd(s:docker_cmd(["pull", image]))
endfunction

command! -nargs=1 Dpull call s:DockerPull(<f-args>)

" Section: Dcreate

function! s:DockerCreate(details)
    let details = filter(a:details, "v:val != '<none>'")
    let name = join(a:details[:-2], '_')
    let image = a:details[-1]

    if strlen(name) > 0
        let cmd = ['create', '--name ' . name, image]
    else
        let cmd = ['create', image]
    endif

    call s:run_cmd(s:docker_cmd(cmd))
endfunction

command! -nargs=1 Dcreate call s:DockerCreate([<f-args>])

" Section: Dwrite

function! s:DockerWrite(img_name) abort
    let cmd = s:docker_cmd(["ps", "-ql"])
    let con_id = system(join(cmd, ' '))[:-2]
    call s:run_cmd(s:docker_cmd(["commit", con_id, a:img_name]))
endfunction

command! -nargs=1 Dwrite call s:DockerWrite(<f-args>)

" Section: Dpatch

function! s:DockerPatch(con_id) abort
    let cmd = s:docker_cmd(["exec", a:con_id, "git", "diff", "|", "patch", "-p1"])
    call s:run_cmd(cmd)
endfunction

command! -nargs=1 Dpatch call s:DockerPatch(<f-args>)

" Section: Dstatus

function! s:help_dstatus()
    execute ":pclose!"
    execute ":pedit! " . g:orca_path . "/res/dstatus.help"
    execute "normal \<C-W>p"
    setlocal filetype=md
    nmap <buffer> <silent> ? :call <SID>preview_refresh()<CR>:call <SID>setup_dstatus()<CR>
    nmap <buffer> <silent> q :pclose!<CR>
endfunction

function! s:setup_dstatus()
    setlocal buftype=nowrite nomodified readonly nomodifiable
    setlocal bufhidden=delete
    setlocal nowrap
    set filetype=dstatus
    nmap <buffer> l :call <SID>Docker("logs -f " . <SID>line_columns([0])[0])<CR>
    nmap <buffer> p :call <SID>DockerPatch(<SID>line_columns([0])[0])<CR>
    nmap <buffer> <silent> r :call <SID>preview_refresh()<CR>:call <SID>setup_dstatus()<CR>
    nmap <buffer> s :call <SID>DockerExec(<SID>line_columns([0])[0])<CR>
    nmap <buffer> <silent> ? :call <SID>help_dstatus()<CR>
    nmap <buffer> <silent> q :pclose!<CR>
endfunction

function! s:DockerStatus() abort
    exec s:preview(s:docker_cmd(["ps"]))
    exec s:setup_dstatus()
endfunction

command! Dstatus call s:DockerStatus()

" Section: Dimages

function! s:help_dimages()
    execute ":pclose!"
    execute ":pedit! " . g:orca_path . "/res/dimages.help"
    execute "normal \<C-W>p"
    setlocal filetype=md
    nmap <buffer> <silent> ? :call <SID>preview_refresh()<CR>:call <SID>setup_dimages()<CR>
    nmap <buffer> <silent> q :pclose!<CR>
endfunction

function! s:setup_dimages()
    setlocal buftype=nowrite nomodified readonly nomodifiable
    setlocal bufhidden=delete
    setlocal nowrap
    set filetype=dstatus
    nmap <buffer> c :call <SID>DockerCreate(<SID>line_columns([0,1,2]))<CR>
    nmap <buffer> <silent> r :call <SID>preview_refresh()<CR>:call <SID>setup_dimages()<CR>
    nmap <buffer> s :call <SID>DockerShell(<SID>line_columns([2])[0])<CR>
    nmap <buffer> <silent> ? :call <SID>help_dimages()<CR>
    nmap <buffer> <silent> q :pclose!<CR>
endfunction

function! s:DockerImages() abort
    exec s:preview(s:docker_cmd(["images"]))
    exec s:setup_dimages()
endfunction

command! Dimages call s:DockerImages()

" Section: Fig

function! s:Fig(...) abort
    exec s:run_cmd(s:fig_cmd(a:000))
endfunction

command! -nargs=+ Fig call s:Fig(<f-args>)

" Section: Fbuild

function! s:FigBuild() abort
    exec s:run_cmd(s:fig_cmd(["build"]))
endfunction

command! Fbuild call s:FigBuild()

" Section: Fup

function! s:FigUp() abort
    exec s:run_cmd(s:fig_cmd(["up", "-d"]))
endfunction

command! Fup call s:FigUp()
