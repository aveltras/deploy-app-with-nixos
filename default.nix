let

  nixpkgsRev = "nixos-20.03";
  compilerVersion = "ghc865";
  compilerSet = pkgs.haskell.packages."${compilerVersion}";

  githubTarball = owner: repo: rev:
    builtins.fetchTarball { url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz"; };

  ghcide = (import (githubTarball "cachix" "ghcide-nix" "5bd24cfc991584b360c9b5bd4e45e18d8ec669b0") {})."ghcide-${compilerVersion}";
  pkgs = import (githubTarball "NixOS" "nixpkgs-channels" nixpkgsRev) { inherit config; };
  gitIgnore = pkgs.nix-gitignore.gitignoreSourcePure;
  
  config = {
    packageOverrides = super: let self = super.pkgs; in rec {
      haskell = super.haskell // {
        packageOverrides = self: super: with pkgs.haskell.lib; {
          server = super.callCabal2nix "server" (gitIgnore [./.gitignore] ./.) {};
          hasql-th = dontCheck super.hasql-th;
        };
      };
    };
  };
  
in {
  inherit pkgs;

  server = pkgs.haskellPackages.server;

  migrations = pkgs.runCommand "mkMigrations" {} ''
    mkdir $out
    cp -r ${./db/migrations}/*.sql $out 
  '';

  shell = compilerSet.shellFor {
    packages = p: [p.server];
    buildInputs = with pkgs; [
      compilerSet.cabal-install
      dbmate
      ghcide
      stylish-haskell
    ];
  };
}
