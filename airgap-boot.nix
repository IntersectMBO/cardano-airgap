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
    etcFlakePath
    hostId
    hostName
    documentsDir
    secretsDir
    airgapUser
    airgapUserUid
    airgapUserGroup
    prodImage
    ;
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

      # Deprecated: signing-tool
      # "signing-tool-config.json".source = builtins.toFile "signing-tool-config.json" (builtins.toJSON {
      #   inherit documentsDir secretsDir;
      # });
    };

    systemPackages = with self.packages.${system};
      [
        adawallet
        bech32
        cardano-address
        cardano-cli
        cardano-hw-cli
        cc-sign
        disko
        format-airgap-data
        menu
        orchestrator-cli
        # Deprecated: signing-tool
        # signing-tool-with-config
        tx-bundle
        unmount-airgap-data
        shutdown
      ]
      ++ (with pkgs; [
        cfssl
        cryptsetup
        glibc
        adwaita-icon-theme
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
      ]);

    variables = {
      ENC_DIR = secretsDir;
      PUB_DIR = documentsDir;
    };
  };

  # Used by starship for fonts
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
  ];

  # Disable squashfs for testing only
  # Set the flake.nix `imageParameters.prodImage = true;` when ready to build the distribution image to use image compression
  isoImage.squashfsCompression = lib.mkIf (!prodImage) ((lib.warn "Generating a testing only ISO with compression disabled") null);

  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
      accept-flake-config = true
    '';

    nixPath = ["nixpkgs=${pkgs.path}"];
    settings = {
      substituters = lib.mkForce [];
      trusted-users = [airgapUser];
    };
  };

  nixpkgs.config.allowUnfree = true;

  networking = {
    inherit hostId hostName;

    enableIPv6 = lib.mkForce false;
    interfaces = lib.mkForce {};
    networkmanager.enable = lib.mkForce false;
    useDHCP = lib.mkForce false;
    wireless.enable = lib.mkForce false;
  };

  programs = {
    bash = {
      completion.enable = true;
      interactiveShellInit = lib.getExe self.packages.${system}.menu;
    };

    fzf = {
      fuzzyCompletion = true;
      keybindings = true;
    };

    starship = {
      enable = true;
      presets = ["nerd-font-symbols"];
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
    displayManager.autoLogin.user = lib.mkForce airgapUser;

    udev.extraRules = ''
      # Ledger rules, source: https://github.com/LedgerHQ/udev-rules/blob/master/20-hw1.rules
      # HW.1, Nano
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="1b7c|2b7c|3b7c|4b7c", TAG+="uaccess", TAG+="udev-acl"

      # Blue, NanoS, Aramis, HW.2, Nano X, NanoSP, Stax, Ledger Test,
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", TAG+="uaccess", TAG+="udev-acl"

      # Same, but with hidraw-based library (instead of libusb)
      KERNEL=="hidraw*", ATTRS{idVendor}=="2c97", MODE="0666"

      # Trezor rules, source: https://trezor.io/guides/trezorctl/udev-rules
      # Trezor
      SUBSYSTEM=="usb", ATTR{idVendor}=="534c", ATTR{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
      KERNEL=="hidraw*", ATTRS{idVendor}=="534c", ATTRS{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

      # Trezor v2
      SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c0", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
      SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
      KERNEL=="hidraw*", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

      # Thunderbolt support
      ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"
    '';
  };

  environment.etc."xdg/autostart/gnome-console.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Console
    Exec=kgx
    X-GNOME-Autostart-enabled=true
    NoDisplay=false
    Terminal=false
    Hidden=false
  '';

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
        command='kgx'
        name='console'

        [org/gnome/settings-daemon/plugins/power]
        idle-dim=false
        power-button-action='interactive'
        sleep-inactive-ac-type='nothing'

        [org/gnome/shell]
        welcome-dialog-last-shown-version='41.2'
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

    users.${airgapUser} = {
      createHome = true;
      extraGroups = ["wheel"];
      group = airgapUserGroup;
      home = "/home/${airgapUser}";
      uid = airgapUserUid;
      isNormalUser = true;
    };
  };

  system.stateVersion = lib.versions.majorMinor lib.version;
}
