{ config, lib, pkgs, ... }:

with lib;

{
  imports = [
    ./module.nix
  ];

  boot.isContainer = true;
  networking.hostName = mkDefault "deploynixos";
  networking.useDHCP = false;

  services.myapp.enable = true;
}
