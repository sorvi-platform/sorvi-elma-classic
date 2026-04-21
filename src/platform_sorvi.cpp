#include <cstdint>
#include <algorithm>
#include <sys/stat.h>
#include <directinput/scancodes.h>
#include <eol/eol.h>
#include "platform_impl.h"
#include "sound_engine.h"
#include "pic8.h"
#include "keys.h"

extern int elma_main();

struct Color {
  uint8_t r, g, b, a;
};

static uint16_t framebuffer_w = 0;
static uint16_t framebuffer_h = 0;
static uint8_t *framebuffer_pixels = NULL;
static uint8_t screen_indexed_pixels[800 * 600] = {};
static Color *screen_palette = NULL;
static bool scancodes[255] = {};
static bool scancodes_prev[255] = {};
static bool buttons[2] = {};
static bool buttons_prev[2] = {};
static DikScancode last_key = DIK_UNKNOWN;
static uint64_t monotonic_time = 0;
static uint64_t last_repeat_time = 0;
static uint64_t repeat_delay = 300;

extern "C" {
  void elma_platform_run(void) {
    elma_main();
  }

  void elma_platform_frame_data(uint16_t w, uint16_t h, unsigned char *buffer, uint64_t time) {
    framebuffer_pixels = buffer;
    framebuffer_w = w;
    framebuffer_h = h;
    monotonic_time = time;
  }

  void elma_platform_mix_sound(short *buffer, size_t len) {
    sound_mixer(buffer, len);
  }

  void elma_platform_key(uint32_t code, bool pressed) {
    if (pressed) {
      last_repeat_time = monotonic_time;
      last_key = code;
    } else {
      repeat_delay = 300;
      if (last_key = code) {
        last_key = DIK_UNKNOWN;
      }
    }
    scancodes[code] = pressed;
  }

  void elma_platform_button(uint32_t button, bool pressed) {
    buttons[button] = pressed;
  }

  [[noreturn]] extern void sorvi_core_v1_panic(const char *msg, uintptr_t addr);
  extern void elma_platform_wait_for_frame(void);
  extern void elma_platform_finish_frame(void);
};

void message_box(const char *msg) {
  sorvi_core_v1_panic(msg, 0);
}

bool platform_render_error(pic8 *buffer) {
  if (!buffer) return false;
  pic8 view;
  lock_backbuffer(view, false);
  blit8(&view, buffer);
  unlock_backbuffer();
  return true;
}

void handle_events() {
  memcpy(buttons_prev, buttons, sizeof(buttons));
  if (last_key != DIK_UNKNOWN && monotonic_time > last_repeat_time + repeat_delay) {
    memset(scancodes_prev, false, sizeof(scancodes));
    last_repeat_time = monotonic_time;
    if (repeat_delay > 80) {
      repeat_delay = std::max(repeat_delay - 80, (uint64_t)20);
    }
  } else {
    memcpy(scancodes_prev, scancodes, sizeof(scancodes));
  }
  elma_platform_wait_for_frame();
  if (scancodes[DIK_L]) {
    add_text_to_buffer("lol");
  }
  EolClient->tick();
}

void platform_init() {
  mkdir("/data/rec", 0755);
}

void init_sound() {}

void lock_backbuffer(pic8 &view, bool flipped) {
  view.subview(framebuffer_w, framebuffer_h, screen_indexed_pixels, framebuffer_w, flipped);
}

void unlock_backbuffer() {
  for (size_t idx = 0; idx < framebuffer_w * framebuffer_h; ++idx) {
    auto color = screen_palette[screen_indexed_pixels[idx]];
    framebuffer_pixels[idx * 4 + 0] = color.r;
    framebuffer_pixels[idx * 4 + 1] = color.g;
    framebuffer_pixels[idx * 4 + 2] = color.b;
    framebuffer_pixels[idx * 4 + 3] = color.a;
  }
}

void lock_frontbuffer(pic8 &view, bool flipped) {
  lock_backbuffer(view, flipped);
}

void unlock_frontbuffer() {
  unlock_backbuffer();
}

void get_mouse_position(int *x, int *y) {}

void set_mouse_position(int x, int y) {}

bool was_left_mouse_just_clicked() {
  return buttons[0] && !buttons_prev[0];
}

bool was_right_mouse_just_clicked() {
  return buttons[1] && !buttons_prev[1];
}

void show_cursor() {}

void hide_cursor() {}

bool is_key_down(DikScancode code) {
  return scancodes[code];
}

bool was_key_just_pressed(DikScancode code) {
  return scancodes[code] && !scancodes_prev[code];
}

DikScancode get_any_key_just_pressed() {
  auto key = last_key;
  last_key = DIK_UNKNOWN;
  return key;
}

bool was_key_down(DikScancode code) {
  return scancodes[code] && !scancodes_prev[code];
}

int get_mouse_wheel_delta() {
  return 0;
}

std::string get_clipboard_text() {
  return "";
}

bool is_shortcut_modifier_down() {
  return false;
}

bool is_fullscreen() {
  return true;
}

long long get_milliseconds() {
  return monotonic_time;
}

void platform_apply_fullscreen_mode() {}

std::vector<std::pair<int, int>> platform_get_display_modes() {
  return {{800, 600}};
}

std::pair<int, int> platform_get_desktop_resolution() {
  return {800, 600};
}

void platform_resize_window(int width, int height) {}

void platform_recreate_window() {}

bool has_window() {
  return true;
}

palette::palette(unsigned char* palette_data) {
    Color* pal = new Color[256];
    for (int i = 0; i < 256; i++) {
        pal[i].r = palette_data[3 * i];
        pal[i].g = palette_data[3 * i + 1];
        pal[i].b = palette_data[3 * i + 2];
        pal[i].a = 0xFF;
    }
    data = (void*)pal;
}

palette::~palette() { delete[] (Color*)data; }

void palette::set() {
  screen_palette = (Color*)data;
}
