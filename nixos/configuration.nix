{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;

  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;
  networking.usePredictableInterfaceNames = false;

  i18n = {
    defaultLocale = "fr_FR.UTF-8";
    supportedLocales = [ "fr_FR.UTF-8/UTF-8" ];
    inputMethod.enabled = "ibus";
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "fr";
  };
  
  time.timeZone = "Europe/Paris";

  environment.systemPackages = with pkgs; [

  ];

  services.openssh.enable = true;

  # In case you want to be able to login as root without public key:
  # services.openssh.permitRootLogin = "yes";
  # nix-shell -p mkpasswd --run 'mkpasswd -m sha-512 nixosdemo'
  # users.users.root.initialHashedPassword = "$6$ElZ9YNBW/hBJYjo$7TSbGs.H0abwIHUJe3zPQ8NScs6AKOKB7Br6TBEZk.vgZ7J9neAVL8CbTIGOPfW8oirGP1b6kRErQvo/r9jmX1";
  
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICRH41b8Qn+80OJuZssDDfqcSkH3MkVyqoA4I8V2FkW7 romain"
  ];
  
  system.stateVersion = "20.03";
}

