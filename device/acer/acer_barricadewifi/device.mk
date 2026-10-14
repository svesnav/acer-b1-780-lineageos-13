LOCAL_PATH := device/acer/acer_barricadewifi

PRODUCT_CHARACTERISTICS := tablet
PRODUCT_AAPT_CONFIG := normal large xhdpi
PRODUCT_AAPT_PREF_CONFIG := xhdpi
DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay
TARGET_SCREEN_WIDTH := 800
TARGET_SCREEN_HEIGHT := 1280

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.zygote=zygote64_32 \
    ro.mount.fs=EXT4 \
    ro.product.cpu.abilist=arm64-v8a,armeabi-v7a,armeabi \
    ro.product.cpu.abilist64=arm64-v8a \
    ro.product.cpu.abilist32=armeabi-v7a,armeabi \
    ro.adb.secure=0 \
    ro.secure=0 \
    ro.debuggable=1 \
    persist.sys.usb.config=mtp,adb

PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=213 \
    qemu.hw.mainkeys=0 \
    ro.radio.noril=true \
    ro.opengles.version=196608 \
    wifi.interface=wlan0 \
    wifi.tethering.interface=ap0 \
    wifi.direct.interface=p2p0 \
    persist.mtk.wcn.combo.chipid=-1 \
    camera.disable_zsl_mode=1 \
    ro.telephony.default_network=0 \
    persist.radio.multisim.config=ss \
    persist.gemini.sim_num=1 \
    dalvik.vm.isa.arm64.variant=cortex-a53 \
    dalvik.vm.isa.arm.variant=cortex-a53

PRODUCT_PACKAGES += \
    audio.a2dp.default \
    audio.r_submix.default \
    audio.usb.default \
    libion \
    libtinyalsa \
    libtinycompress \
    libtinyxml \
    charger_res_images \
    hostapd \
    libwpa_client \
    wpa_supplicant

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:system/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:system/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:system/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:system/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:system/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:system/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:system/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:system/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:system/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:system/etc/permissions/android.hardware.wifi.xml \
    $(LOCAL_PATH)/rootdir/fstab.mt8163:root/fstab.mt8163 \
    $(LOCAL_PATH)/configs/audio_policy.conf:system/etc/audio_policy.conf \
    $(LOCAL_PATH)/configs/media_codecs.xml:system/etc/media_codecs.xml \
    $(LOCAL_PATH)/configs/media_profiles.xml:system/etc/media_profiles.xml \
    $(LOCAL_PATH)/configs/wpa_supplicant.conf:system/etc/wifi/wpa_supplicant.conf \
    $(LOCAL_PATH)/configs/p2p_supplicant_overlay.conf:system/etc/wifi/p2p_supplicant_overlay.conf \
    $(LOCAL_PATH)/configs/wpa_supplicant_overlay.conf:system/etc/wifi/wpa_supplicant_overlay.conf

$(call inherit-product-if-exists, vendor/acer/acer_barricadewifi/acer_barricadewifi-vendor.mk)

