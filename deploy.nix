let

  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs-channels/archive/nixos-20.03.tar.gz";
  }) {};

in {

  network =  {
    inherit pkgs;
    description = "My NixOS server";
  };

  "159.69.155.132" = { config, pkgs, ... }: {

    deployment = {
      targetUser = "root";
    };

    imports = [
      ./nixos/configuration.nix
      ./module.nix
    ];

    networking = {
      domain = "demo.romainviallard.dev";
      firewall.allowedTCPPorts = [ 80 443 ];
    };
    
    security.acme = {
      acceptTerms = true;
      # validMinDays = 999; # force renewal
      # server = "https://acme-staging-v02.api.letsencrypt.org/directory";
      email = "romain@romainviallard.dev";
      certs."demo.romainviallard.dev".extraDomains = {
        # "demo2.romainviallard.dev" = null;
      };
    };
    
    services.myapp = {
      enable = true;
      port = 8080;
    };

    services.nginx = {
      enable = true;

      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      # https://nixos.org/nixos/manual/#module-security-acme-nginx
      virtualHosts = {
        
        "demo.romainviallard.dev" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.myapp.port}";
          };
        };

        # "demo2.romainviallard.dev" = {
        #   useACMEHost = "demo.romainviallard.dev";
        #   forceSSL = true;
        #   locations."/" = {
        #     proxyPass = "http://127.0.0.1:${toString config.services.myapp.port}";
        #   };
        # };
      };
    };
    
  };
}
