# vim-ocra

## Installation

Vim has a number of plugins that ease the pains of plugin management.

### [pathogen.vim](https://github.com/tpope/vim-pathogen).

If you've already set up pathogen, then this is all you need to do:

```
cd ~/.vim/bundle
git clone git://github.com/tpope/vim-fugitive.git
```

### [Vundle.vim](https://github.com/VundleVim/Vundle.vim.git)

Vundle is my prefered plugin management system for vim. When you've set up and
ready to go just put this line between `vundle#begin()` and `vundle#end()` in
your `~/.vimrc`:

```
Plugin 'nicr9/vim-orca'
```

Then run this to install:

```
vim +PluginInstall +qall
```

You can pull down updates with:

```
vim +PluginUpdate +qall
```

## Docs

I will add a tutorial in the future, but until then I'll just leave you with
[the vim docs](https://github.com/nicr9/vim-orca/blob/master/doc/orca.txt).
