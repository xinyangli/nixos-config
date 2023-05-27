{ config, pkgs, inputs, system, ... }:
{
  programs.vscode = {
    enable = true;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    mutableExtensionsDir = false;
    extensions = (with inputs.nix-vscode-extensions.extensions.${system}.vscode-marketplace; [
      arrterian.nix-env-selector

      bbenoist.nix
      ms-azuretools.vscode-docker
      ms-vscode-remote.remote-ssh
      vscodevim.vim
      github.vscode-pull-request-github
      eamodio.gitlens
      gruntfuggly.todo-tree # todo highlight

      # Language support
      # Python
      ms-python.python
      # Markdown
      davidanson.vscode-markdownlint
      # C/C++
      ms-vscode.cmake-tools
      llvm-vs-code-extensions.vscode-clangd
      # Nix
      jnoortheen.nix-ide
      # Latex
      james-yu.latex-workshop
      # Vue
      vue.volar

      ms-vscode-remote.remote-ssh-edit
    ]) ++ (with inputs.nixpkgs.legacyPackages.${system}.vscode-extensions; [
      # Rust
      rust-lang.rust-analyzer

      mkhl.direnv
    ]);
    userSettings = {
      "workbench.colorTheme" = "Default Dark+";
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
        "editor.formatonpaste" = false;
        "editor.suggestselection" = "recentlyusedbyprefix";
        "editor.wordwrap" = "bounded";
        "editor.wordwrapcolumn" = 100;
        "editor.unicodehighlight.allowedlocales" = {
          "_os" = true;
          "_vscode" = true;
          "zh-hans" = true;
          "zh-hant" = true;
        };
      };
    };
  };
}
