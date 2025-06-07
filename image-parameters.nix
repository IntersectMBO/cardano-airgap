{
  imageParameters = rec {
    # Set to true when ready to generate and distribute an image
    # so that image compression is used.
    prodImage = true;

    # Required for the image disko offline formatter script.
    etcFlakePath = "flake";

    publicVolName = "public";
    encryptedVolName = "encrypted";

    documentsDir = "/run/media/${airgapUser}/${publicVolName}";
    secretsDir = "/run/media/${airgapUser}/${encryptedVolName}";

    hostId = "ffffffff";
    hostName = "cardano-airgap";

    airgapUser = "airgap";
    airgapUserUid = 1234;
    airgapUserGid = 100;
    airgapUserGroup = "users";
  };
}
