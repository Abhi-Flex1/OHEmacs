// ohosterm stub — declares the redisplay_interface entry points for Stage 2.
//
// Full ohosterm.c (~5-6k lines) will be cloned from Emacs 30.1
// `src/androidterm.c` (6934 lines):
//   create_terminal + redisplay_interface (update_begin/end, frame_up_to_date,
//   glyph-string fns android_draw_glyph_string_* -> ohos_draw_glyph_string_*
//   via OH_Drawing_Canvas), read_socket (android_read_socket analogue),
//   cursor/divider, frame parm handlers. See docs/PORTING.md.

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct terminal;
struct frame;

// Created by ohos.c during emacs init; registers redisplay_interface.
struct terminal *ohos_create_terminal(void);

// Called from NAPI/XComponent thread to pump ohos_event_queue into Emacs
// keyboard.c (mirrors android_read_socket in androidterm.c:1853).
int ohos_read_socket(struct terminal *terminal, int *hold_quit);

// Redraw hooks wired to terminal->update_begin_hook etc. in full port.
void ohos_update_begin(struct frame *f);
void ohos_update_end(struct frame *f);
void ohos_frame_up_to_date(struct frame *f);

#ifdef __cplusplus
}
#endif
