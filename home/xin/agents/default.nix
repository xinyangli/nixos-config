{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.my-lib) flakePath settings;
  configDir = "${flakePath config}/config";
  codexPluginName = "agent-notify";
  codexPluginRoot = "${config.home.homeDirectory}/plugins/${codexPluginName}";
  agentNotifyTokenFile = "${config.xdg.configHome}/secrets/agent-notify-ntfy-token";
  agentNotify = pkgs.fetchgit {
    url = "https://git.xiny.li/xin/agent-notify";
    rev = "785f48c2213ad85766e0f39c44bd28bd3eda5f22";
    hash = "sha256-fIZNzJWs1rLVMkkBQ5jXeFqG3iFeYHtHNNQBPfVXgd0=";
  };

  codex-xdg = pkgs.symlinkJoin {
    name = "codex-xdg";
    paths = [ pkgs.llm-agents.codex ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      wrapProgram $out/bin/codex \
        --set CODEX_HOME "${config.xdg.configHome}/codex" \
        --prefix PATH : "${lib.makeBinPath [ pkgs.python3 ]}"
    '';
  };

  agentNotifyBridge = pkgs.writeShellApplication {
    name = "agent-notify-bridge";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [ -z "''${AGENT_NOTIFY_NTFY_TOKEN:-}" ]; then
        token_file="''${AGENT_NOTIFY_NTFY_TOKEN_FILE:-${agentNotifyTokenFile}}"
        if [ ! -s "$token_file" ]; then
          printf 'agent-notify-bridge: ntfy token file is missing or empty: %s\n' "$token_file" >&2
          exit 1
        fi
        export AGENT_NOTIFY_NTFY_TOKEN
        AGENT_NOTIFY_NTFY_TOKEN="$(tr -d '\r\n' < "$token_file")"
      fi

      if [ -z "$AGENT_NOTIFY_NTFY_TOKEN" ]; then
        printf 'agent-notify-bridge: ntfy token is empty\n' >&2
        exit 1
      fi

      export AGENT_NOTIFY_PLUGIN_ROOT="''${AGENT_NOTIFY_PLUGIN_ROOT:-${codexPluginRoot}}"
      export AGENT_NOTIFY_NTFY_BASE_URL="''${AGENT_NOTIFY_NTFY_BASE_URL:-${settings.ntfyUrl}}"
      export AGENT_NOTIFY_NTFY_SEND_TOPIC="''${AGENT_NOTIFY_NTFY_SEND_TOPIC:-agent-notify}"
      export AGENT_NOTIFY_NTFY_POLL_TOPIC="''${AGENT_NOTIFY_NTFY_POLL_TOPIC:-agent-notify-reply}"

      if [ "$#" -eq 0 ]; then
        set -- serve
      fi

      exec ${pkgs.python3}/bin/python3 ${agentNotify}/scripts/agent_notify_bridge.py \
        --codex-bin ${codex-xdg}/bin/codex \
        "$@"
    '';
  };

  personalMarketplace = {
    name = "personal";
    interface = {
      displayName = "Personal";
    };
    plugins = [
      {
        name = codexPluginName;
        source = {
          source = "local";
          path = "./plugins/${codexPluginName}";
        };
        policy = {
          installation = "AVAILABLE";
          authentication = "ON_INSTALL";
        };
        category = "Productivity";
      }
    ];
  };
in
{
  config = {
    nixpkgs.config.allowUnfree = true;
    home.packages = [
      agentNotifyBridge
      codex-xdg
    ] ++ (with pkgs.llm-agents; [
      pi
      rtk
      tuicr
    ]);

    home.sessionVariables = {
      AGENT_NOTIFY_PLUGIN_ROOT = codexPluginRoot;
      AGENT_NOTIFY_NTFY_BASE_URL = settings.ntfyUrl;
      AGENT_NOTIFY_NTFY_SEND_TOPIC = "agent-notify";
      AGENT_NOTIFY_NTFY_POLL_TOPIC = "agent-notify-reply";
      AGENT_NOTIFY_NTFY_TOKEN_FILE = agentNotifyTokenFile;
    };

    home.file."plugins/${codexPluginName}".source = agentNotify;
    home.file.".agents/plugins/marketplace.json".text = builtins.toJSON personalMarketplace;

    home.activation.installAgentNotifyCodexPlugin =
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        $DRY_RUN_CMD ${codex-xdg}/bin/codex plugin add ${codexPluginName}@personal >/dev/null
      '';

    systemd.user.services.agent-notify-bridge = {
      Unit = {
        Description = "Agent Notify Codex bridge";
        Documentation = "https://git.xiny.li/xin/agent-notify";
      };

      Service = {
        ExecStart = "${agentNotifyBridge}/bin/agent-notify-bridge serve";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = [ "default.target" ];
    };

    xdg.configFile."codex/skills".source =
      config.lib.file.mkOutOfStoreSymlink "${configDir}/agents/skills";
  };
}
