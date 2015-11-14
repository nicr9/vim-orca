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

if !exists("g:orca_private_registery")
    let g:orca_private_registery = ""
endif

if !exists("g:orca_preview_dir")
    let g:orca_preview_dir = "/tmp/orca/"
endif

" Section: useful constants

let g:orca_version = "v0.3"
let g:orca_path = expand('<sfile>:p:h:h')

let s:multi_ws_re = '\s\s\+'

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

function! s:dcompose_cmd(args) abort
    if g:orca_sudo
        let cmd = ["sudo", "docker-compose"]
    else
        let cmd = ["docker-compose"]
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

function! s:preview(cmd, file_name)
    let g:orca_last_preview_cmd = a:cmd
    let g:orca_last_preview_file = a:file_name
    let tmp = g:orca_preview_dir . a:file_name

    " Setup /tmp
    if !isdirectory(g:orca_preview_dir)
        exec mkdir(g:orca_preview_dir, 'p')
    endif

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
    execute s:preview(g:orca_last_preview_cmd, g:orca_last_preview_file)
    if exists('g:orca_preview_cursor')
        call setpos(".", g:orca_preview_cursor)
        unlet g:orca_preview_cursor
    endif
endfunction

function! s:line_range(...)
    if a:0 == 0
        let from = line("'<")
        let to = line("'>")
    elseif a:0 == 2
        let from = a:1
        let to = a:2
    else
        return []
    endif
    let lines = range(from, to)
    return map(lines, "getline(v:val)")
endfunction

function! s:multiline_col(lines, column)
    return map(a:lines, "s:get_col(v:val, " . a:column . ")")
endfunction

function! s:line_col(line_no, column)
    if type(a:line_no) == 1
        let line = getline(a:line_no)
    else
        let line = a:line_no
    endif
    return s:get_col(line, a:column)
endfunction

function! s:get_col(text, column)
    let matches = split(a:text, s:multi_ws_re)
    return matches[a:column]
endfunction

function! s:container_running(con_id)
    let raw = system(join(s:docker_cmd(['ps', '-q']), ' '))
    let all_running = split(raw)
    return (index(all_running, a:con_id) > 0)
endfunction

function! s:latest_container()
    let cmd = s:docker_cmd(["ps", "-ql"])
    if g:orca_debug
        let con_id = "1234567890ab"
    else
        let con_id = system(join(cmd, ' '))[:-2]
    endif
    return con_id
endfunction

" Section: Docker

function! s:Docker(...) abort
    exec s:run_cmd(s:docker_cmd(a:000))
endfunction

command! -nargs=+ Docker call s:Docker(<f-args>)

" Section: Dbuild

function! s:DockerBuild(image_tag, ...) abort
    " parse optional params
    let context = '.'
    if a:0 > 0
        let context = a:1
    endif
    echom "context: " . context

    let cmd = ["build", "--rm=false", "-t", a:image_tag, context]
    exec s:run_cmd(s:docker_cmd(cmd))
endfunction

command! -nargs=* Dbuild call s:DockerBuild(<f-args>)

" Section: Dexec

function! s:DockerExec(...) abort
    let cmd = extend(["exec"], a:000)
    call s:run_cmd(s:docker_cmd(cmd))
endfunction

command! -nargs=1 Dexec call s:DockerExec(<f-args>)

" Section: Dpull

function! s:DockerPull(image) abort
    let image = a:image
    if strlen(g:orca_private_registery) != 0
        let image = g:orca_private_registery . image
    endif
    call s:run_cmd(s:docker_cmd(["pull", image]))
endfunction

command! -nargs=1 Dpull call s:DockerPull(<f-args>)

" Section: Dcreate

function! s:DockerCreate(image, ...) abort
    if a:0 > 0
        let cmd = ['create', '--name ' . name, image]
    else
        let cmd = ['create', image]
    endif

    exec s:run_cmd(s:docker_cmd(cmd))

    if a:0 != 1
        let raw = system(join(s:docker_cmd(['ps', '-l']), ' '))
        let name = split(raw)[-1]
    endif

    echom "Created container: " . name
endfunction

command! -nargs=* Dcreate call s:DockerCreate(<f-args>)

" Section: Dcommit

