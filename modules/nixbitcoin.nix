{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nixbitcoin;
  secrets = import ../load-secrets.nix;
in {
  imports =
    [
      ./bitcoind.nix
      ./tor.nix
      ./clightning.nix
    ];

  options.services.nixbitcoin = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the nix-bitcoin service will be installed.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Tor
    services.tor.enable = true;
    services.tor.client.enable = true;
    services.tor.hiddenServices.bitcoind = {
      map = [{
        port = config.services.bitcoind.port;
      }];
      version = 3;
    };

    # bitcoind
    services.bitcoind.enable = true;
    services.bitcoind.listen = true;
    services.bitcoind.proxy = config.services.tor.client.socksListenAddress;
    services.bitcoind.port = 8333;
    services.bitcoind.rpcuser = "bitcoinrpc";
    services.bitcoind.rpcpassword = secrets.bitcoinrpcpassword;

    # clightning
    services.clightning.enable = true;
    services.clightning.bitcoin-rpcuser = config.services.bitcoind.rpcuser;
    services.clightning.bitcoin-rpcpassword = config.services.bitcoind.rpcpassword;

    # nodeinfo
    systemd.services.nodeinfo = {
      description = "Get node info";
      wantedBy = [ "multi-user.target" ];
      path  = [ pkgs.clightning pkgs.jq pkgs.sudo ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c ${pkgs.nodeinfo}/bin/nodeinfo";
        user = "root";
        type = "oneshot";
      };
    };
  };
}