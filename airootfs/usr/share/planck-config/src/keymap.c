#include QMK_KEYBOARD_H
#ifdef AUDIO_ENABLE
#include "muse.h"
#endif
#include "eeprom.h"
#include "keymap_french.h"
#include "keymap_contributions.h"
#include "keymap_us_international.h"

#define KC_MAC_UNDO LGUI(KC_Z)
#define KC_MAC_CUT LGUI(KC_X)
#define KC_MAC_COPY LGUI(KC_C)
#define KC_MAC_PASTE LGUI(KC_V)
#define KC_PC_UNDO LCTL(KC_Z)
#define KC_PC_CUT LCTL(KC_X)
#define KC_PC_COPY LCTL(KC_C)
#define KC_PC_PASTE LCTL(KC_V)
#define ES_LESS_MAC KC_GRAVE
#define ES_GRTR_MAC LSFT(KC_GRAVE)
#define ES_BSLS_MAC ALGR(KC_6)
#define NO_PIPE_ALT KC_GRAVE
#define NO_BSLS_ALT KC_EQUAL
#define LSA_T(kc) MT(MOD_LSFT | MOD_LALT, kc)
#define BP_NDSH_MAC ALGR(KC_8)
#define SE_SECT_MAC ALGR(KC_6)
#define T KC_TRANSPARENT

enum planck_keycodes {
  RGB_SLD = EZ_SAFE_RANGE,
  ST_MACRO_A, ST_MACRO_B, ST_MACRO_C,
  ST_MACRO_D, ST_MACRO_E, ST_MACRO_F,
  ST_MACRO_G, ST_MACRO_H, ST_MACRO_I,
  ST_MACRO_J, ST_MACRO_K, ST_MACRO_L,
  ST_MACRO_M, ST_MACRO_N, ST_MACRO_O,
  ST_MACRO_P, ST_MACRO_Q, ST_MACRO_R,
  ST_MACRO_S, ST_MACRO_T, ST_MACRO_U,
  ST_MACRO_V, ST_MACRO_W, ST_MACRO_X,
  ST_MACRO_Y, ST_MACRO_Z
};

enum planck_layers {
  _BASE,
  _LOWER,
  _RAISE,
  _ADJUST,
  _LAYER4,
  _LAYER5,
};

#define LOWER MO(_LOWER)
#define RAISE MO(_RAISE)

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [_BASE] = LAYOUT_planck_grid(
    KC_ESCAPE,  KC_Q,  KC_W,     KC_E,      KC_R,   KC_T,      KC_Y,   KC_U,   KC_I,            KC_O,    KC_P,       KC_BSPACE,
    KC_TAB,     KC_A,  KC_S,     KC_D,      KC_F,   KC_G,      KC_H,   KC_J,   KC_K,            KC_L,    KC_SCOLON,  KC_ENTER,
    KC_LSHIFT,  KC_Z,  KC_X,     KC_C,      KC_V,   KC_B,      KC_N,   KC_M,   KC_COMMA,        KC_DOT,  KC_SLASH,   KC_RSHIFT,
    T,          T,     KC_LGUI,  KC_LCTRL,  LOWER,  KC_SPACE,  KC_NO,  RAISE,  LALT(KC_LCTRL),  MO(4),   KC_LALT,    T
  ),

  [_LOWER] = LAYOUT_planck_grid(
    T,  KC_1,       KC_2,         KC_3,         KC_4,     KC_5,     KC_6,     KC_7,     KC_8,              KC_9,            KC_0,                T,
    T,  KC_LCBR,    KC_LBRACKET,  KC_RBRACKET,  KC_RCBR,  KC_PIPE,  KC_LEFT,  KC_DOWN,  KC_UP,             KC_RIGHT,        T,                   T,
    T,  T,          T,            T,            T,        T,        T,        T,        KC_GRAVE,          KC_TILD,         KC_BSLASH,           T,
    T,  T,          T,            T,            T,        T,        KC_NO,    T,        KC_AUDIO_VOL_DOWN, KC_AUDIO_VOL_UP, KC_MEDIA_PLAY_PAUSE, T                    
  ),                                                                                                                                                             

  [_RAISE] = LAYOUT_planck_grid(
    T,  KC_EXLM,  KC_AT,  KC_HASH,  KC_DLR,  KC_PERC,  KC_CIRC,  KC_AMPR,   KC_ASTR,   KC_LPRN,  KC_RPRN,  T,
    T,  T,        T,      T,        T,       T,        T,        KC_MINUS,  KC_EQUAL,  T,        T,        T,
    T,  T,        T,      T,        T,       T,        KC_DQUO,  KC_QUOTE,  T,         T,        T,        T,
    T,  T,        T,      T,        T,       T,        KC_NO,    T,         T,         T,        T,        T
  ),

  [_ADJUST] = LAYOUT_planck_grid(
    TT(5),  T,  T,  T,  T,  T,       T,         T,        T,        T,        T,  EE_CLR,
    T,      T,  T,  T,  T,  T,       T,         RGB_TOG,  RGB_VAI,  RGB_VAD,  T,  RESET,
    T,      T,  T,  T,  T,  T,       RGB_RMOD,  RGB_MOD,  RGB_HUI,  RGB_HUD,  T,  T,
    T,      T,  T,  T,  T,  MU_TOG,  KC_NO,     T,        T,        T,        T,  T
  ),

  [_LAYER4] = LAYOUT_planck_grid(
    T,  KC_F1,  KC_F2,  KC_F3,  T,  T,  T,      T,  T,  T,  T,  T,
    T,  KC_F4,  KC_F5,  KC_F6,  T,  T,  T,      T,  T,  T,  T,  T,
    T,  KC_F7,  KC_F8,  KC_F9,  T,  T,  T,      T,  T,  T,  T,  T,
    T,  KC_F10, KC_F11, KC_F12, T,  T,  KC_NO,  T,  T,  T,  T,  T
  ),

  [_LAYER5] = LAYOUT_planck_grid(
    T, ST_MACRO_Q, ST_MACRO_W, ST_MACRO_E, ST_MACRO_R, ST_MACRO_T, ST_MACRO_Y, ST_MACRO_U, ST_MACRO_I, ST_MACRO_O, ST_MACRO_P, T,
    T, ST_MACRO_A, ST_MACRO_S, ST_MACRO_D, ST_MACRO_F, ST_MACRO_G, ST_MACRO_H, ST_MACRO_J, ST_MACRO_K, ST_MACRO_L, T,          T,
    T, ST_MACRO_Z, ST_MACRO_X, ST_MACRO_C, ST_MACRO_V, ST_MACRO_B, ST_MACRO_N, ST_MACRO_M, T,          T,          T,          T,
    T, T,          T,          T,          T,          T,          KC_NO,      T,          T,          T,          T,          T
  ),
};

