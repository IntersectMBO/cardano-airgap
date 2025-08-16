self: system: let
  inherit (self.imageParameters) documentsDir etcFlakePath secretsDir;
  inherit (self.lib) filter hasSuffix head;
  inherit (builtins) attrNames readDir;

  pkgs = self.inputs.nixpkgs.legacyPackages.${system};
  capkgs = self.inputs.capkgs.packages.${system};
in rec {
  # Inputs packages, collected here for easier re-use throughout the flake
  inherit (self.inputs.credential-manager.packages.${system}) cc-sign orchestrator-cli tx-bundle;
  inherit (self.inputs.disko.packages.${system}) disko;

  # Cardano-cli should remain version matched to adawallet to avoid wrapper errors
  inherit (self.inputs.adawallet.packages.${system}) adawallet cardano-address cardano-cli cardano-hw-cli cardano-signer;

  bech32 = capkgs.bech32-input-output-hk-cardano-node-10-4-1-420c94f;

  default = iso;

  # Repo defined packages
  format-airgap-data = pkgs.writeShellApplication {
    name = "format-airgap-data";
    runtimeInputs = with pkgs; [
      disko
      usbutils
      util-linux
    ];

    text = ''
      ARGS=("$@")

      PRINT_HELP() {
        echo "Command usage:"
        echo "  format-airgap-data [--dry-run] --argstr device \"\$YOUR_AIRGAP_DATA_DRIVE\" [extra-options]"
        echo
        echo "Where:"
        echo "\$YOUR_AIRGAP_DATA_DRIVE is the path to the airgap data"
        echo "drive, which may be something like: /dev/sda"
        echo
        echo "The device being formatted should be at least 16 GB in size or the format may fail."
        echo
        echo "[extra-options] may be additional options as accepted by disko"
        echo "These can be viewed with the command: disko --help"
        echo
        echo "Commands which can help you identify the proper drive to format are:"
        echo
        echo "lsblk -o +label:"
        lsblk -o +label
        echo
        echo "lsusb:"
        lsusb
        echo
        exit
      }

      DRY_RUN="false"
      if [ "$#" = "0" ]; then
        PRINT_HELP
      elif [[ " ''${ARGS[*]} " =~ [[:space:]]-h[[:space:]] ]]; then
        PRINT_HELP
      elif [[ " ''${ARGS[*]} " =~ [[:space:]]--help[[:space:]] ]]; then
        PRINT_HELP
      elif [[ ! " ''${ARGS[*]} " =~ [[:space:]]--argstr[[:space:]]device[[:space:]] ]]; then
        PRINT_HELP
      elif [[ " ''${ARGS[*]} " =~ [[:space:]]--dry-run[[:space:]] ]]; then
        DRY_RUN="true"
      fi

      for i in "''${!ARGS[@]}"; do
       if [ "''${ARGS[$i]}" = "device" ]; then
         if [ "$#" -lt "$((i + 2))" ]; then
           PRINT_HELP
         fi
         DEVICE=''${ARGS[$i + 1]};
       fi
      done

      if [ "$DRY_RUN" = "false" ]; then
        echo "WARNING: Device $DEVICE is about to be completely wiped and formatted!"
        echo "         Only proceed if you are sure you know what you are doing."
        echo "         Otherwise, seek assistance instead."
        echo
        read -p "Do you wish to proceed [yY]? " -n 1 -r
        echo
        if ! [[ $REPLY =~ ^[Yy]$ ]]; then
          echo "Aborting."
          exit
        fi
        echo "Wiping and formatting $DEVICE starting in 10 seconds..."
        sleep 10
      else
        echo "Dry run request detected -- no actual formatting actions will be carried out."
        echo "The final script path printed below can be reviewed prior to running for real."
        echo
      fi

      sudo disko \
      -m destroy,format,mount \
      --yes-wipe-all-disks \
      /etc/${etcFlakePath}/airgap-disko.nix \
      "$@"
    '';
  };

  iso = let
    inherit (self.nixosConfigurations.airgap-boot.config.system.build) isoImage;

    isoName' = head (filter
      (p: hasSuffix ".iso" p)
      (attrNames (readDir "${isoImage}/iso")));

    isoName = "airgap-boot-${shortRev}-${isoName'}";

    shortRev = self.sourceInfo.shortRev or "dirty";
  in
    pkgs.runCommand isoName {} ''
      mkdir -p "$out/iso"
      mkdir -p "$out/nix-support"

      # Copy rather than symlink so hydra download links show size and sha256 hash
      cp "${isoImage}/iso/${isoName'}" "$out/iso/${isoName}"

      echo "file iso $out/iso/${isoName}" > "$out/nix-support/hydra-build-products"
      echo "${system}" > "$out/nix-support/system"
    '';

  menu = pkgs.writeShellApplication {
    name = "menu";
    runtimeInputs = with pkgs; [nushell];

    text = ''
      nu -c \
        '"Welcome to the Airgap Shell" | ansi gradient --fgstart "0xffffff" --fgend "0xffffff" --bgstart "0x0000ff" --bgend "0xff0000"'
      echo
      echo "Some commands available are:"
      echo "  adawallet"
      echo "  bech32"
      echo "  cardano-address"
      echo "  cardano-cli"
      echo "  cardano-hw-cli"
      echo "  cardano-signer"
      echo "  cc-sign"
      echo "  cfssl"
      echo "  format-airgap-data"
      echo "  ipython"
      echo "  menu"
      echo "  openssl"
      echo "  orchestrator-cli"
      echo "  pwgen"
      echo "  shutdown"
      # Deprecated
      # echo "  signing-tool-with-config"
      echo "  step"
      echo "  tx-bundle"
      echo "  unmount-airgap-data"
      echo "  xxd"
    '';
  };

  qemu-run-iso = pkgs.writeShellApplication {
    name = "qemu-run-iso";
    runtimeInputs = with pkgs; [fd qemu_kvm];

    text = ''
      if fd --type file --has-results 'airgap-boot-.*\.iso' result/iso 2> /dev/null; then
        echo "Symlinking the existing iso image for qemu:"
        ln -sfv result/iso/airgap-boot-*.iso result-iso
        echo
      else
        echo "No iso file exists to run, please build one first, example:"
        echo "  nix build -L .#iso"
        exit
      fi

      if [ "$#" = 0 ]; then
        echo "Not passing through any host devices; see the README.md if you would like to do that."
      fi

      # To disallow a network nic, pass: -nic none
      # See README.md for additional args to pass through a host device
      qemu-kvm \
        -smp 2 \
        -m 4G \
        -drive file=result-iso,format=raw,if=none,media=cdrom,id=drive-cd1,readonly=on \
        -device ahci,id=achi0 \
        -device ide-cd,bus=achi0.0,drive=drive-cd1,id=cd1,bootindex=1 \
        "$@"
    '';
  };

  shutdown = pkgs.writeShellApplication {
    name = "shutdown";
    runtimeInputs = [unmount-airgap-data];

    text = ''
      unmount-airgap-data
      systemctl poweroff -i
    '';
  };

  # Deprecated
  # signing-tool-with-config = pkgs.writeShellApplication {
  #   name = "signing-tool-with-config";
  #   runtimeInputs = [signing-tool];

  #   text = ''
  #     cc-sign --config-file /etc/signing-tool-config.json "$@" &> /dev/null || {
  #       echo "ERROR: Has the airgap-data device already been mounted?"
  #       echo "       If not, once the airgap-data device is mounted, try again."
  #       echo
  #       echo "If needed, debug output can be seen by running:"
  #       echo "  signing-tool --config-file /etc/signing-tool-config.json"
  #     }
  #   '';
  # };

  unmount-airgap-data = pkgs.writeShellApplication {
    name = "unmount-airgap-data";
    runtimeInputs = with pkgs; [cryptsetup gnugrep util-linux];
    bashOptions = ["errtrace" "errexit" "nounset" "pipefail"];

    text = ''
      ERROR() {
        echo
        echo "ERROR: An error occurred trying to unmount."
        echo "       Please check the text above, remedy"
        echo "       the cause, and try again."
        echo
        echo "Also ensure:"
        echo "  * No programs have files open on the airgap-data partitions"
        echo "  * No shells have a working directory in an airgap-data partition"
      }

      trap 'ERROR' ERR

      UNMOUNT() {
        MOUNTPOINT="$1"
        if df | grep --quiet "$MOUNTPOINT"; then
          sudo umount --verbose "$MOUNTPOINT"
        else
          echo "Not currently mounted: $MOUNTPOINT"
        fi
      }

      echo "Unmounting:"
      UNMOUNT ${documentsDir}
      UNMOUNT ${secretsDir}
      echo

      echo "Closing crypted luks volumes."
      sudo bash -c 'dmsetup ls --target crypt --exec "cryptsetup close"'
      echo

      echo "Syncing."
      sync

      echo
      echo "If no unexpected errors are seen above,"
      echo "then it is safe to remove the airgap-data device."
    '';
  };
}
