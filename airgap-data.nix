self: {device ? "/dev/disk/AIRGAP_DATA_DEVICE_UPDATE_ME", ...}: let
  inherit
    (self.imageParameters)
    airgapUserUid
    airgapUserGid
    publicVolName
    encryptedVolName
    ;

  uidGid = "${toString airgapUserUid}:${toString airgapUserGid}";
in {
  disko.devices = {
    disk.main = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          public = {
            size = "8G";
            content = {
              type = "filesystem";
              format = "ext4";
              extraArgs = ["-L" "${publicVolName}" "-E" "root_owner=${uidGid}"];
            };
          };

          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = encryptedVolName;
              askPassword = true;

              # For the ultra-paranoid, allowDiscards can be changed to false.
              # Allowing discards may enhance flash or ssd performance and
              # longevity at the expense of possibly slightly reducing
              # encryption security.
              #
              # A good discussion is here:
              #   https://askubuntu.com/questions/399211/is-enabling-trim-on-an-encrypted-ssd-a-security-risk
              settings.allowDiscards = true;

              # The default key derivation function, `argon2id`, is "memory
              # hard" and may require substantial memory to both create and
              # subsequently open the luks crypted partition.
              #
              # For machines that have too little memory and the initial
              # formatting fails, or if the drive is being created on a machine
              # with large memory and then opened on a machine with small
              # memory, the drive may need to be created with the older
              # `pbkdf2` algorithm which is not memory hard.
              #
              # After a luks crypted volume using argon2id is opened, the
              # required opening memory can be viewed in the output of:
              #
              #   sudo cryptsetup luksDump $DEVICE
              #
              # The older `pbkdf2` algorithm can be used by switching to the
              # commented line below:
              # extraFormatArgs = ["--label ${encryptedVolName}" "--pbkdf pbkdf2"];
              extraFormatArgs = ["--label ${encryptedVolName}"];

              postMountHook = "dmsetup ls --target crypt --exec 'cryptsetup close' 2> /dev/null";
              content = {
                type = "filesystem";
                format = "ext4";
                extraArgs = ["-L" "${encryptedVolName}" "-E" "root_owner=${uidGid}"];
              };
            };
          };
        };
      };
    };
  };
}
