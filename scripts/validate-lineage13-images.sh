#!/usr/bin/env bash
set -euo pipefail

workspace="/mnt/c/Users/slava/Documents/Acer LineageOS"
system_image="$workspace/builds/lineage-13.0-b1-780-system.img"
boot_image="$workspace/builds/lineage-13.0-b1-780-boot.img"
mount_dir="/home/slava/lineage-b1-780/validate-system"
product="/home/slava/lineage-b1-780/cm13/out/target/product/acer_barricadewifi"
aapt="/home/slava/lineage-b1-780/cm13/out/host/linux-x86/bin/aapt"
partition_size=3758096384

[ "$(stat -c %s "$system_image")" -eq "$partition_size" ]
[ "$(stat -c %s "$boot_image")" -le 16777216 ]
e2fsck -fn "$system_image"

mkdir -p "$mount_dir"
mount -o loop,ro "$system_image" "$mount_dir"
bt_resources_file="$(mktemp)"
trap 'rm -f "$bt_resources_file"; umount "$mount_dir"' EXIT

grep -q '^ro.build.version.release=6.0.1$' "$mount_dir/build.prop"
grep -q '^ro.build.version.sdk=23$' "$mount_dir/build.prop"
grep -q '^ro.product.device=acer_barricadewifi$' "$mount_dir/build.prop"
grep -q '^ro.cm.version=13.0-' "$mount_dir/build.prop"
grep -q '^ro.lineage.device=acer_barricadewifi$' "$mount_dir/build.prop"
grep -q '^ro.radio.noril=true$' "$mount_dir/build.prop"
grep -q '^Acer B1-780 Android 6 proprietary blobs overlaid$' \
  "$mount_dir/etc/b1-780-lineage13-blobs.txt"

for bits in lib lib64; do
  for hal in audio.primary camera gralloc hwcomposer lights sensors; do
    test -f "$mount_dir/$bits/hw/$hal.mt8163.so"
  done
done

for bits in lib lib64; do
  for camera_lib in libcam_platform.so libcam.device1.so libcam.device3.so libJpgEncPipe.so; do
    test -f "$mount_dir/$bits/$camera_lib"
  done
done
test -f "$mount_dir/etc/media_profiles.xml"
grep -q '<CamcorderProfiles cameraId="0">' "$mount_dir/etc/media_profiles.xml"
grep -q '<CamcorderProfiles cameraId="1">' "$mount_dir/etc/media_profiles.xml"

test ! -e "$mount_dir/recovery-from-boot.p"
test ! -e "$mount_dir/bin/install-recovery.sh"
test ! -e "$mount_dir/etc/permissions/org.cyanogenmod.telephony.xml"

for file in \
  etc/audio_device.xml \
  etc/audio_em.xml \
  etc/audio_param/AudioParamOptions.xml \
  lib/libbt-vendor.so \
  lib/libbtcusttable.so \
  lib/libbluetooth_mtk.so \
  lib64/libbtcusttable.so; do
  test -f "$mount_dir/$file"
done

# Ensure the tested MTK Bluetooth compatibility build, including disabled
# vendor-incompatible HID-device and Health profiles, is in the image.
cmp "$mount_dir/app/Bluetooth/Bluetooth.apk" \
  "$product/system/app/Bluetooth/Bluetooth.apk"
cmp "$mount_dir/lib/libbluetooth_jni.so" \
  "$product/system/lib/libbluetooth_jni.so"
$aapt dump resources "$mount_dir/app/Bluetooth/Bluetooth.apk" > "$bt_resources_file"
grep -q 'profile_supported_hdp: t=0x12 d=0x00000000' "$bt_resources_file"
grep -q 'profile_supported_hidd: t=0x12 d=0x00000000' "$bt_resources_file"

# Absolute /system links appear broken on the build host but resolve on the
# device.  Check every such target against the mounted image namespace.
python3 - "$mount_dir" <<'PY'
import os
import sys
from pathlib import Path

root = Path(sys.argv[1])
bad = []
for path in root.rglob("*"):
    if not path.is_symlink():
        continue
    target = os.readlink(path)
    if target.startswith("/system/"):
        resolved = root / target.removeprefix("/system/")
    elif target.startswith("/"):
        continue
    else:
        resolved = path.parent / target
    if not resolved.exists():
        bad.append(f"{path.relative_to(root)} -> {target}")
if bad:
    raise SystemExit("broken system symlinks:\n" + "\n".join(bad))
print("system symlinks: OK")
PY

sha256sum "$boot_image" "$system_image"
echo "LineageOS 13 image validation: PASS"
