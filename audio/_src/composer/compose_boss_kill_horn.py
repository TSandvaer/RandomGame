"""
compose_boss_kill_horn.py — algorithmic placeholder composer for the M3-T2-W3-T16
boss-kill horn cue (Beat F2 of the boss-defeated cinematic).

Owner: Devon · Phase: M3-T2-W3-T16b (ClickUp 86c9wjzgh) · Date: 2026-05-22.

What this script does
---------------------
Generates `audio/sfx/mobs/sfx-boss-kill-horn.ogg` — a single sustained warm horn
note that rises across 0.9 s, peaking as embers exit screen during the Beat F2
boss-defeated cinematic (per Uma `boss-intro.md` §Beat F2 + `audio-direction.md`
row sfx-boss-kill-horn + AD-23).

Design intent (Uma F2):
  - 0.9 s sustained warm horn — NOT a clipped sting, NOT a slow swell-only.
  - "Rising" — pitch glides gently upward across the duration so the note feels
    LIFTED, climbing alongside the visual embers.
  - Peak energy lands at ~T+0.75-0.85 s — the embers are exiting screen by then
    and the horn-into-silence sets up the BossDefeatedTitleCard fade-in at T+1.2.
  - Tonally rhymes with sfx-boss-wake (M3-T2-W1-T7 sibling cue, also low brass)
    so the boss's entry and exit share a harmonic palette — wake at A2 (110 Hz)
    fundamental; kill-horn at D3 (146.83 Hz) fundamental rising to ~E3 (164.8 Hz)
    over the 0.9 s. The minor-third lift between wake (A2) and kill-horn (D3+) is
    intentional — the entrance is darker, the exit lands a step brighter.

Why a placeholder (not freesound / hand-Foley / sampled)
-------------------------------------------------------
Same disclosure pattern as `compose_sfx_m3w7.py` and `compose_stratum1.py` — the
dispatched-agent environment has no DAW / no Spitfire LABS samples / no internet
access for freesound curation. The synthesis emulates additive low-brass via a
fundamental + 5 harmonics with a brass-style harmonic tilt, low-pass body filter,
and an ADSR shaped so the attack is gentle (40 ms — no hard transient that would
read as a sting) and the release tails over 250 ms.

Routes through `AudioDirector.play_sfx(SFX_BOSS_KILL_HORN)` which is fired from
`Stratum1BossRoom._play_t16_cinematic_climax(death_position)` (Drew's T16a wiring
already calls play_sfx with cue id `sfx-boss-kill-horn`; T16b lands the asset +
SFX_PATHS entry so the call no longer hits the UNKNOWN safe-no-op branch).

Output format (matches `audio-direction.md §4`)
-----------------------------------------------
- OGG Vorbis (libsndfile defaults near q5).
- 44.1 kHz mono per SFX format rule.
- Peak normalized to -3 dBFS (combat headroom, no clipping in HTML5 export).

Reproducibility
---------------
Run from repo root:
    python audio/_src/composer/compose_boss_kill_horn.py
Outputs to:
    audio/sfx/mobs/sfx-boss-kill-horn.ogg

M4 promotion plan
-----------------
M4 ticket: promote to hand-composed (Spitfire LABS low-brass sample at D3 with
a tasteful pitch-glide to E3, ~1-2 h authoring + mix) OR freesound CC0 source
(alphorn / low-trombone) + DAW mix. Same one-file replace under the cue-ID ==
filename rule.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

SR = 44100
PEAK_TARGET_DBFS = -3.0


def _t(n_samples: int) -> np.ndarray:
    return np.linspace(0.0, n_samples / SR, n_samples, endpoint=False)


def _lowpass(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    sos = butter(2, cutoff_hz, btype="lowpass", fs=SR, output="sos")
    return sosfilt(sos, x)


def _bandpass(x: np.ndarray, low_hz: float, high_hz: float) -> np.ndarray:
    sos = butter(2, [low_hz, high_hz], btype="bandpass", fs=SR, output="sos")
    return sosfilt(sos, x)


def _normalize(y: np.ndarray, target_dbfs: float = PEAK_TARGET_DBFS) -> np.ndarray:
    peak = float(np.max(np.abs(y)))
    if peak < 1e-9:
        return y
    target_amp = 10.0 ** (target_dbfs / 20.0)
    return y * (target_amp / peak)


def compose_boss_kill_horn(rng: np.random.Generator) -> np.ndarray:
    """Boss-kill horn: sustained warm horn note rising D3 → E3 over 0.9 s.

    Per Uma `boss-intro.md` Beat F2 + audio-direction.md sfx-boss-kill-horn row.
    """
    duration_s = 0.90
    n = int(SR * duration_s)
    t = _t(n)

    # ------------------------------------------------------------------
    # Pitch glide: D3 (146.83 Hz) at t=0 → E3 (164.81 Hz) at t=duration_s.
    # A ~2-semitone rise across the note — perceptually "lifted", not a hard
    # bend. Per Uma "rising" without specifying interval; minor third would
    # be too overt, major second too subtle; whole tone reads as lift.
    # ------------------------------------------------------------------
    f0_start = 146.83  # D3
    f0_end = 164.81    # E3
    f0 = f0_start + (f0_end - f0_start) * (t / duration_s)
    phase = 2.0 * math.pi * np.cumsum(f0) / SR

    # ------------------------------------------------------------------
    # Brass harmonic stack: fundamental + 5 harmonics with the brass tilt
    # (strong 2nd + 3rd harmonics is the low-brass tell). Same shape as
    # sfx-boss-wake to rhyme the entry/exit harmonic palette.
    # ------------------------------------------------------------------
    horn = (
        1.00 * np.sin(phase)
        + 0.70 * np.sin(2.0 * phase)
        + 0.50 * np.sin(3.0 * phase)
        + 0.30 * np.sin(4.0 * phase)
        + 0.18 * np.sin(5.0 * phase)
        + 0.10 * np.sin(6.0 * phase)
    )
    # Body filter — low-pass at 1100 Hz softens the upper partials so the
    # note reads as warm horn, not bright trumpet.
    horn = _lowpass(horn, 1100.0)

    # ------------------------------------------------------------------
    # ADSR envelope shaped so peak energy lands at ~T+0.75-0.85 s (embers
    # exiting screen). Attack 40 ms (gentle, no hard transient — this is
    # not a sting). Decay-then-rising-sustain so the note feels like it's
    # climbing, peaking late, then a short release into silence (so the
    # title card at T+1.2 lands into clean silence per the
    # "silence as punctuation" tonal pattern in audio-architecture.md).
    # ------------------------------------------------------------------
    attack_s = 0.040
    release_s = 0.250
    a = int(SR * attack_s)
    r = int(SR * release_s)
    s = max(0, n - a - r)

    env = np.zeros(n)
    # Attack: 0 → 0.55 (start lower than peak — note still climbing).
    if a > 0:
        env[:a] = np.linspace(0.0, 0.55, a, endpoint=False)
    # Sustain: rising from 0.55 → 1.0 across the sustain section. Peak hits
    # near the end of sustain (just before release starts).
    if s > 0:
        env[a:a + s] = np.linspace(0.55, 1.0, s, endpoint=False)
    # Release: 1.0 → 0 over 250 ms.
    if r > 0:
        env[a + s:a + s + r] = np.linspace(1.0, 0.0, r, endpoint=False)

    horn = horn * env * 0.85

    # ------------------------------------------------------------------
    # Bow-noise / breath sheen — faint high-band noise that scales with
    # envelope so the texture feels physical (a real horn has some air
    # noise riding on the tone). Quiet at -18 dB-ish relative to the horn.
    # ------------------------------------------------------------------
    noise = rng.uniform(-1.0, 1.0, n).astype(np.float64)
    breath = _bandpass(noise, 1500.0, 3500.0) * env * 0.06

    # ------------------------------------------------------------------
    # Sub-octave bed — half-fundamental at D2 (73.42 Hz) glided down a hair
    # to give the note physical weight. Quiet at -12 dB-ish so it grounds
    # the horn without competing with the body harmonics.
    # ------------------------------------------------------------------
    sub_phase = 2.0 * math.pi * np.cumsum(f0 * 0.5) / SR
    sub = np.sin(sub_phase) * env * 0.25

    y = horn + breath + sub
    return _normalize(y)


CUES = [
    ("audio/sfx/mobs/sfx-boss-kill-horn.ogg", compose_boss_kill_horn, 41),
]


def main() -> int:
    repo_root = Path(__file__).resolve().parents[3]
    for rel_path, composer, seed in CUES:
        out = repo_root / rel_path
        out.parent.mkdir(parents=True, exist_ok=True)
        rng = np.random.default_rng(seed=seed)
        mono = composer(rng).astype(np.float32)
        sf.write(str(out), mono, SR, format="OGG", subtype="VORBIS")
        peak_db = 20.0 * math.log10(max(float(np.max(np.abs(mono))), 1e-9))
        duration_s = len(mono) / SR
        print(
            f"[compose_boss_kill_horn] wrote {rel_path}  "
            f"peak={peak_db:+.2f} dBFS  samples={len(mono)}  "
            f"duration={duration_s:.3f} s"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
