$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, vendor/cm/config/common_full_tablet_wifionly.mk)
$(call inherit-product, device/acer/acer_barricadewifi/device.mk)

PRODUCT_NAME := cm_acer_barricadewifi
PRODUCT_DEVICE := acer_barricadewifi
PRODUCT_BRAND := Acer
PRODUCT_MODEL := B1-780
PRODUCT_MANUFACTURER := Acer

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=b1-780_ww_gen1 \
    BUILD_FINGERPRINT=acer/b1-780_ww_gen1/acer_barricadewifi:6.0/MRA58K/1495071958:user/release-keys \
    PRIVATE_BUILD_DESC="full_neostra8163_tb_m-user 6.0 MRA58K 1495071958 release-keys"

