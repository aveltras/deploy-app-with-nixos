{ config, lib, pkgs, ... }:

with lib;

let

  pkg = import ./.;

  migrations = pkg.migrations;
  server = pkg.server;
  
  cfg = config.services.myapp;

in {

  options = {
    services.myapp = {
      enable = mkEnableOption "My App";

      user = mkOption {
        type = types.str;
        default = "myapp";
        description = "User account under which my app runs.";
      };

      port = mkOption {
        type = types.nullOr types.int;
        default = 3003;
        example = 8080;
        description = ''
          The port to bind my app server to.
        '';
      };
    };
  };
  
  config = mkIf cfg.enable {

    users.users.${cfg.user} = {
      name = cfg.user;
      description = "My app service user";
      isSystemUser = true;
    };

    services = {
      postgresql = {

        enable = true;

        enableTCPIP = true;
        ensureDatabases = [ cfg.user ];

        ensureUsers = [
          {
            name = cfg.user;
            ensurePermissions = {
              "DATABASE ${cfg.user}" = "ALL PRIVILEGES";
            };
          }
        ];

        authentication = pkgs.lib.mkOverride 10 ''
          local sameuser all peer
          host sameuser all ::1/32 trust
        '';
      };

      redis.enable = true;
    };
    
    systemd.services = {

      db-migration = {
        description = "DB migrations script";
        wantedBy = [ "multi-user.target" ];
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];

        environment = {
          DATABASE_URL = "postgres://${cfg.user}@localhost:5432/myapp?sslmode=disable";
        };
        
        serviceConfig = {
          User = cfg.user;
          Type = "oneshot";
          ExecStart = "${pkgs.dbmate}/bin/dbmate -d ${migrations} --no-dump-schema up";
        };
      };
      
      myapp = {
        wantedBy = [ "multi-user.target" ];
        description = "Start my app server.";
        after = [ "network.target" ];
        requires = [ "db-migration.service" ];

        environment = {
          APP_PORT = toString cfg.port;
          DATABASE_URL = "postgres:///${cfg.user}";
        };
        
        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          ExecStart = ''${server}/bin/server'';
          Restart = "always";
          KillMode = "process";
        };
      };
    };
  };
}
