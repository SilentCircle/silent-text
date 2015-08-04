LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_ARM_MODE := arm
LOCAL_MODULE   := sccrypto-jni
LOCAL_CFLAGS   := -DANDROID
LOCAL_LDLIBS   := -llog

LOCAL_SHARED_LIBRARIES := \
  sccrypto

LOCAL_C_INCLUDES += \
  $(LOCAL_PATH)

LOCAL_SRC_FILES  := \
  base64.c \
  com/silentcircle/scimp/NativeKeyGenerator/generateKey.c \
  com/silentcircle/scimp/NativeKeyGenerator/getPublicKey.c \
  com/silentcircle/scimp/NativePacket/scimp_jni.c \
  com/silentcircle/scimp/NativePacket/connect.c \
  com/silentcircle/scimp/NativePacket/onCreate.c \
  com/silentcircle/scimp/NativePacket/onDestroy.c \
  com/silentcircle/scimp/NativePacket/receivePacket.c \
  com/silentcircle/scimp/NativePacket/receivePacketPKI.c \
  com/silentcircle/scimp/NativePacket/resetStorageKey.c \
  com/silentcircle/scimp/NativePacket/sendPacket.c \
  com/silentcircle/scimp/NativePacket/sendPacketPKI.c \
  com/silentcircle/scloud/NativePacket/decrypt.c \
  com/silentcircle/scloud/NativePacket/encrypt.c \
  com/silentcircle/scloud/NativePacket/onCreate.c \
  com/silentcircle/scloud/NativePacket/onDestroy.c \
  jni.c \
  scimp_keys.c \
  scimp_packet.c \
  scloud_decrypt_packet.c \
  scloud_decrypt_parameters.c \
  scloud_encrypt_packet.c \
  scloud_encrypt_parameters.c \
  scimp_tests.c \
  uint8_t_array.c

include $(BUILD_SHARED_LIBRARY)
