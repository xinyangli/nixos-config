{ inputs, config, lib, pkgs, ... }:
with lib;

let
  cfg = config.custom-hm.vscode;

  packages = {
    nixPackages = {
      systemPackages = with pkgs; [ nixd nixpkgs-fmt ];
      extension = with inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace; [
        jnoortheen.nix-ide
      ];
      settings = {
        "nix.enableLanguageServer" = true;
        "nix.formatterPath" = "nixpkgs-fmt";
        "nix.serverPath" = "nixd";
      };
    };
    cxxPackages = {
      systemPackages = with pkgs; [ clang-tools cmake-format ];
      extension = with inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace; [
        llvm-vs-code-extensions.vscode-clangd
        (ms-vscode.cmake-tools.overrideAttrs (_: { sourceRoot = "extension"; }))
        twxs.cmake
        ms-vscode.cpptools
      ];
      settings = {
        "cmake.configureOnEdit" = false;
        "cmake.showOptionsMovedNotification" = false;
        "cmake.showNotAllDocumentsSavedQuestion" = false;
        "cmake.pinnedCommands" = [
          "workbench.action.tasks.configureTaskRunner"
          "workbench.action.tasks.runTask"
         ];
        "C_Cpp.intelliSenseEngine" = "Disabled";
      };
    };
    pythonPackages = {
      systemPackages = with pkgs; [ ];
      extension = with inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace; [
        ms-python.python
      ];
      settings = { };
    };
    scalaPackages = {
      systemPackages = with pkgs; [ coursier ];
      extension = with inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace; [
        scala-lang.scala
        scalameta.metals
      ];
      settings = { };
    };
    latexPackages = {
      systemPackages = with pkgs; [ texliveSmall ];
      extension = with inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace; [
        james-yu.latex-workshop
      ];
      settings = {
        "latex-workshop.latex.autoBuild.run" = "never";
        "latex-workshop.latex.tools" = [
          { "name" = "xelatex";
            "command" = "xelatex";
            "args" = [ "-synctex=1" "-interaction=nonstopmode" "-file-line-error" "%DOCFILE%" ];
          }
          { "name" = "pdflatex";
            "command" = "pdflatex";
            "args" = [ "-synctex=1" "-interaction=nonstopmode" "-file-line-error" "%DOCFILE%" ];
          }
          { "name" = "bibtex"; "command" = "bibtex"; "args" = [ "%DOCFILE%" ]; }
        ];
        "latex-workshop.latex.recipes" = [
          { "name" = "xelatex"; "tools" = [ "xelatex" ]; }
          { "name" = "pdflatex"; "tools" = [ "pdflatex" ]; }
          { "name" = "xe->bib->xe->xe"; "tools" = [ "xelatex" "bibtex" "xelatex" "xelatex" ]; }
          { "name" = "pdf->bib->pdf->pdf"; "tools" = [ "pdflatex" "bibtex" "pdflatex" "pdflatex" ]; }
        ];
        "[latex]" = {
          "editor.formatOnPaste" = false;
          "editor.suggestSelection" = "recentlyusedbyprefix";
          "editor.wordWrap" = "bounded";
          "editor.wordWrapColumn" = 80;
          "editor.unicodeHighlight.ambiguousCharacters" = false;
        };
      };
    };
  };

  languages = [ "nix" "cxx" "python" "scala" "latex" ];
  zipAttrsWithLanguageOption = (attr:
    (map (l: (lib.mkIf cfg.languages.${l} packages."${l}Packages".${attr})) languages)
  );
in
{
  options.custom-hm.vscode = {
    enable = mkEnableOption "Vscode config";
    languages = {
      nix = mkOption {
        type = lib.types.bool;
        default = true;
      };
      cxx = mkEnableOption "C++";
      python = mkEnableOption "Python";
      scala = mkEnableOption "Scala";
      latex = mkEnableOption "Latex";
    };
  };
  config = mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    home.packages = lib.mkMerge ([
      [ pkgs.clang-tools ]
    ] ++ zipAttrsWithLanguageOption "systemPackages");
    programs.vscode = {
      enable = true;
      package = pkgs.vscode.override { commandLineArgs = "--enable-wayland-ime"; };
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      mutableExtensionsDir = false;
      extensions = lib.mkMerge ([
        (with inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace; [
          mkhl.direnv

          ms-azuretools.vscode-docker
          ms-vscode-remote.remote-ssh
          vscodevim.vim
          github.vscode-pull-request-github
          gruntfuggly.todo-tree # todo highlight

          # Markdown
          davidanson.vscode-markdownlint
          # Latex
          # Scale / chisel
          sterben.fpga-support

          ms-vscode-remote.remote-ssh-edit
          mushan.vscode-paste-image
        ])
        (with pkgs.vscode-extensions; [
          waderyan.gitblame
          catppuccin.catppuccin-vsc
          # Rust
          rust-lang.rust-analyzer
        ])
      ] ++ zipAttrsWithLanguageOption "extension");
      userSettings = lib.mkMerge ([
      {"workbench.colorTheme" = "Catppuccin Macchiato";
        "terminal.integrated.sendKeybindingsToShell" = true;
        "extensions.ignoreRecommendations" = true;
        "files.autoSave" = "afterDelay";
        "editor.inlineSuggest.enabled" = true;
        "editor.rulers" = [
          80
        ];
        "editor.mouseWheelZoom" = true;
        "git.autofetch" = false;
        "window.zoomLevel" = -1;

        "extensions.experimental.affinity" = {
          "vscodevim.vim" = 1;
        };
      }] ++ zipAttrsWithLanguageOption "settings");
    };
  };
}
