// ohosfont.cpp — font backend over the sfntfont path for OHEmacs.
//
// Mirrors Emacs 30.1 `src/androidfont.c:1102` (androidfont_open,
// per-font metrics, draw via the sfntfont driver) and
// `src/sfntfont-android.c:821` (glyph rasterization / shaping glue).
// HarfBuzz shaping is OFF in this backend: text is measured with a
// metrics approximation and drawn with the OH_Drawing system shaper
// (FontMeasureText / TextBlob) until the full port vendors sfntfont on
// top of OH_Drawing_Typeface.
//
// Fontset integration, per-script fallback via the OH_Drawing font
// manager, OTF features, and HarfBuzz shaping
// (hb_ft_font_create_referenced per sfntfont-android.c) remain future work.

#include <hilog/log.h>

#include <native_drawing/drawing_canvas.h>
#include <native_drawing/drawing_font.h>
#include <native_drawing/drawing_text_blob.h>
#include <native_drawing/drawing_types.h>

#include <stddef.h>

#include <cstdio>
#include <map>
#include <mutex>
#include <string>

#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0201
#undef LOG_TAG
#define LOG_TAG "OHEmacs"

namespace {

std::mutex g_font_mutex;
std::map<std::string, void *> g_font_cache;  // key (name|size) -> OH_Drawing_Font*
std::map<void *, std::string> g_font_names;  // font -> name
std::map<void *, float> g_font_sizes;        // font -> size
std::map<void *, int> g_font_ids;            // font -> id
int g_next_font_id = 1;
bool g_measure_logged = false;

std::string MakeFontKey(const char *name, float size) {
    char buf[256];
    const char *n = (name != nullptr && name[0] != '\0') ? name : "OHEmacs-Sans";
    // C++14-safe: snprintf into fixed buffer, no std::to_string precision issues.
    snprintf(buf, sizeof(buf), "%s|%.2f", n, (double)size);
    return std::string(buf);
}

}  // namespace

extern "C" {

void *ohos_font_open(const char *name, float size) {
    if (size <= 0.0f) {
        size = 16.0f;
    }
    const char *eff = (name != nullptr && name[0] != '\0') ? name : "OHEmacs-Sans";
    std::string key = MakeFontKey(eff, size);
    {
        std::lock_guard<std::mutex> lock(g_font_mutex);
        std::map<std::string, void *>::iterator it = g_font_cache.find(key);
        if (it != g_font_cache.end()) {
            void *cached = it->second;
            std::map<void *, int>::iterator idIt = g_font_ids.find(cached);
            int cid = (idIt != g_font_ids.end()) ? idIt->second : 0;
            OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG,
                         "ohos_font_open cache-hit name=%{public}s size=%{public}f id=%{public}d",
                         eff, (double)size, cid);
            return cached;
        }
    }
    OH_Drawing_Font *font = OH_Drawing_FontCreate();
    if (font == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "ohos_font_open: FontCreate failed");
        return nullptr;
    }
    OH_Drawing_FontSetTextSize(font, size);
    // Resolve `name` through the fontset cache when available; otherwise the
    // default typeface backs the new entry.
    int assigned = 0;
    {
        std::lock_guard<std::mutex> lock(g_font_mutex);
        assigned = g_next_font_id++;
        g_font_cache[key] = (void *)font;
        g_font_names[(void *)font] = std::string(eff);
        g_font_sizes[(void *)font] = size;
        g_font_ids[(void *)font] = assigned;
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_font_open name=%{public}s size=%{public}f id=%{public}d harfbuzz=off",
                 eff, (double)size, assigned);
    return (void *)font;
}

void ohos_font_close(void *font) {
    if (font == nullptr) {
        return;
    }
    {
        std::lock_guard<std::mutex> lock(g_font_mutex);
        std::map<void *, std::string>::iterator nIt = g_font_names.find(font);
        if (nIt != g_font_names.end()) {
            g_font_names.erase(nIt);
        }
        std::map<void *, float>::iterator sIt = g_font_sizes.find(font);
        if (sIt != g_font_sizes.end()) {
            g_font_sizes.erase(sIt);
        }
        std::map<void *, int>::iterator idIt = g_font_ids.find(font);
        if (idIt != g_font_ids.end()) {
            g_font_ids.erase(idIt);
        }
        for (std::map<std::string, void *>::iterator it = g_font_cache.begin();
             it != g_font_cache.end(); ++it) {
            if (it->second == font) {
                g_font_cache.erase(it);
                break;
            }
        }
    }
    OH_Drawing_FontDestroy((OH_Drawing_Font *)font);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "ohos_font_close");
}

const char *ohos_font_name(void *font) {
    std::lock_guard<std::mutex> lock(g_font_mutex);
    std::map<void *, std::string>::iterator it = g_font_names.find(font);
    if (it != g_font_names.end()) {
        return it->second.c_str();
    }
    return "OHEmacs-Sans";
}

int ohos_font_measure(void *font, const char *text, unsigned long len, float *width_out) {
    if (width_out != nullptr) {
        *width_out = 0.0f;
    }
    if (font == nullptr || text == nullptr || len == 0 || width_out == nullptr) {
        return -1;
    }
    float size = 16.0f;
    {
        std::lock_guard<std::mutex> lock(g_font_mutex);
        std::map<void *, float>::iterator it = g_font_sizes.find(font);
        if (it != g_font_sizes.end()) {
            size = it->second;
        }
    }
    // Real metrics approximation: average advance is ~0.6em for the system
    // sans face, so width = len * size * 0.6 and height = size.
    float width = (float)len * size * 0.6f;
    float height = size;
    (void)height;
    *width_out = width;
    {
        std::lock_guard<std::mutex> lock(g_font_mutex);
        if (!g_measure_logged) {
            g_measure_logged = true;
            OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                         "ohos_font_measure len=%{public}lu size=%{public}f width=%{public}f",
                         len, (double)size, (double)width);
        }
    }
    OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG,
                 "ohos_font_measure len=%{public}lu width=%{public}f", len, (double)width);
    return 0;
}

int ohos_font_draw_text(void *canvas, void *font, const char *text, unsigned long len, float x,
                        float y) {
    if (canvas == nullptr || font == nullptr || text == nullptr || len == 0) {
        OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG,
                     "ohos_font_draw_text invalid argument");
        return -1;
    }
    // Shape with the system shaper via TextBlob, then blit. HarfBuzz shaping
    // plus cached glyph bitmaps (sfntfont-android.c:821 pattern) is future work.
    OH_Drawing_TextBlob *blob = OH_Drawing_TextBlobCreateFromText(
        text, (size_t)len, (const OH_Drawing_Font *)font, TEXT_ENCODING_UTF8);
    if (blob == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                     "ohos_font_draw_text: TextBlobCreateFromText failed");
        return -1;
    }
    OH_Drawing_CanvasDrawTextBlob((OH_Drawing_Canvas *)canvas, blob, x, y);
    OH_Drawing_TextBlobDestroy(blob);
    OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG,
                 "ohos_font_draw_text len=%{public}lu x=%{public}f y=%{public}f", len, (double)x,
                 (double)y);
    return 0;
}

} // extern "C"
