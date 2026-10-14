#!/usr/bin/env bash
set -eo pipefail

export JAVA_HOME="$HOME/acer-twrp/toolchains/jdk8"
export PATH="$JAVA_HOME/bin:$PATH"

workspace="/mnt/c/Users/slava/Documents/Acer LineageOS"
source_ramdisk="$workspace/porting/boot-ramdisk.bin"
work="$HOME/lineage-b1-780/lineage13-boot-ramdisk"
raw="$HOME/lineage-b1-780/lineage13-boot-ramdisk.img"
raw_mtk="$HOME/lineage-b1-780/lineage13-boot-ramdisk-mtk.img"
unsigned="$workspace/builds/lineage-13.0-b1-780-boot-unsigned.img"
signed="$workspace/builds/lineage-13.0-b1-780-boot.img"
mkbootimg="$HOME/acer-twrp/src/out/host/linux-x86/bin/mtkbootimg"
bootsigner="$HOME/acer-twrp/src/out/host/linux-x86/framework/BootSignature.jar"
keys="$HOME/acer-twrp/src/build/target/product/security"

rm -rf "$work"
mkdir -p "$work"
(
  cd "$work"
  dd if="$source_ramdisk" bs=512 skip=1 status=none | gzip -dc | \
    cpio -idm --no-absolute-filenames 2>/dev/null
)

# Acer's healthd uses a MediaTek-extended BatteryProperties parcel layout.
# Lineage's BatteryService expects the standard Android 6 layout; mixing the
# two shifts every field. Use the healthd built with Lineage.
lineage_healthd="$HOME/lineage-b1-780/cm13/out/target/product/acer_barricadewifi/root/sbin/healthd"
test -f "$lineage_healthd"
cp "$lineage_healthd" "$work/sbin/healthd"
chmod 0750 "$work/sbin/healthd"

# Custom system images cannot pass Acer's stock dm-verity tree.
sed -i 's/ wait,verify$/ wait/' "$work/fstab.mt8163"
grep -q 'by-name/system /system ext4 ro wait$' "$work/fstab.mt8163"

# Acer forces userdata encryption during the first boot.  The proprietary
# keymaster stack cannot provision that volume before the port has completed
# framework startup, so keep userdata unencrypted for this initial ROM.
sed -i \
  's# wait,check,resize,forceencrypt=[^,]*,# wait,check,resize#' \
  "$work/fstab.mt8163"
if grep -q 'forceencrypt=' "$work/fstab.mt8163"; then
  echo "failed to remove forced userdata encryption" >&2
  exit 1
fi

# Keep Acer's low-level init scripts, but use CM 13's framework class paths.
# Its system services depend on the CyanogenMod platform and hardware jars.
python3 - "$work/init.environ.rc" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
s = p.read_text()
s = re.sub(
    r"(?m)^\s*export BOOTCLASSPATH .*$",
    "    export BOOTCLASSPATH "
    "/system/framework/core-libart.jar:/system/framework/conscrypt.jar:"
    "/system/framework/okhttp.jar:/system/framework/core-junit.jar:"
    "/system/framework/bouncycastle.jar:/system/framework/ext.jar:"
    "/system/framework/framework.jar:/system/framework/telephony-common.jar:"
    "/system/framework/voip-common.jar:/system/framework/ims-common.jar:"
    "/system/framework/apache-xml.jar:"
    "/system/framework/org.apache.http.legacy.boot.jar",
    s,
)
s = re.sub(
    r"(?m)^\s*export SYSTEMSERVERCLASSPATH .*$",
    "    export SYSTEMSERVERCLASSPATH "
    "/system/framework/org.cyanogenmod.platform.jar:"
    "/system/framework/org.cyanogenmod.hardware.jar:"
    "/system/framework/services.jar:"
    "/system/framework/ethernet-service.jar:"
    "/system/framework/wifi-service.jar",
    s,
)
p.write_text(s)
PY