const uint16_t PROGMEM combo0[] = { KC_LSHIFT, KC_RSHIFT, COMBO_END };
 
combo_t key_combos[COMBO_COUNT] = {
    COMBO(combo0, KC_CAPSLOCK),
};                                                                              

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
  for (int i = ST_MACRO_A; i < ST_MACRO_Z; i++) {
      if (keycode == i && record->event.pressed) {
	  register_code(KC_LALT);
	  register_code(KC_PSCREEN);
	  register_code(KC_A+i-ST_MACRO_A);
	  wait_ms(30);
	  unregister_code(KC_LALT);
	  unregister_code(KC_PSCREEN);
	  unregister_code(KC_A+i-ST_MACRO_A);
      }
  }
  switch (keycode) {
    case RGB_SLD:
        if (rawhid_state.rgb_control) {
            return false;
        }
        if (record->event.pressed) {
            rgblight_mode(1);
        }
        return false;
  }
  return true;
}

#ifdef AUDIO_ENABLE
bool muse_mode = false;
uint8_t last_muse_note = 0;
uint16_t muse_counter = 0;
uint8_t muse_offset = 70;
uint16_t muse_tempo = 50;

void encoder_update(bool clockwise) {
    if (muse_mode) {
        if (IS_LAYER_ON(_RAISE)) {
            if (clockwise) {
                muse_offset++;
            } else {
                muse_offset--;
            }
        } else {
            if (clockwise) {
                muse_tempo+=1;
            } else {
                muse_tempo-=1;
            }
        }
    } else {
        if (clockwise) {
        #ifdef MOUSEKEY_ENABLE
            register_code(KC_MS_WH_DOWN);
            unregister_code(KC_MS_WH_DOWN);
        #else
            register_code(KC_PGDN);
            unregister_code(KC_PGDN);
        #endif
        } else {
        #ifdef MOUSEKEY_ENABLE
            register_code(KC_MS_WH_UP);
            unregister_code(KC_MS_WH_UP);
        #else
            register_code(KC_PGUP);
            unregister_code(KC_PGUP);
        #endif
        }
    }
}

void matrix_scan_user(void) {
#ifdef AUDIO_ENABLE
    if (muse_mode) {
        if (muse_counter == 0) {
            uint8_t muse_note = muse_offset + SCALE[muse_clock_pulse()];
            if (muse_note != last_muse_note) {
                stop_note(compute_freq_for_midi_note(last_muse_note));
                play_note(compute_freq_for_midi_note(muse_note), 0xF);
                last_muse_note = muse_note;
            }
        }
        muse_counter = (muse_counter + 1) % muse_tempo;
    }
#endif
}

bool music_mask_user(uint16_t keycode) {
    switch (keycode) {
    case RAISE:
    case LOWER:
        return false;
    default:
        return true;
    }
}
#endif

uint8_t layer_state_set_user(uint8_t state) {
    return update_tri_layer_state(state, _LOWER, _RAISE, _ADJUST);
}
