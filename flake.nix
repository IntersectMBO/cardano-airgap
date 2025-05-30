{
  inputs = {
    # Nixpkgs 25.05 for latest gnome image and devenv hooks
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # For latest package versions when required
    # nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Required image signing tooling
    credential-manager.url = "github:IntersectMBO/credential-manager";

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
    # nixpkgs-unstable,
    devenv,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;
    inherit (lib) collect isDerivation genAttrs nixosSystem;

    # Several required devShell/cli binaries and the ISO only build for
    # x86_64-linux.  Limit to this arch for now; expand later as needed.
    systems = ["x86_64-linux"];

    forEachSystem = genAttrs systems;
    pkgs = system: nixpkgs.legacyPackages.${system};
  in rec {
    # For direnv nix version shell evaluation
    inherit lib;

    # General image parameters used throughout nix code
    inherit (import ./image-parameters.nix) imageParameters;

    packages = forEachSystem (system: import ./packages.nix self system);

    devShells =
      forEachSystem
      (system: {
        default = devenv.lib.mkShell {
          inherit inputs;
          pkgs = pkgs system;
          modules = [
            {
              packages = with self.packages.${system}; [
                adawallet
                bech32
                cardano-address
                cardano-cli
                cardano-hw-cli
                cc-sign
                (pkgs system).cryptsetup
                disko
                orchestrator-cli
                qemu-run-iso
                tx-bundle
                # Until binary blobs are addressed and ventoy is set back to OSS license
                # (pkgs-system).ventoy-full
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

    nixosConfigurations.airgap-boot = nixosSystem {
      system = "x86_64-linux";
      modules = [./airgap-boot.nix];
      specialArgs = {
        inherit self;
        system = "x86_64-linux";
      };
    };

    diskoConfigurations.airgap-data = import ./airgap-data.nix self;

    hydraJobs =
      forEachSystem
      (system: let
        jobs = {inherit packages;};
      in
        jobs
        // {
          required = (pkgs system).releaseTools.aggregate {
            name = "required";
            constituents = collect isDerivation jobs;
          };
        });
  };
}
