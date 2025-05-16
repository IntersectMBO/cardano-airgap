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

      "signing-tool-config.json".source = builtins.toFile "signing-tool-config.json" (builtins.toJSON {
        inherit documentsDir secretsDir;
      });
    };

    systemPackages = with self.packages.${system};
      [
        adawallet
        bech32
        cardano-address
        cardano-cli
        disko
        format-airgap-data
        menu
        orchestrator-cli
        signing-tool
        signing-tool-with-config
        unmount-airgap-data
        shutdown
      ]
      ++ (with pkgs; [
        cfssl
        cryptsetup
        glibc
        gnome3.adwaita-icon-theme
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
    (nerdfonts.override {fonts = ["FiraCode"];})
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
      enableCompletion = true;
      interactiveShellInit = lib.getExe self.packages.${system}.menu;
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
    displayManager.autoLogin.user = lib.mkForce airgapUser;

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