# Preserve TWRP when Android starts.
python3 - "$work/init.rc" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()
old = "service flash_recovery /system/bin/install-recovery.sh\n    class main\n    oneshot"
new = "service flash_recovery /system/bin/install-recovery.sh\n    class main\n    disabled\n    oneshot"
if s.count(old) != 1:
    raise SystemExit("unexpected flash_recovery service definition")
p.write_text(s.replace(old, new, 1))
PY

# Drive the two-color charge LED from the kernel power-supply triggers.  The
# MTK lights HAL makes one late write after sys.boot_completed and can clear
# the red trigger, so install the triggers after that startup write settles.
cat > "$work/sbin/charge-led-late.sh" <<'EOF'
#!/sbin/sh
sleep 12
echo none > /sys/class/leds/red/trigger
echo none > /sys/class/leds/green/trigger
was_online=0
while true; do
    online="$(cat /sys/class/power_supply/usb/online)"
    if [ "$online" = "1" ]; then
        status="$(cat /sys/class/power_supply/battery/status)"
        level="$(cat /sys/class/power_supply/battery/capacity)"
        if [ "$status" = "Full" ] || [ "$level" -ge 100 ]; then
            echo 0 > /sys/class/leds/red/brightness
            echo 255 > /sys/class/leds/green/brightness
        else
            echo 0 > /sys/class/leds/green/brightness
            echo 255 > /sys/class/leds/red/brightness
        fi
    elif [ "$was_online" = "1" ]; then
        echo 0 > /sys/class/leds/red/brightness
        echo 0 > /sys/class/leds/green/brightness
    fi
    was_online="$online"
    sleep 5
done
EOF
chmod 0750 "$work/sbin/charge-led-late.sh"

cat >> "$work/init.mt8163.rc" <<'EOF'

service charge_led_late /system/bin/sh /sbin/charge-led-late.sh
    class late_start
    user root
    group root
    disabled

on property:sys.boot_completed=1
    start charge_led_late
EOF

# Keep this first boot image debuggable and permissive so proprietary MTK
# Android 6 daemons can run while the device policy is being brought up.
sed -i \
  -e 's/^ro\.secure=.*/ro.secure=0/' \
  -e 's/^ro\.adb\.secure=.*/ro.adb.secure=0/' \
  -e 's/^ro\.debuggable=.*/ro.debuggable=1/' \
  -e 's/^persist\.sys\.usb\.config=.*/persist.sys.usb.config=mtp,adb/' \
  "$work/default.prop"

python3 - "$work/init" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
b = bytearray(p.read_bytes())
offset = 0x79dc
old = bytes.fromhex("e0030032")
new = bytes.fromhex("e0031f2a")
if b[offset:offset + 4] != old:
    raise SystemExit(
        f"unexpected init instruction at {offset:#x}: "
        f"{b[offset:offset + 4].hex()}"
    )
b[offset:offset + 4] = new
p.write_bytes(b)
PY

(
  cd "$work"
  find . -print0 | cpio --null -o -H newc --owner 0:0 2>/dev/null | \
    gzip -n -9 > "$raw"
)

python3 - "$raw" "$raw_mtk" <<'PY'
import struct
import sys
from pathlib import Path

payload = Path(sys.argv[1]).read_bytes()
header = b'\x88\x16\x88\x58' + struct.pack('<I', len(payload))
header += b'ROOTFS'.ljust(32, b'\0')
header = header.ljust(512, b'\xff')
Path(sys.argv[2]).write_bytes(header + payload)
PY

"$mkbootimg" \
  --kernel "$workspace/porting/boot-kernel.bin" \
  --ramdisk "$raw_mtk" \
  --cmdline 'bootopt=64S3,32N2,64N2 androidboot.selinux=permissive' \
  --base 0x40078000 \
  --pagesize 2048 \
  --ramdisk_offset 0x03f88000 \
  --second_offset 0x00e88000 \
  --tags_offset 0x0df88000 \
  --board 1495071958 \
  --mtk 1 \
  --output "$unsigned"

java -jar "$bootsigner" /boot "$unsigned" \
  "$keys/testkey.pk8" "$keys/testkey.x509.pem" "$signed"
java -jar "$bootsigner" -verify "$signed"
sha256sum "$signed"
ls -l "$signed"

