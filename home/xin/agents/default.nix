{
  config,
  pkgs,
  ...
}:
let
  inherit (config.my-lib) flakePath;
  configDir = "${flakePath config}/config";

  claude-code-xdg = pkgs.symlinkJoin {
    name = "claude-code-xdg";
    paths = [ pkgs.llm-agents.claude-code ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      wrapProgram $out/bin/claude \
        --set CLAUDE_CONFIG_DIR "${config.xdg.configHome}/claude"
    '';
  };

  codex-xdg = pkgs.symlinkJoin {
    name = "codex-xdg";
    paths = [ pkgs.llm-agents.codex ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      wrapProgram $out/bin/codex \
        --set CODEX_HOME "${config.xdg.configHome}/codex"
    '';
  };
in
{
  config = {
    home.packages = [
      claude-code-xdg
      codex-xdg
    ];

    xdg.configFile."codex/skills".source =
      config.lib.file.mkOutOfStoreSymlink "${configDir}/agents/skills";
    xdg.configFile."claude/skills".source =
      config.lib.file.mkOutOfStoreSymlink "${configDir}/agents/skills";
  };
}
