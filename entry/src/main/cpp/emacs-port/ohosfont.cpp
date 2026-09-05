// ohosfont.cpp — font backend stub over the sfntfont path for OHEmacs.
//
// Stage 2. Mirrors Emacs 30.1 `src/androidfont.c:1102` (androidfont_open,
// per-font metrics, draw via the sfntfont driver) and
// `src/sfntfont-android.c:821` (glyph rasterization / shaping glue).
// HarfBuzz shaping is OFF in this stub: text is measured and drawn with
// the OH_Drawing system shaper (FontMeasureText / TextBlob) until the full
// port vendors sfntfont on top of OH_Drawing_Typeface.
//
// TODO(full port): fontset.c integration, per-script fallback via the
// OH_Drawing font manager, OTF features, and HarfBuzz shaping
// (hb_ft_font_create_referenced per sfntfont-android.c).

#include <hilog/log.h>

#include <native_drawing/drawing_canvas.h>
#include <native_drawing/drawing_font.h>
#include <native_drawing/drawing_text_blob.h>
#include <native_drawing/drawing_types.h>

#include <stddef.h>

#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0201
#undef LOG_TAG
#define LOG_TAG "OHEmacs"

extern "C" {

void *ohos_font_open(const char *name, float size) {
    if (size <= 0.0f) {
        size = 16.0f;
    }
    OH_Drawing_Font *font = OH_Drawing_FontCreate();
    if (font == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "ohos_font_open: FontCreate failed");
        return nullptr;
    }
    OH_Drawing_FontSetTextSize(font, size);
    // TODO(androidfont.c:1102): resolve `name` through the fontset cache
    // and OH_Drawing_CreateTypeface instead of the default typeface.
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
                 "ohos_font_open name=%{public}s size=%{public}f harfbuzz=off",
                 name != nullptr ? name : "(default)", (double)size);
    return (void *)font;
}

void ohos_font_close(void *font) {
    if (font == nullptr) {
        return;
    }
    OH_Drawing_FontDestroy((OH_Drawing_Font *)font);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "ohos_font_close");
}

const char *ohos_font_name(void *font) {
    // TODO: return the fontset entry name backing `font`.
    (void)font;
    return "OHEmacs-Stub-Sans";
}

int ohos_font_measure(void *font, const char *text, unsigned long len, float *width_out) {
    if (width_out != nullptr) {
        *width_out = 0.0f;
    }
    if (font == nullptr || text == nullptr || len == 0 || width_out == nullptr) {
        return -1;
    }
    float width = 0.0f;
    OH_Drawing_ErrorCode rc = OH_Drawing_FontMeasureText((const OH_Drawing_Font *)font, text,
                                                        (size_t)len, TEXT_ENCODING_UTF8,
                                                        nullptr, &width);
    if (rc != OH_DRAWING_SUCCESS) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                     "ohos_font_measure: FontMeasureText failed %{public}d", (int)rc);
        return -1;
    }
    *width_out = width;
    return 0;
}

int ohos_font_draw_text(void *canvas, void *font, const char *text, unsigned long len, float x,
                        float y) {
    if (canvas == nullptr || font == nullptr || text == nullptr || len == 0) {
        return -1;
    }
    // TODO(sfntfont-android.c:821): shape with HarfBuzz, then blit cached
    // glyph bitmaps; the TextBlob path below uses the system shaper.
    OH_Drawing_TextBlob *blob = OH_Drawing_TextBlobCreateFromText(
        text, (size_t)len, (const OH_Drawing_Font *)font, TEXT_ENCODING_UTF8);
    if (blob == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                     "ohos_font_draw_text: TextBlobCreateFromText failed");
        return -1;
    }
    OH_Drawing_CanvasDrawTextBlob((OH_Drawing_Canvas *)canvas, blob, x, y);
    OH_Drawing_TextBlobDestroy(blob);
    return 0;
}

} // extern "C"
