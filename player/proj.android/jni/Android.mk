LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

$(call import-add-path,$(LOCAL_PATH)/../../../)
$(call import-add-path,$(LOCAL_PATH)/../../../external)
$(call import-add-path,$(LOCAL_PATH)/../../../cocos)

LOCAL_MODULE := cocos2dcpp_shared

LOCAL_MODULE_FILENAME := libcocos2dcpp

LOCAL_SRC_FILES := hellocpp/main.cpp \
                   ../../Classes/AppDelegate.cpp \
                   ../../Classes/ProjectConfig/ProjectConfig.cpp \
                   ../../Classes/ProjectConfig/SimulatorConfig.cpp \
                   ../../Classes/HelloWorldScene.cpp \
                   ../../Classes/BunnyMarkScene.cpp \
                   ../../Classes/MainScene.cpp

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../../Classes

# LOCAL_SRC_FILES += hello.cpp
# _COCOS_HEADER_ANDROID_BEGIN
# _COCOS_HEADER_ANDROID_END


LOCAL_STATIC_LIBRARIES := cocos2dx_static
LOCAL_STATIC_LIBRARIES += cocos2d_lua_static

# _COCOS_LIB_ANDROID_BEGIN
# _COCOS_LIB_ANDROID_END

include $(BUILD_SHARED_LIBRARY)

$(call import-module,scripting/lua-bindings/proj.android)
$(call import-module,.)

# _COCOS_LIB_IMPORT_ANDROID_BEGIN
# _COCOS_LIB_IMPORT_ANDROID_END
