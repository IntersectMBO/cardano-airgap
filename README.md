## Build the airgap-boot disk image:
```bash
$ nix build .#iso
```

## Test the airgap-boot image:
```bash
qemu-run-iso
```

## Test the airgap-boot image with a host passed device:
```bash
# Find the device of interest, in this case a thumbdrive:
❯ lsusb | grep -i sandisk
Bus 001 Device 030: ID 0781:5567 SanDisk Corp. Cruzer Blade

# Pass the device to qemu based on vendor and product id:
sudo qemu-run-iso -device nec-usb-xhci,id=xhci -device usb-host,vendorid=0x0781,productid=0x5567

# Or, pass a bus and address to qemu:
sudo qemu-run-iso -device nec-usb-xhci,id=xhci -device usb-host,hostbus=1,hostaddr=30
```

## Fomat the airgap-data device:
WARNING -- BE ABSOLUTELY SURE YOU HAVE THE CORRECT DEVICE LISTED AS THIS DRIVE WILL BE WIPED!

WARNING -- Do a dry first and review the output script if desired.

WARNING -- The device should be at least 16 GB in size or the format may fail.

Below, `$YOUR_AIRGAP_DATA_DRIVE` is the path to the airgap data device,
which may be something like: `/dev/sdb`.

### From within the airgap boot image:
```bash
format-airgap-data --dry-run --argstr device "$YOUR_AIRGAP_DATA_DRIVE"

# If satisfied with the dry run script, proceed with the formatting:
format-airgap-data --argstr device "$YOUR_AIRGAP_DATA_DRIVE"
```

### From the flake devShell of a networked machine:
```bash
disko -m destroy,format,mount --dry-run -f .#airgap-data --argstr device "$YOUR_AIRGAP_DATA_DRIVE"

# If satisfied with the dry run script, proceed with the formatting:
sudo disko -m destroy,format,mount -f .#airgap-data --argstr device "$YOUR_AIRGAP_DATA_DRIVE"
```