function! s:DockerCommit(...) abort
    " Sort out params
    if len(a:000) == 2
        let con_id = a:1
        let img_name = a:2
    elseif len(a:000) == 1
        let con_id = s:latest_container()
        let img_name = a:1
    else
        return
    endif

    call s:run_cmd(s:docker_cmd(["commit", con_id, img_name]))
endfunction

command! -nargs=* Dcommit call s:DockerCommit(<f-args>)

" Section: Dkill

function! s:DockerKill(...) abort
    let containers = a:0 == 0 ? [s:latest_container()] : a:1
    let container_list = type(a:1) == 1 ? [containers] : containers

    for con_id in container_list
        if s:container_running(con_id)
            call s:run_cmd(s:docker_cmd(["stop", con_id]))
        endif
        call s:run_cmd(s:docker_cmd(["kill", con_id]))
    endfor
endfunction

command! -nargs=? Dkill call s:DockerKill(<f-args>)

" Section: Drmi

function! s:DockerRmi(img_name) abort
    let img_list = type(a:img_name) == 3 ? a:img_name : [a:img_name]

    for img_id in img_list
        let cmd = s:docker_cmd(["rmi", '-f', img_id])
        call s:run_cmd(cmd)
    endfor
endfunction

command! -nargs=1 Drmi call s:DockerRmi(<f-args>)

" Section: Drm

function! s:DockerRm(...) abort
    let containers = a:0 == 0 ? [s:latest_container()] : a:1
    let container_list = type(a:1) == 1 ? [containers] : containers

    for con_id in container_list
        let cmd = s:docker_cmd(["rm", '-f', con_id])
        call s:run_cmd(cmd)
    endfor
endfunction

command! -nargs=? Drm call s:DockerRm(<f-args>)

" Section: Drun

function! s:DockerRun(...) abort
    let cmd = extend(['run'], a:000)
    call s:run_cmd(s:docker_cmd(cmd))
endfunction

command! -nargs=* Drun call s:DockerRun(<f-args>)

" Section: Dhistory

function! s:DockerHistory(image_tag) abort
    let cmd = ['history', '--no-trunc=true', a:image_tag]
    call s:run_cmd(s:docker_cmd(cmd))
endfunction

command! -nargs=1 Dhistory call s:DockerHistory(<f-args>)

" Section: Dinspect

function! s:help_dinspect()
    let g:orca_preview_cursor = getpos(".")
    execute ":pclose!"
    execute ":pedit! " . g:orca_path . "/res/dinspect.help"
    execute "normal \<C-W>p"
    setlocal buftype=nowrite nomodified readonly nomodifiable
    setlocal bufhidden=delete
    setlocal filetype=md
    nmap <buffer> <silent> ? :call <SID>preview_refresh()<CR>:call <SID>setup_dinspect()<CR>
    nmap <buffer> <silent> q :pclose!<CR>
endfunction

function! s:setup_dinspect()
    setlocal noswapfile
    setlocal buftype=nowrite nomodified readonly nomodifiable
    setlocal bufhidden=delete
    setlocal nowrap
    set filetype=json
    nmap <buffer> <silent> r :call <SID>preview_refresh()<CR>:call <SID>setup_dinspect()<CR>
    nmap <buffer> <silent> ? :call <SID>help_dinspect()<CR>
    nmap <buffer> <silent> q :pclose!<CR>
endfunction

function! s:DockerInspect(...) abort
    let object = len(a:000) == 1 ? a:1 : s:latest_container()
    let file_name = 'inspect_' . object
    exec s:preview(s:docker_cmd(["inspect", object]), file_name)
    exec s:setup_dinspect()
endfunction

command! -nargs=? Dinspect call s:DockerInspect(<f-args>)

" Section: Dlogs

function! s:help_dlogs()
    let g:orca_preview_cursor = getpos(".")
    execute ":pclose!"
    execute ":pedit! " . g:orca_path . "/res/dlogs.help"
    execute "normal \<C-W>p"
    setlocal buftype=nowrite nomodified readonly nomodifiable
    setlocal bufhidden=delete
    setlocal filetype=md
    nmap <buffer> <silent> ? :call <SID>preview_refresh()<CR>:call <SID>setup_dlogs()<CR>
    nmap <buffer> <silent> q :pclose!<CR>
endfunction

