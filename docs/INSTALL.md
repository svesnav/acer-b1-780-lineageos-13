# Install LineageOS 13

This guide is only for the Acer Iconia One 7 B1-780 Wi-Fi (`acer_barricadewifi`). It uses raw partition images, so verify the model and every checksum before flashing.

## 1. Prepare and back up

1. Unlock the bootloader. Unlocking erases user data.
2. Install the persistent B1-780 TWRP recovery from the companion TWRP repository.
3. Boot TWRP. The stock recovery screen can appear for about eight seconds before TWRP starts.
4. In TWRP, back up Boot, System, Data and NVRAM when available.
5. Copy the complete TWRP backup directory to the computer.

## 2. Download and verify

Download the boot image, compressed system image and `SHA256SUMS.txt` from the latest release. Verify their SHA-256 hashes, then extract `lineage-13.0-b1-780-system.img.7z` with 7-Zip.

## 3. Wipe and flash

In TWRP, wipe System, Data, Cache and Dalvik/ART Cache. Keep TWRP open and verify that ADB sees a recovery device:

```text
adb devices
```

From the repository directory, write the raw images with the included guarded transfer tool:

```text
python tools/flash-raw-via-adb.py lineage-13.0-b1-780-system.img system
python tools/flash-raw-via-adb.py lineage-13.0-b1-780-boot.img boot
```

The tool checks that the target is a recovery environment before writing. Do not disconnect the cable while either transfer is running.

## 4. First boot

Reboot System from TWRP. The first boot takes longer than later boots. If the Acer bootloader refuses a software reboot, hold Power for about 10–15 seconds and start the tablet normally.

After Android starts, complete setup and grant Camera permissions when asked. Both cameras, audio, Bluetooth, battery reporting and the charge LED have been tested on the target tablet.
