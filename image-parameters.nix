{
  imageParameters = rec {
    # Set to true when ready to generate and distribute an image
    # so that image compression is used.
    prodImage = true;

    # This will add significant eval time and size to the image,
    # but may fix a problem if a flake related nix operation
    # can't complete within the airgap image.
    embedFlakeDeps = false;

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
