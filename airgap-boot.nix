{
  lib,
  modulesPath,
  pkgs,
  self,
  system,
  ...
}: let
  inherit
    (self.imageParameters)
    embedFlakeDeps
    etcFlakePath
    hostId
    hostName
    documentsDir
    secretsDir
    signingUser
    signingUserUid
    signingUserGroup
    testImage
    ;

  inputPkg = input: pkg: self.inputs.${input}.packages.${system}.${pkg};
in {
  imports = [(modulesPath + "/installer/cd-dvd/installation-cd-graphical-gnome.nix")];

  boot = {
    initrd.availableKernelModules = [
      # Support for various usb hubs
      "ohci_pci"
      "ohci_hcd"
      "ehci_pci"
      "ehci_hcd"
      "xhci_pci"
      "xhci_hcd"

      # May be needed in some situations
      "uas"

      # Needed to mount usb as a storage device
      "usb-storage"
    ];

    kernelModules = ["kvm-intel"];

    supportedFilesystems = ["zfs"];

    # To address build time warn
    swraid.enable = lib.mkForce false;
  };

  documentation.info.enable = false;

  environment = {
    etc = {
      # Embed this flake source in the iso to re-use the disko or other configuration
      ${etcFlakePath}.source = self.outPath;

      "signing-tool-config.json".source = builtins.toFile "signing-tool-config.json" (builtins.toJSON {
        inherit documentsDir secretsDir;
      });
    };

    systemPackages = with pkgs; [
      (inputPkg "capkgs" "cardano-address-cardano-foundation-cardano-wallet-v2024-07-07-29e3aef")
      (inputPkg "capkgs" "\"cardano-cli:exe:cardano-cli\"-input-output-hk-cardano-cli-cardano-cli-9-0-0-1-33059ee")
      (inputPkg "credential-manager" "orchestrator-cli")
      (inputPkg "credential-manager" "signing-tool")
      (inputPkg "disko" "disko")

      self.packages.${system}.format-airgap-data
      self.packages.${system}.signing-tool-with-config
      self.packages.${system}.unmount-airgap-data

      cfssl
      cryptsetup
      glibc
      gnome.adwaita-icon-theme
      gnupg
      jq
      lvm2
      neovim
      openssl
      pwgen
      smem
      sqlite-interactive
      step-cli
      usbutils
      util-linux
    ];
  };

  # Used by starship for fonts
  fonts.packages = with pkgs; [
    (nerdfonts.override {fonts = ["FiraCode"];})
  ];

  # Disable squashfs for testing only
  # Set the flake.nix `imageParameters.testImage = false;` when ready to build the distribution image
  isoImage.squashfsCompression = lib.mkIf testImage ((lib.warn "Generating a testing only ISO with compression disabled") null);

  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
      accept-flake-config = true
    '';

    nixPath = ["nixpkgs=${pkgs.path}"];
    settings = {
      substituters = lib.mkForce [];
      trusted-users = [signingUser];
    };
  };

  nixpkgs.config.allowUnfree = true;

  networking = {
    inherit hostId hostName;

    enableIPv6 = lib.mkForce false;
    interfaces = lib.mkForce {};
    useDHCP = lib.mkForce false;
    wireless.enable = lib.mkForce false;
  };

  programs = {
    bash = {
      enableCompletion = true;
      interactiveShellInit = ''
        ${lib.getExe pkgs.nushell} -c \
          '"Welcome to the Airgap Shell" | ansi gradient --fgstart "0xffffff" --fgend "0xffffff" --bgstart "0x0000ff" --bgend "0xff0000"'
        echo
        echo "Some commands available are:"
        echo "  cardano-address"
        echo "  cardano-cli"
        echo "  format-airgap-data"
        echo "  orchestrator-cli"
        echo "  signing-tool"
        echo "  signing-tool-with-config"
        echo "  unmount-airgap-data"
      '';
    };

    fzf = {
      fuzzyCompletion = true;
      keybindings = true;
    };

    starship = {
      enable = true;
      settings = {
        git_commit = {
          tag_disabled = false;
          only_detached = false;
        };
        git_metrics = {
          disabled = false;
        };
        memory_usage = {
          disabled = false;
          format = "via $symbol[\${ram_pct}]($style) ";
          threshold = -1;
        };
        shlvl = {
          disabled = false;
          symbol = "↕";
          threshold = -1;
        };
        status = {
          disabled = false;
          map_symbol = true;
          pipestatus = true;
        };
        time = {
          disabled = false;
          format = "[\\[ $time \\]]($style) ";
        };
      };
    };

    dconf.enable = true;
    gnupg.agent.enable = true;
  };

  services = {
    displayManager.autoLogin.user = lib.mkForce signingUser;

    udev.extraRules = ''
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="1b7c", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="2b7c", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="3b7c", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="4b7c", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="1807", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="1808", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0000", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0001", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0004", MODE="0660", TAG+="uaccess", TAG+="udev-acl"
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="plugdev", ATTRS{idVendor}=="2c97"
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="plugdev", ATTRS{idVendor}=="2581"
      ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"
    '';
  };

  systemd.user.services.dconf-defaults = {
    script = let
      dconfDefaults = pkgs.writeText "dconf.defaults" ''
        [org/gnome/desktop/background]
        color-shading-type='solid'
        picture-options='zoom'
        picture-uri='${./cardano.png}'
        primary-color='#000000000000'
        secondary-color='#000000000000'

        [org/gnome/desktop/lockdown]
        disable-lock-screen=true
        disable-log-out=true
        disable-user-switching=true

        [org/gnome/desktop/notifications]
        show-in-lock-screen=false

        [org/gnome/desktop/screensaver]
        color-shading-type='solid'
        lock-delay=uint32 0
        lock-enabled=false
        picture-options='zoom'
        picture-uri='${./cardano.png}'
        primary-color='#000000000000'
        secondary-color='#000000000000'

        [org/gnome/settings-daemon/plugins/media-keys]
        custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']

        [org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0]
        binding='<Primary><Alt>t'
        command='gnome-terminal'
        name='terminal'

        [org/gnome/settings-daemon/plugins/power]
        idle-dim=false
        power-button-action='interactive'
        sleep-inactive-ac-type='nothing'

        [org/gnome/shell]
        welcome-dialog-last-shown-version='41.2'

        [org/gnome/terminal/legacy]
        theme-variant='dark'
      '';
    in ''
      ${pkgs.dconf}/bin/dconf load / < ${dconfDefaults}
    '';
    wantedBy = ["graphical-session.target"];
    partOf = ["graphical-session.target"];
  };

  users = {
    allowNoPasswordLogin = true;
    defaultUserShell = pkgs.bash;
    mutableUsers = false;

    users.cc-signer = {
      createHome = true;
      extraGroups = ["wheel"];
      group = signingUserGroup;
      home = "/home/${signingUser}";
      uid = signingUserUid;
      isNormalUser = true;
    };
  };

  system = {
    # This works to enable flake based disko builds within the image,
    # but adds significant eval time and size for image generation.
    #
    # Alternatively, the disko builds can be done using the
    # airgap-disko.nix configuration from within the image without
    # requiring the flake closure dependencies.
    extraDependencies = lib.mkIf embedFlakeDeps [(self.packages.${system}.flakeClosureRef self)];

    # To address build time warn
    stateVersion = lib.versions.majorMinor lib.version;
  };
}
