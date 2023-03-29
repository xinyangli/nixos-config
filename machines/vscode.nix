{ config, lib, pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.vscode-with-extensions.override {
      vscodeExtensions = with pkgs.vscode-extensions; [
        arrterian.nix-env-selector

        bbenoist.nix
        ms-azuretools.vscode-docker
        ms-vscode-remote.remote-ssh
        vscodevim.vim
        github.copilot
        github.vscode-pull-request-github
        eamodio.gitlens
        gruntfuggly.todo-tree # todo highlight

        vadimcn.vscode-lldb # debugger

        # Language support
        ms-python.python
        davidanson.vscode-markdownlint
        llvm-vs-code-extensions.vscode-clangd
        jnoortheen.nix-ide
        james-yu.latex-workshop
        rust-lang.rust-analyzer
      ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "remote-ssh-edit";
          publisher = "ms-vscode-remote";
          version = "0.47.2";
          sha256 = "1hp6gjh4xp2m1xlm1jsdzxw9d8frkiidhph6nvl24d0h8z34w49g";
        }
      ];
    })
  ];
}
