#!/usr/bin/env python3
"""Extract only SDL's synthesis engine; leave its source unchanged."""
from pathlib import Path
import sys
s=Path('src/sdl/audio.c').read_text().split('static void audio_cb')[0]
s=s.replace('#include "audio.h"', '#include "../../src/sdl/audio.h"')
a=s.index('static SDL_AudioDeviceID'); b=s.index('static int noise_s16',a)
s=s[:a]+s[b:]
s=s.replace('return ((int)n - 128) << 8;', 'return ((int)n - 128) * 256;') # same samples, defined signed arithmetic for UBSan
s+='\nuint32_t reference_phase(AudioEnv *e,int i) { return e->phase[i]; }\nuint32_t reference_noise(AudioEnv *e,int i) { return e->lfsr[i]; }\n'
Path(sys.argv[1]).write_text(s)
