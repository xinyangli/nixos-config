{ inputs, config, lib, pkgs, ... }:
with lib;

let
  cfg = config.custom-hm.vscode;
in
{
  options.custom-hm.vscode = { 
    enable = mkEnableOption "Vscode config";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      pkgs.wl-clipboard-x11
    ];
    programs.vscode = {
      enable = true;
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      mutableExtensionsDir = false;
      extensions = (with inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace; [
        mkhl.direnv

        bbenoist.nix
        ms-azuretools.vscode-docker
        ms-vscode-remote.remote-ssh
        vscodevim.vim
        github.vscode-pull-request-github
        gruntfuggly.todo-tree # todo highlight

        # Language support
        # Python
        ms-python.python
        # Markdown
        davidanson.vscode-markdownlint
        # C/C++
        ms-vscode.cmake-tools
        twxs.cmake
        llvm-vs-code-extensions.vscode-clangd
        # Nix
        jnoortheen.nix-ide
        # Latex
        james-yu.latex-workshop
        # Vue
        vue.volar
        # Scale / chisel
        scala-lang.scala
        scalameta.metals

        sterben.fpga-support

        ms-vscode-remote.remote-ssh-edit
        mushan.vscode-paste-image
      ]) ++ (with pkgs.vscode-extensions; [
        waderyan.gitblame
        catppuccin.catppuccin-vsc
        # Rust
        rust-lang.rust-analyzer
        github.copilot
      ]);
      userSettings = {
        "workbench.colorTheme" = "Catppuccin Macchiato";
        "terminal.integrated.sendKeybindingsToShell" = true;
        "extensions.ignoreRecommendations" = true;
        "files.autoSave" = "afterDelay";
        "editor.inlineSuggest.enabled" = true;
        "editor.rulers" = [
          80
        ];
        "editor.mouseWheelZoom" = true;
        "git.autofetch" = true;
        "window.zoomLevel" = -1;

        "nix.enableLanguageServer" = true;

        "latex-workshop.latex.autoBuild.run" = "never";
        "latex-workshop.latex.tools" = [
          {
            "name" = "xelatex";
            "command" = "xelatex";
            "args" = [
              "-synctex=1"
              "-interaction=nonstopmode"
              "-file-line-error"
              "-pdf"
              "%DOCFILE%"
            ];
          }
          {
            "name" = "pdflatex";
            "command" = "pdflatex";
            "args" = [
              "-synctex=1"
              "-interaction=nonstopmode"
              "-file-line-error"
              "%DOCFILE%"
            ];
          }
          {
            "name" = "bibtex";
            "command" = "bibtex";
            "args" = [
              "%DOCFILE%"
            ];
          }
        ];
        "latex-workshop.latex.recipes" = [
          {
            "name" = "xelatex";
            "tools" = [
              "xelatex"
            ];
          }
          {
            "name" = "pdflatex";
            "tools" = [
              "pdflatex"
            ];
          }
          {
            "name" = "xe->bib->xe->xe";
            "tools" = [
              "xelatex"
              "bibtex"
              "xelatex"
              "xelatex"
            ];
          }
          {
            "name" = "pdf->bib->pdf->pdf";
            "tools" = [
              "pdflatex"
              "bibtex"
              "pdflatex"
              "pdflatex"
            ];
          }
        ];
        "[latex]" = {
          "editor.formatOnPaste" = false;
          "editor.suggestSelection" = "recentlyusedbyprefix";
          "editor.wordWrap" = "bounded";
          "editor.wordWrapColumn" = 80;
          "editor.unicodeHighlight.ambiguousCharacters" = false;
        };
        "cmake.configureOnEdit" = false;
      };
    };
  };
}
