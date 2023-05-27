{ pkgs, ... }: {
  programs.neovim = {
    enable = true;
    vimAlias = true;
    vimdiffAlias = true;
    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
      dracula-nvim
    ];
    extraConfig = ''
    set nocompatible
  
    syntax on
    set number
    set relativenumber
    set shortmess+=I
    set laststatus=2

    set ignorecase
    set smartcase

    set mouse+=a

    colorscheme dracula
    '';
  };
}