#!/usr/bin/env bash
set -eo pipefail

workspace="/mnt/c/Users/slava/Documents/Acer LineageOS"
tree="/home/slava/lineage-b1-780/cm13"
device_source="$workspace/porting/lineage13/device/acer/acer_barricadewifi"

rm -rf "$tree/device/acer/acer_barricadewifi"
mkdir -p "$tree/device/acer"
cp -a "$device_source" "$tree/device/acer/"
python3 "$workspace/porting/lineage13/apply-source-patches.py" "$tree"

export JAVA_HOME="/home/slava/acer-twrp/toolchains/jdk8"
export PATH="$JAVA_HOME/bin:/home/slava/acer-twrp/toolchains/python2/bin:$PATH"
cd "$tree"
source build/envsetup.sh >/dev/null
lunch cm_acer_barricadewifi-userdebug >/dev/null
# The existing output tree was initially seeded while the stock ramdisk was
# being analyzed. Force healthd and its parcel library to be rebuilt from the
# current CM sources so the BatteryProperties layout matches framework.jar.
rm -rf \
  "$tree/out/target/product/acer_barricadewifi/obj/EXECUTABLES/healthd_intermediates" \
  "$tree/out/target/product/acer_barricadewifi/obj/STATIC_LIBRARIES/libbatteryservice_intermediates"
rm -f "$tree/out/target/product/acer_barricadewifi/root/sbin/healthd"
make -j4 libmedia Bluetooth framework-res healthd