function! s:setup_dlogs()
    setlocal noswapfile
    setlocal buftype=nowrite nomodified readonly nomodifiable
    setlocal bufhidden=delete
    setlocal nowrap
    set filetype=dstatus
    nmap <buffer> <silent> r :call <SID>preview_refresh()<CR>:call <SID>setup_dlogs()<CR>
    nmap <buffer> <silent> ? :call <SID>help_dlogs()<CR>
    nmap <buffer> <silent> q :pclose!<CR>
endfunction

function! s:DockerLogs(...) abort
    let con_id = len(a:000) == 1 ? a:1 : s:latest_container()
    let file_name = 'logs_' . con_id
    exec s:preview(s:docker_cmd(["logs", con_id]), file_name)
    exec s:setup_dlogs()
endfunction

command! -nargs=? Dlogs call s:DockerLogs(<f-args>)

" Section: Dimages

function! s:help_dimages()
    let g:orca_preview_cursor = getpos(".")
    execute ":pclose!"
    execute ":pedit! " . g:orca_path . "/res/dimages.help"
    execute "normal \<C-W>p"
    setlocal buftype=nowrite nomodified readonly nomodifiable
    setlocal bufhidden=delete
    setlocal filetype=md
    nmap <buffer> <silent> ? :call <SID>preview_refresh()<CR>:call <SID>setup_dimages()<CR>
    nmap <buffer> <silent> q :pclose!<CR>
endfunction

function! s:setup_dimages()
    setlocal noswapfile
    setlocal buftype=nowrite nomodified readonly nomodifiable
    setlocal bufhidden=delete
    setlocal nowrap
    set filetype=dstatus
    nmap <buffer> d :call <SID>DockerRun('-d', <SID>line_col('.', 2))<CR>
    nmap <buffer> h :call <SID>DockerHistory(<SID>line_col('.', 2))<CR>
    nmap <buffer> i :call <SID>DockerInspect(<SID>line_col('.', 2))<CR>
    nmap <buffer> <silent> r :call <SID>preview_refresh()<CR>:call <SID>setup_dimages()<CR>
    nmap <buffer> s :call <SID>DockerRun('-it', '--entrypoint=/bin/bash', <SID>line_col('.', 2))<CR>
    nmap <buffer> t :call <SID>DockerRun('-it', <SID>line_col('.', 2))<CR>
    nmap <silent> <buffer> <backspace> :call <SID>DockerRmi(<SID>line_col('.', 2))<CR>r
    vmap <silent> <buffer> <backspace> <ESC>:call <SID>DockerRmi(<SID>multiline_col(<SID>line_range(), 2))<CR>r
    nmap <buffer> <silent> ? :call <SID>help_dimages()<CR>
    nmap <buffer> <silent> q :pclose!<CR>
endfunction

function! s:DockerImages() abort
    let file_name = 'logs'
    exec s:preview(s:docker_cmd(["images"]), file_name)
    exec s:setup_dimages()
endfunction

command! Dimages call s:DockerImages()

" Section: Dpatch

function! s:DockerPatch(...) abort
    let con_id = len(a:000) == 1 ? a:1 : s:latest_container()

    let cmd = s:docker_cmd(["exec", con_id, "git", "diff", "|", "patch", "-p1"])
    call s:run_cmd(cmd)
endfunction

command! -nargs=? Dpatch call s:DockerPatch(<f-args>)

" Section: Dstatus

function! s:help_dstatus()
    let g:orca_preview_cursor = getpos(".")
    execute ":pclose!"
    execute ":pedit! " . g:orca_path . "/res/dstatus.help"
    execute "normal \<C-W>p"
    setlocal buftype=nowrite nomodified readonly nomodifiable
    setlocal bufhidden=delete
    setlocal filetype=md
    nmap <buffer> <silent> ? :call <SID>preview_refresh()<CR>:call <SID>setup_dstatus()<CR>
    nmap <buffer> <silent> q :pclose!<CR>
endfunction

