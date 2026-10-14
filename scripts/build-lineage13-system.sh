#!/usr/bin/env bash
set -eo pipefail

workspace="/mnt/c/Users/slava/Documents/Acer LineageOS"
tree="/home/slava/lineage-b1-780/cm13"
product="$tree/out/target/product/acer_barricadewifi"
base_system="$product/system"
work="/home/slava/lineage-b1-780/lineage13-system"
mountpoint="/home/slava/lineage-b1-780/stock-system"
stock_image="$workspace/backups/B1-780_20261011_225934/firmware-after-unlock/system.img"
output="$workspace/builds/lineage-13.0-b1-780-system.img"
sparse="$workspace/builds/lineage-13.0-b1-780-system-sparse.img"
overlay="$workspace/porting/lineage13/overlay-stock-blobs.py"
stock_ramdisk="/home/slava/acer-twrp/stock-boot-ramdisk"
make_ext4fs="$tree/out/host/linux-x86/bin/make_ext4fs"
img2simg="$tree/out/host/linux-x86/bin/img2simg"

if [ "$(id -u)" -ne 0 ]; then
  echo "run this script as root" >&2
  exit 1
fi
if [ ! -d "$base_system/framework" ]; then
  echo "Lineage system tree is missing: $base_system" >&2
  exit 1
fi

mkdir -p "$mountpoint"
mounted=0
cleanup() {
  if [ "$mounted" = 1 ]; then
    umount "$mountpoint" || true
  fi
}
trap cleanup EXIT
if ! mountpoint -q "$mountpoint"; then
  mount -o loop,ro "$stock_image" "$mountpoint"
  mounted=1
fi

rm -rf "$work"
mkdir -p "$work"
cp -a "$base_system/." "$work/"
python3 "$overlay" "$mountpoint" "$work" --stock-ramdisk "$stock_ramdisk"

# The Acer camera HAL exposes two Camera1 devices but the stock firmware keeps
# its camcorder profiles outside the system image. Lineage Camera2 requires
# explicit profiles for both IDs before it will initialize either camera.
cp "$workspace/porting/lineage13/device/acer/acer_barricadewifi/configs/media_profiles.xml" \
  "$work/etc/media_profiles.xml"

# Never let the ROM overwrite the persistent TWRP partition.
rm -f "$work/recovery-from-boot.p" "$work/bin/install-recovery.sh"

# Replace build-generated ABI lists atomically; the generic CM product emits a
# 32-bit-only list even for this dual-ABI device.
sed -i \
  -e '/^ro\.product\.cpu\.abilist=/d' \
  -e '/^ro\.product\.cpu\.abilist64=/d' \
  -e '/^ro\.product\.cpu\.abilist32=/d' \
  "$work/build.prop"

cat >> "$work/build.prop" <<'EOF'
ro.lineage.device=acer_barricadewifi
ro.lineage.model=B1-780
ro.lineage.port.version=13.0-b1-780-v1
ro.setupwizard.mode=OPTIONAL
persist.sys.usb.config=mtp,adb
qemu.hw.mainkeys=0
ro.radio.noril=true
ro.product.cpu.abilist=arm64-v8a,armeabi-v7a,armeabi
ro.product.cpu.abilist64=arm64-v8a
ro.product.cpu.abilist32=armeabi-v7a,armeabi
EOF

# This Wi-Fi-only B1-780 variant has no modem or SIM slot.  CM's common
# product installs this optional feature declaration even when noril is set,
# which makes Settings expose SIM information.
rm -f "$work/etc/permissions/org.cyanogenmod.telephony.xml"

rm -f "$output" "$sparse"
"$make_ext4fs" \
  -T 0 \
  -S "$stock_ramdisk/file_contexts" \
  -L system \
  -l 3758096384 \
  -a system \
  "$output" \
  "$work"

# Android 6's make_ext4fs leaves unused inode-bitmap padding clear.  Current
# e2fsck treats that as an error, so normalize it once and then perform a
# read-only verification pass.
set +e
e2fsck -fy "$output"
fsck_status=$?
set -e
if [ "$fsck_status" -gt 1 ]; then
  echo "e2fsck repair failed with status $fsck_status" >&2
  exit "$fsck_status"
fi
e2fsck -fn "$output"
if [ -x "$img2simg" ]; then
  "$img2simg" "$output" "$sparse"
  sha256sum "$output" "$sparse"
else
  echo "img2simg was not built; retaining the validated raw image"
  sha256sum "$output"
fi
du -sh "$work"
ls -lh "$output"
[ ! -e "$sparse" ] || ls -lh "$sparse"

