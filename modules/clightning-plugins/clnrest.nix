{ config, lib, pkgs, ... }:

with lib;
let
  options = {
    services.clightning.plugins.clnrest = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable clnrest (clightning plugin).

          clnrest provides a clightning REST API, using clightning RPC calls as its backend.
          It also broadcasts clightning notifications to listeners connected to its websocket server.

          See here for all available options:
          https://docs.corelightning.org/docs/rest
          Extra options can be set via `services.clightning.extraConfig`.
        '';
      };
      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address to listen for REST connections.";
      };
      port = mkOption {
        type = types.port;
        default = 3010;
        description = "REST server port.";
      };
      createAdminRune = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Create a rune with admin permissions at path `''${config.services.clightning.networkDir}/admin-rune`.
        '';
      };
      package = mkOption {
        type = types.package;
        default = config.nix-bitcoin.pkgs.nbPython3Packages.clnrest;
        defaultText = "config.nix-bitcoin.pkgs.nbPython3Packages.clnrest";
        description = "The package providing clnrest binaries.";
      };
    };

    # Internal read-only options used by `./nodeinfo.nix` and `./onion-services.nix`
    services.clnrest = let
      inherit (config.nix-bitcoin.lib) mkAlias;
    in {
      enable = mkAlias cfg.enable;
      address = mkAlias cfg.address;
      port = mkAlias cfg.port;
    };
  };

  cfg = config.services.clightning.plugins.clnrest;
  inherit (config.services) clightning;

  runePath = "${clightning.networkDir}/admin-rune";
in
{
  inherit options;

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${cfg.package}/bin/clnrest
      clnrest-host=${cfg.address}
      clnrest-port=${toString cfg.port}
    '';

    systemd.services.clightning.postStart = mkIf cfg.createAdminRune (mkAfter ''
      if [[ ! -e '${runePath}' ]]; then
        rune=$(${clightning.cli}/bin/lightning-cli createrune | ${pkgs.jq}/bin/jq -r .rune)
        install -m 640 <(echo "$rune") '${runePath}'
      fi
    '');
  };
}