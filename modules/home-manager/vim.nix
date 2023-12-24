{ config, pkgs, lib, ... }: 

with lib;

let
  cfg = config.custom-hm.neovim;
in
{
  options.custom-hm.neovim = {
    enable = mkEnableOption "neovim configurations";
  };
  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      vimAlias = true;
      vimdiffAlias = true;
      plugins = with pkgs.vimPlugins; [
        catppuccin-nvim
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
      set list
      set listchars=tab:→·
      set tabstop=4
      set shiftwidth=4
      set expandtab

      set mouse+=a

      colorscheme catppuccin-macchiato
      '';
    };
  };
}
