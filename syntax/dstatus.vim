syntax match conNames "[a-zA-Z0-9/,-_]*$"
syntax match conIds "^[A-Fa-f0-9]*"
syntax match conIds "^CONTAINER ID"

highlight conNames ctermfg=Red guifg=Red
highlight conIds ctermfg=Green guifg=Green
