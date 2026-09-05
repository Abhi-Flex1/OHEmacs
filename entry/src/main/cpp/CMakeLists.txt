cmake_minimum_required(VERSION 3.4.1)
project(ohemacs)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include)

add_library(entry SHARED
    napi_init.cpp
    ohemacs_bridge.cpp
)

find_library(libace_napi libace_napi.z.so)
find_library(libhilog libhilog_ndk.z.so)
find_library(libace_ndk libace_ndk.z.so)
find_library(libuv libuv.so)

# NativeWindow / Drawing / VSync are linked by absolute SONAME to match sysroot layout.
target_link_libraries(entry PUBLIC
    ${libace_napi}
    ${libhilog}
    ${libace_ndk}
    ${libuv}
    libnative_window.so
    libnative_drawing.so
    libnative_vsync.so
    libEGL.so
    libGLESv3.so
)
