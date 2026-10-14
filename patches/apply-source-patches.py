#!/usr/bin/env python3
from pathlib import Path
import shutil
import sys


root = Path(sys.argv[1] if len(sys.argv) > 1 else "/home/slava/lineage-b1-780/cm13")
here = Path(__file__).resolve().parent


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if new in text:
        return
    if text.count(old) != 1:
        raise SystemExit(f"unexpected source in {path}: wanted one match")
    path.write_text(text.replace(old, new, 1))


# Add only the missing MediaTek voice-unlock symbols to Lineage libmedia.
compat = root / "frameworks/av/media/libmedia/mtk_audio_compat.cpp"
shutil.copyfile(here / "source-patches/mtk_audio_compat.cpp", compat)
media_mk = root / "frameworks/av/media/libmedia/Android.mk"
replace_once(
    media_mk,
    "    AudioPolicy.cpp\n",
    "    AudioPolicy.cpp \\\n+    mtk_audio_compat.cpp\n",
)

# CM 13 inserted optional Qualcomm extensions in the middle of bt_interface_t.
# Acer's Android 6 HAL follows the AOSP layout, so all pointers after cleanup
# were shifted. Move the optional fields to the end to preserve the AOSP ABI.
bt_header = root / "hardware/libhardware/include/hardware/bluetooth.h"
text = bt_header.read_text()
blocks = [
    "    /** SSR cleanup. */\n    void (*ssrcleanup)(void);\n\n",
    "    /* Send any test HCI command to the controller. */\n"
    "    int (*hci_cmd_send)(uint16_t opcode, uint8_t *buf, uint8_t len);\n\n",
    "    /** BT stack Test interface */\n"
    "    const void* (*get_testapp_interface)(int test_app_profile);\n\n",
]
marker = "    /* Acer/MTK ABI compatibility: optional CM fields follow the AOSP interface. */"
if marker not in text:
    for block in blocks:
        if text.count(block) != 1:
            raise SystemExit(f"unexpected Bluetooth header block: {block.splitlines()[0]}")
        text = text.replace(block, "", 1)
    addition = """    /* Acer/MTK ABI compatibility: optional CM fields follow the AOSP interface. */
    void (*ssrcleanup)(void);
    int (*hci_cmd_send)(uint16_t opcode, uint8_t *buf, uint8_t len);
    const void* (*get_testapp_interface)(int test_app_profile);
"""
    text = text.replace("} bt_interface_t;", addition + "} bt_interface_t;", 1)
    bt_header.write_text(text)

# Do not dereference an optional field beyond Acer's shorter AOSP structure.
adapter = root / "packages/apps/Bluetooth/jni/com_android_bluetooth_btservice_AdapterService.cpp"
replace_once(
    adapter,
    """    sBluetoothInterface->ssrcleanup();
    ALOGI("%s: return from cleanup",__FUNCTION__);
""",
    """    if (sBluetoothInterface->size >= sizeof(bt_interface_t) &&
            sBluetoothInterface->ssrcleanup != NULL) {
        sBluetoothInterface->ssrcleanup();
    } else if (cleanup == JNI_TRUE) {
        sBluetoothInterface->cleanup();
    }
    ALOGI("%s: return from cleanup",__FUNCTION__);
""",
)

# Acer's MediaTek AVRCP target interface is 64 bytes while CM 13 extended the
# same structure to 80 bytes.  cleanup is the final entry in both ABIs, so use
# the size reported by the vendor interface to find it instead of reading CM's
# fixed offset (which otherwise jumps into read-only data and raises SIGILL).
avrcp = root / "packages/apps/Bluetooth/jni/com_android_bluetooth_avrcp.cpp"
replace_once(
    avrcp,
    """static const btrc_interface_t *sBluetoothMultiAvrcpInterface = NULL;
static jobject mCallbacksObj = NULL;
""",
    """static const btrc_interface_t *sBluetoothMultiAvrcpInterface = NULL;
static jobject mCallbacksObj = NULL;

static void cleanupAvrcpInterface() {
    if (sBluetoothMultiAvrcpInterface == NULL) return;

    const size_t vendorSize = sBluetoothMultiAvrcpInterface->size;
    void (*cleanup)(void) = NULL;
    if (vendorSize >= sizeof(size_t) + sizeof(cleanup) &&
            vendorSize < sizeof(btrc_interface_t)) {
        memcpy(&cleanup,
               reinterpret_cast<const uint8_t *>(sBluetoothMultiAvrcpInterface) +
                       vendorSize - sizeof(cleanup),
               sizeof(cleanup));
        ALOGI("Using vendor AVRCP cleanup at end of %zu-byte interface", vendorSize);
    } else if (vendorSize >= sizeof(btrc_interface_t)) {
        cleanup = sBluetoothMultiAvrcpInterface->cleanup;
    } else {
        ALOGE("Invalid AVRCP interface size: %zu", vendorSize);
    }

    if (cleanup != NULL) cleanup();
}
""",
)
replace_once(
    avrcp,
    """         sBluetoothMultiAvrcpInterface->cleanup();
         sBluetoothMultiAvrcpInterface = NULL;
""",
    """         cleanupAvrcpInterface();
         sBluetoothMultiAvrcpInterface = NULL;
""",
)
replace_once(
    avrcp,
    """        sBluetoothMultiAvrcpInterface->cleanup();
        sBluetoothMultiAvrcpInterface = NULL;
""",
    """        cleanupAvrcpInterface();
        sBluetoothMultiAvrcpInterface = NULL;
""",
)

print("Lineage 13 MTK source patches applied")