function! s:setup_dstatus()
    setlocal noswapfile
    setlocal buftype=nowrite nomodified readonly nomodifiable
    setlocal bufhidden=delete
    setlocal nowrap
    set filetype=dstatus
    nmap <buffer> c :call <SID>DockerCommit(<SID>line_col('.', 0), <SID>line_col('.', -1))<CR>
    nmap <buffer> i :call <SID>DockerInspect(<SID>line_col('.', 0))<CR>
    nmap <buffer> K :call <SID>DockerKill(<SID>line_col('.', 0))<CR>r
    vmap <buffer> K <ESC>:call <SID>DockerKill(<SID>multiline_col(<SID>line_range(), 0))<CR>r
    nmap <buffer> l :call <SID>Docker("logs -f " . <SID>line_col('.', 0))<CR>
    nmap <buffer> L :call <SID>DockerLogs(<SID>line_col('.', 0))<CR>
    nmap <buffer> p :call <SID>DockerPatch(<SID>line_col('.', 0))<CR>
    nmap <buffer> <silent> r :call <SID>preview_refresh()<CR>:call <SID>setup_dstatus()<CR>
    nmap <buffer> s :call <SID>DockerExec('-it', <SID>line_col('.', 0), '/bin/bash')<CR>
    nmap <silent> <buffer> <backspace> :call <SID>DockerRm(<SID>line_col('.', 0))<CR>r
    vmap <silent> <buffer> <backspace> <ESC>:call <SID>DockerRm(<SID>multiline_col(<SID>line_range(), 0))<CR>r
    nmap <buffer> <silent> ? :call <SID>help_dstatus()<CR>
    nmap <buffer> <silent> q :pclose!<CR>
endfunction

function! s:DockerStatus(...) abort
    let cmd = ["ps"]

    " Optionally filter results
    if len(a:000) == 1
        if a:1 == 'all'
            let cmd = ["ps", '-a']
        elseif index(["restarting", "running", "paused", "exited"], a:1) >= 0
            let cmd = ["ps", "-a", "-f", "status=" . a:1]
        elseif a:1 =~ "="
            let cmd = ["ps", "-a", "-f", a:1]
        endif
    endif

    let file_name = 'status'
    exec s:preview(s:docker_cmd(cmd), file_name)
    exec s:setup_dstatus()
endfunction

command! -nargs=? Dstatus call s:DockerStatus(<f-args>)

" Section: DCompose

function! s:DCompose(...) abort
    exec s:run_cmd(s:dcompose_cmd(a:000))
endfunction

command! -nargs=+ DCompose call s:DCompose(<f-args>)

" Section: DCbuild

function! s:DComposeBuild(...) abort
    let cmd = a:0 == 1 ? ["build", a:1] : ["build"]
    exec s:run_cmd(s:dcompose_cmd(cmd))
endfunction

command! -nargs=? DCbuild call s:DComposeBuild(<f-args>)

" Section: DCkill

function! s:DComposeKill(...) abort
    let cmd = a:0 == 1 ? ["kill", a:1] : ["kill"]
    exec s:run_cmd(s:dcompose_cmd(cmd))
endfunction

command! -nargs=? DCkill call s:DComposeKill(<f-args>)

" Section: DCrestart

function! s:DComposeRestart(...) abort
    let cmd = a:0 == 1 ? ["restart", a:1] : ["restart"]
    exec s:run_cmd(s:dcompose_cmd(cmd))
endfunction

command! -nargs=? DCrestart call s:DComposeRestart(<f-args>)

" Section: DCstart

function! s:DComposeStart(...) abort
    let cmd = a:0 == 1 ? ["start", a:1] : ["start"]
    exec s:run_cmd(s:dcompose_cmd(cmd))
endfunction

command! -nargs=? DCstart call s:DComposeStart(<f-args>)

" Section: DClogs

function! s:DComposeLogs() abort
    let cmd = a:0 == 1 ? ["logs", a:1] : ["logs"]
    exec s:run_cmd(s:dcompose_cmd(cmd))
endfunction

command! -nargs=? DClogs call s:DComposeLogs(<f-args>)

" Section: DCpull

function! s:DComposePull() abort
    let cmd = a:0 == 1 ? ["pull", a:1] : ["pull"]
    exec s:run_cmd(s:dcompose_cmd(cmd))
endfunction

command! -nargs=? DCpull call s:DComposePull(<f-args>)

" Section: DCrm

function! s:DComposeRm() abort
    let cmd = a:0 == 1 ? ["rm", a:1] : ["rm"]
    exec s:run_cmd(s:dcompose_cmd(cmd))
endfunction

command! -nargs=? DCrm call s:DComposeRm(<f-args>)

" Section: DCup

function! s:DComposeUp() abort
    let cmd = a:0 == 1 ? ["up", "-d", a:1] : ["up", "-d"]
    exec s:run_cmd(s:dcompose_cmd(cmd))
endfunction

command! -nargs=? DCup call s:DComposeUp(<f-args>)
