#include "napi/native_api.h"
#include "ohemacs_bridge.h"

#include <ace/xcomponent/native_interface_xcomponent.h>
#include <hilog/log.h>

#include <cstring>
#include <string>

#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0201
#undef LOG_TAG
#define LOG_TAG "OHEmacs"

extern "C" void OhemacsRegisterCallbacks(OH_NativeXComponent *component);

namespace {

napi_value MakeString(napi_env env, const std::string &s) {
    napi_value v = nullptr;
    napi_create_string_utf8(env, s.c_str(), s.size(), &v);
    return v;
}

std::string GetString(napi_env env, napi_value v) {
    size_t len = 0;
    napi_get_value_string_utf8(env, v, nullptr, 0, &len);
    std::string s(len, '\0');
    size_t written = 0;
    napi_get_value_string_utf8(env, v, len ? &s[0] : nullptr, len + 1, &written);
    s.resize(written);
    return s;
}

napi_value Hello(napi_env env, napi_callback_info) {
    return MakeString(env, "Hello OHEmacs (NAPI) — Emacs 30.1 OpenHarmony GUI scaffold");
}

napi_value Add(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    int64_t a = 0, b = 0;
    if (argc > 0) {
        napi_get_value_int64(env, argv[0], &a);
    }
    if (argc > 1) {
        napi_get_value_int64(env, argv[1], &b);
    }
    napi_value out = nullptr;
    napi_create_int64(env, a + b, &out);
    return out;
}

napi_value GetEmacsVersion(napi_env env, napi_callback_info) {
    return MakeString(env, std::string("GNU Emacs ") + OHEMACS_UPSTREAM_VERSION +
                               " (OHEmacs port " + OHEMACS_PORT_VERSION + ")");
}

napi_value InitEmacs(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    std::string files = argc > 0 ? GetString(env, argv[0]) : "/data/storage/el2/base/files";
    std::string cache = argc > 1 ? GetString(env, argv[1]) : "/data/storage/el2/base/cache";
    std::string status = OhemacsInit(files, cache);
    return MakeString(env, status);
}

napi_value SendKey(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    int64_t code = 0, action = 0;
    if (argc > 0) {
        napi_get_value_int64(env, argv[0], &code);
    }
    if (argc > 1) {
        napi_get_value_int64(env, argv[1], &action);
    }
    OhemacsSendKey((int32_t)code, (int32_t)action);
    napi_value und = nullptr;
    napi_get_undefined(env, &und);
    return und;
}

napi_value SendExpose(napi_env env, napi_callback_info) {
    OhemacsSendExpose();
    napi_value und = nullptr;
    napi_get_undefined(env, &und);
    return und;
}

// testXComponent(id: string): resolve the XComponent instance passed as
// __NATIVE_XCOMPONENT_OBJ__ and register surface callbacks.
// ArkTS must have <XComponent id=... libraryname='entry'> for this to work.
napi_value TestXComponent(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    napi_value exports = nullptr;
    // The NAPI exports object holds the native XComponent under a magic key.
    // We recover it via the current module's exports is unreliable here, so
    // instead unwrap from global: caller passes id, we look up via
    // napi_get_named_property on `this`? Simplest robust path used by official
    // samples: get property OH_NATIVE_XCOMPONENT_OBJ from the callback's
    // `this`. Fall back to logging if unavailable (UI still works).
    napi_value thisVar = nullptr;
    napi_get_cb_info(env, info, nullptr, nullptr, &thisVar, nullptr);

    OH_NativeXComponent *nativeXComp = nullptr;
    napi_value obj = nullptr;
    bool got = false;
    if (thisVar != nullptr &&
        napi_get_named_property(env, thisVar, OH_NATIVE_XCOMPONENT_OBJ, &obj) == napi_ok &&
        obj != nullptr) {
        if (napi_unwrap(env, obj, (void **)&nativeXComp) == napi_ok && nativeXComp != nullptr) {
            got = true;
        }
    }
    // Fallback: try exports of this module via global `require`? Skip — log.
    if (got) {
        OhemacsRegisterCallbacks(nativeXComp);
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "testXComponent: callbacks registered");
    } else {
        // Still return success; OnSurfaceCreated will be delivered via the
        // auto-registration path when ArkTS uses libraryname='entry' and the
        // runtime loads this .so for the XComponent id.
        OH_LOG_Print(LOG_APP, LOG_WARN, LOG_DOMAIN, LOG_TAG,
                     "testXComponent: no XComponent obj on `this`; relying on auto-load path");
        // Attempt direct lookup: the XComponent runtime calls Init() with
        // exports containing OH_NATIVE_XCOMPONENT_OBJ only when libraryname
        // matches. That path is handled in Init() below.
    }
    (void)exports;
    napi_value und = nullptr;
    napi_get_undefined(env, &und);
    return und;
}

napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"hello", nullptr, Hello, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"add", nullptr, Add, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getEmacsVersion", nullptr, GetEmacsVersion, nullptr, nullptr, nullptr, napi_default,
         nullptr},
        {"initEmacs", nullptr, InitEmacs, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sendKey", nullptr, SendKey, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sendExpose", nullptr, SendExpose, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"testXComponent", nullptr, TestXComponent, nullptr, nullptr, nullptr, napi_default,
         nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);

    // Auto-registration path: when this .so is loaded as XComponent libraryname,
    // exports contains OH_NATIVE_XCOMPONENT_OBJ. Register immediately.
    napi_value obj = nullptr;
    if (napi_get_named_property(env, exports, OH_NATIVE_XCOMPONENT_OBJ, &obj) == napi_ok &&
        obj != nullptr) {
        OH_NativeXComponent *comp = nullptr;
        if (napi_unwrap(env, obj, (void **)&comp) == napi_ok && comp != nullptr) {
            OhemacsRegisterCallbacks(comp);
            OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                         "Init: XComponent auto-registered");
        }
    }
    return exports;
}

} // namespace

static napi_module g_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = nullptr,
    .reserved = {nullptr},
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) {
    napi_module_register(&g_module);
}
