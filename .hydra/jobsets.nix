{ pulls, ... }:
let
  prs = builtins.fromJSON (builtins.readFile pulls);
  prJobsets = builtins.listToAttrs (
    map (num: {
      name = "pr-${num}";
      value = {
        enabled = 1;
        hidden = false;
        description = "PR ${num}: ${prs.${num}.title}";
        checkinterval = 300;
        schedulingshares = 20;
        enableemail = false;
        emailoverride = "";
        keepnr = 1;
        type = 1;
        flake = "github:xinyangli/nixos-config/pull/${num}/head";
      };
    }) (builtins.attrNames prs)
  );
in
{
  jobsets = derivation {
    name = "spec-jobsets.json";
    system = builtins.currentSystem;
    builder = "/bin/sh";
    args = [
      "-c"
      ''
        printf '%s' "$jobsetsJson" > "$out"
      ''
    ];
    jobsetsJson = builtins.toJSON prJobsets;
  };
}
