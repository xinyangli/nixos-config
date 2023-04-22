{ config, ... }: {
  programs.alacritty = {
    enable = true;
    settings = {
      shell = {
        program = config.programs.zellij.package + "/bin/zellij";
      };
      font.size = 10.0;
      window = {
        resize_increments = true;
        dynamic_padding = true;
      };
    };
  };
}