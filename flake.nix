{
  inputs = {
    # Nixpkgs 24.11 for latest gnome image and devenv hooks
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    # Required image signing tooling
    credential-manager.url = "github:IntersectMBO/credential-manager";
    systems.url = "github:nix-systems/default";

    # For easy language and hook support
    devenv.url = "github:cachix/devenv/v1.6.1";
    devenv.inputs.nixpkgs.follows = "nixpkgs";

    # For declarative block device provisioning
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # A single address wallet that supports mnemonics and hardware wallets
    adawallet.url = "github:input-output-hk/adawallet/jl/update";

    # For fetch-closure shrunk release packages with minimal eval time and dependency sizes
    # Currently x86_64-linux only
    capkgs.url = "github:input-output-hk/capkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = [
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    ];
    extra-substituters = [
      "https://devenv.cachix.org"
      "https://cache.iog.io"
    ];
  };

  outputs = {
    self,
    nixpkgs,
    devenv,
    systems,
    ...
  } @ inputs: let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);
  in {
    # For direnv nix version shell evaluation
    inherit (nixpkgs) lib;

    # General image parameters used throughout nix code
    inherit (import ./image-parameters.nix) imageParameters;

    packages = forEachSystem (system: import ./packages.nix self system);

    devShells =
      forEachSystem
      (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
              packages = with self.packages.${system}; [
                adawallet
                bech32
                cardano-address
                cardano-cli
                cc-sign
                pkgs.cryptsetup
                disko
                orchestrator-cli
                qemu-run-iso
                tx-bundle
                pkgs.ventoy
              ];

              # https://devenv.sh/reference/options/
              languages.nix.enable = true;

              git-hooks.hooks = {
                alejandra.enable = true;
                deadnix.enable = true;
                statix.enable = true;
              };
            }
          ];
        };
      });

    nixosConfigurations.airgap-boot = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [./airgap-boot.nix];
      specialArgs = {
        inherit self;
        system = "x86_64-linux";
      };
    };

    diskoConfigurations.airgap-data = import ./airgap-data.nix self;
  };
}
