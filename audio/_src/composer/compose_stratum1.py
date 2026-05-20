"""
compose_stratum1.py — algorithmic placeholder composer for M3-T2-W1 Stratum-1 boss BGM.

Owner: Devon · Phase: M3 Tier 2 Wave 1 T1 (ClickUp 86c9wjxzh) · Date: 2026-05-20.

What this script does
---------------------
Generates one OGG Vorbis q5 placeholder cue:

  mus-boss-stratum1.ogg — ~60 s loop. Per `team/uma-ux/audio-direction.md`
                          §2 "Music" table, the S1 boss BGM is "driving,
                          frame drum + cello + brass swells", single track
                          for all 3 phases in M1. Aesthetic anchor:
                          dark-folk chamber, NOT orchestral / synth /
                          chiptune (§1 tonal-direction).

Status disclosure (matches `audio-direction.md §6 placeholder synthesis disclosure`)
-----------------------------------------------------------------------------------
This is an algorithmic placeholder, NOT a DAW hand-composed pass. Same
acceptance bar as `compose_stratum2.py`'s S2 boss music — ship-acceptable
per Route 5 fallback ("placeholder loops are explicit-acceptable when
hand-compose latency exceeds the dispatch window"). The file MUST be
promoted to a DAW hand-composed cue in M4 — tracked via the `<deferred-M4>`
flag added to `audio-direction.md`.

Aesthetic differentiation vs S2 boss music
------------------------------------------
Per `team/DECISIONS.md` 2026-05-15 — boss music is UNIQUE per stratum,
NOT cross-stratum-reuse. S1 boss BGM is the climax of the open-world
S1 floor (stone cloister, single warm light); S2 boss is Cinder Vaults
(heat-blasted iron, denser industrial feel). To honor that decision the
S1 boss BGM:

  - Uses a major-minor ambiguous bed (D2 + A2 perfect-fifth, same as S1
    BGM but elevated to boss intensity), NOT S2's minor-third tension
    bed (D2 + F2).
  - Frame drum at ~72 BPM (steady, ritual — the boss has presence but
    is patient), vs S2's ~80 BPM (faster, more frantic).
  - Bronze bell strikes pitched at E4 (same as the death-flow bell —
    intentional rhyme per `boss-intro.md` §"Audio map" Beat 4).
  - Single brass swell on entry (T+1 s), vs S2's two swells at entry +
    midway (S2 boss has more phase-break punctuation).

Output format
-------------
- OGG Vorbis, q5 (libsndfile defaults near q5).
- 44.1 kHz **stereo** per `audio-direction.md §4` music format rule.
- Peak normalized to -3 dBFS (combat headroom; BGM mix headroom at -1 dBFS).

Reproducibility
---------------
Run from repo root:
    python audio/_src/composer/compose_stratum1.py
Outputs to:
    audio/music/stratum1/mus-boss-stratum1.ogg

DSP primitives are vendored from compose_stratum2.py (same instrument
voices: `cello_drone`, `frame_drum_hit`, `bronze_bell`, `brass_swell`)
to keep this script self-contained. No shared module risk for a
placeholder pipeline.
"""

from __future__ import annotations

import math
import os
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

SR = 44100
PEAK_TARGET_DBFS = -3.0


# ----------------------------------------------------------------------
# DSP primitives (vendored from compose_stratum2.py)
# ----------------------------------------------------------------------

def _t(n_samples: int) -> np.ndarray:
    return np.linspace(0.0, n_samples / SR, n_samples, endpoint=False)


def _lowpass_1pole(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    sos = butter(2, cutoff_hz, btype="lowpass", fs=SR, output="sos")
    return sosfilt(sos, x)


def _highpass_1pole(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    sos = butter(2, cutoff_hz, btype="highpass", fs=SR, output="sos")
    return sosfilt(sos, x)


def _adsr(n: int, attack_s: float, decay_s: float, sustain: float, release_s: float) -> np.ndarray:
    a = int(SR * attack_s)
    d = int(SR * decay_s)
    r = int(SR * release_s)
    s = max(0, n - a - d - r)
    env = np.zeros(n, dtype=np.float64)
    if a > 0:
        env[:a] = np.linspace(0.0, 1.0, a, endpoint=False)
    if d > 0:
        env[a:a + d] = np.linspace(1.0, sustain, d, endpoint=False)
    env[a + d:a + d + s] = sustain
    if r > 0:
        end = a + d + s
        env[end:end + r] = np.linspace(sustain, 0.0, r, endpoint=False)
    return env


# ----------------------------------------------------------------------
# Instrument voices (vendored)
# ----------------------------------------------------------------------

def cello_drone(freq_hz: float, duration_s: float, gain: float = 0.5) -> np.ndarray:
    n = int(SR * duration_s)
    t = _t(n)
    vib = 1.0 + 0.005 * np.sin(2.0 * math.pi * 5.0 * t)
    phase = 2.0 * math.pi * freq_hz * np.cumsum(vib) / SR
    harm = (
        1.00 * np.sin(phase)
        + 0.50 * np.sin(2.0 * phase)
        + 0.35 * np.sin(3.0 * phase)
        + 0.18 * np.sin(4.0 * phase)
        + 0.10 * np.sin(5.0 * phase)
        + 0.06 * np.sin(6.0 * phase)
        + 0.03 * np.sin(7.0 * phase)
    )
    y = _lowpass_1pole(harm, 1200.0)
    breath = 0.92 + 0.08 * np.sin(2.0 * math.pi * 0.12 * t)
    y = y * breath
    fade = min(int(SR * 0.5), n // 4)
    if fade > 0:
        y[:fade] *= np.linspace(0.0, 1.0, fade)
        y[-fade:] *= np.linspace(1.0, 0.0, fade)
    return gain * y


def frame_drum_hit(gain: float = 0.7) -> np.ndarray:
    duration_s = 0.40
    n = int(SR * duration_s)
    t = _t(n)
    body = np.sin(2.0 * math.pi * 80.0 * t) * np.exp(-t / 0.08)
    rng = np.random.default_rng(seed=20260520)
    noise = rng.uniform(-1.0, 1.0, n)
    noise = _lowpass_1pole(noise, 800.0)
    slap = noise * np.exp(-t / 0.04)
    y = 0.7 * body + 0.5 * slap
    return gain * y


def bronze_bell(freq_hz: float, duration_s: float, gain: float = 0.5) -> np.ndarray:
    n = int(SR * duration_s)
    t = _t(n)
    f = freq_hz
    partials = [
        (1.00 * f, 1.00, 4.0),
        (2.00 * f, 0.55, 3.0),
        (2.40 * f, 0.40, 2.5),
        (3.00 * f, 0.35, 2.0),
        (4.20 * f, 0.25, 1.2),
        (5.40 * f, 0.18, 0.8),
        (6.80 * f, 0.12, 0.6),
    ]
    y = np.zeros(n)
    for pf, pa, tau in partials:
        y += pa * np.sin(2.0 * math.pi * pf * t) * np.exp(-t / tau)
    click = np.zeros(n)
    click_len = int(SR * 0.005)
    rng = np.random.default_rng(seed=int(freq_hz * 100))
    click[:click_len] = rng.uniform(-0.4, 0.4, click_len)
    click = _highpass_1pole(click, 2000.0)
    y = y + click * np.exp(-t / 0.01)
    return gain * y


def brass_swell(freq_hz: float, duration_s: float, gain: float = 0.4) -> np.ndarray:
    n = int(SR * duration_s)
    t = _t(n)
    phase = 2.0 * math.pi * freq_hz * t
    y = (
        np.sin(phase)
        + 0.6 * np.sin(2.0 * phase)
        + 0.4 * np.sin(3.0 * phase)
        + 0.25 * np.sin(4.0 * phase)
        + 0.12 * np.sin(5.0 * phase)
    )
    y = _lowpass_1pole(y, 900.0)
    env = _adsr(n, attack_s=duration_s * 0.45, decay_s=duration_s * 0.20,
                sustain=0.7, release_s=duration_s * 0.30)
    return gain * y * env


# ----------------------------------------------------------------------
# Composition helpers (vendored)
# ----------------------------------------------------------------------

def _place(target: np.ndarray, sample: np.ndarray, start_s: float, pan: float = 0.0) -> None:
    start = int(SR * start_s)
    end = min(start + len(sample), len(target))
    n = end - start
    if n <= 0:
        return
    pan = max(-1.0, min(1.0, pan))
    theta = (pan + 1.0) * math.pi / 4.0
    lg = math.cos(theta)
    rg = math.sin(theta)
    target[start:end, 0] += sample[:n] * lg
    target[start:end, 1] += sample[:n] * rg


def _normalize(stereo: np.ndarray, target_dbfs: float = PEAK_TARGET_DBFS) -> np.ndarray:
    peak = np.max(np.abs(stereo))
    if peak < 1e-9:
        return stereo
    target_amp = 10.0 ** (target_dbfs / 20.0)
    return stereo * (target_amp / peak)


def _seamless_fade(stereo: np.ndarray, fade_s: float = 1.5) -> np.ndarray:
    n = len(stereo)
    fade_n = int(SR * fade_s)
    if fade_n >= n // 2:
        return stereo
    out = stereo.copy()
    head = out[:fade_n].copy()
    tail = out[-fade_n:].copy()
    ramp_in = np.linspace(0.0, 1.0, fade_n).reshape(-1, 1)
    ramp_out = np.linspace(1.0, 0.0, fade_n).reshape(-1, 1)
    out[:fade_n] = head * ramp_in + tail * ramp_out
    out[-fade_n:] = tail * ramp_in
    return out


# ----------------------------------------------------------------------
# Cue composition
# ----------------------------------------------------------------------

def compose_mus_boss_stratum1(duration_s: float = 60.0) -> np.ndarray:
    """Stratum-1 boss BGM: driving frame drum + cello bed + brass swell.

    Layer plan (per `audio-direction.md` §2 Music + §1 dark-folk-chamber):
      - Cello bed: D2 (73.42 Hz) + A2 (110.0 Hz) perfect-fifth, sustained
        the full loop. SAME interval as S1 BGM but elevated gain (this is
        the boss BEAT, not the wandering exploration BGM).
      - Frame drum heartbeat at ~72 BPM (0.833 s interval) — slightly
        slower than S2 boss's 80 BPM. Steady, ritual cadence; the boss
        has presence but is patient.
      - Bronze bell strikes at E4 (329.63 Hz) every ~10 s — intentional
        rhyme with the death-flow / nameplate bell (Uma `boss-intro.md`
        §"Audio map" Beat 4). Carries the "this is the climax" cue.
      - Single brass swell on entry (T+1 s, ~6 s duration) — the player-
        arrival moment. S2 boss has TWO swells (entry + midway phase
        break); S1 boss has ONE because M1 doesn't yet have phase-break
        audio cinematic layered atop the BGM (T7 ships the phase-break
        sting separately).
    """
    n = int(SR * duration_s)
    stereo = np.zeros((n, 2), dtype=np.float64)

    # Cello bed: D2 + A2 perfect-fifth (S1 BGM interval, but elevated for boss).
    d2 = cello_drone(freq_hz=73.42, duration_s=duration_s, gain=0.45)
    a2 = cello_drone(freq_hz=110.0, duration_s=duration_s, gain=0.32)
    _place(stereo, d2, 0.0, pan=-0.30)
    _place(stereo, a2, 0.0, pan=+0.30)

    # Frame drum at 72 BPM, no ghost echo (vs S1 BGM's heartbeat-pair).
    bpm = 72.0
    beat_period = 60.0 / bpm
    t_beat = 0.5
    rng = np.random.default_rng(seed=20260520)
    while t_beat < duration_s - 0.5:
        hit = frame_drum_hit(gain=0.65)
        _place(stereo, hit, t_beat, pan=rng.uniform(-0.10, 0.10))
        # Mild jitter so it doesn't feel mechanical (±20 ms).
        jitter = rng.uniform(-0.02, 0.02)
        t_beat += beat_period + jitter

    # Bronze bell strikes — E4, ~every 10 s, panned varied.
    bell_times = [4.5, 14.8, 25.3, 36.0, 46.5, 56.8]
    for bt in bell_times:
        if bt < duration_s - 4.0:
            bell = bronze_bell(freq_hz=329.63, duration_s=4.0, gain=0.40)
            _place(stereo, bell, bt, pan=rng.uniform(-0.35, 0.35))

    # Single low-brass swell on entry (T+1 s, 6 s).
    swell = brass_swell(freq_hz=110.0, duration_s=6.0, gain=0.42)  # A2
    _place(stereo, swell, 1.0, pan=0.0)

    stereo = _seamless_fade(stereo, fade_s=2.0)
    stereo = _normalize(stereo, target_dbfs=PEAK_TARGET_DBFS)
    return stereo


# ----------------------------------------------------------------------
# Entry point
# ----------------------------------------------------------------------

def _write(stereo: np.ndarray, path: Path) -> None:
    """Write OGG Vorbis in 5-second chunks. Same pattern as compose_stratum2.py
    to dodge the libsndfile-on-Windows oversized-buffer SIGKILL.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    stereo = np.clip(stereo, -1.0, 1.0).astype(np.float32)
    chunk = SR * 5
    channels = stereo.shape[1] if stereo.ndim > 1 else 1
    with sf.SoundFile(str(path), "w", SR, channels, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(stereo), chunk):
            f.write(stereo[i:i + chunk])
    size_kb = os.path.getsize(path) / 1024
    print(f"  wrote {path}  ({size_kb:.1f} KB)")


def main() -> int:
    here = Path(__file__).resolve()
    audio_dir = here.parent.parent.parent  # → <repo>/audio
    print(f"audio_dir: {audio_dir}")

    print("Composing mus-boss-stratum1 (60 s)...")
    boss = compose_mus_boss_stratum1(duration_s=60.0)
    _write(boss, audio_dir / "music" / "stratum1" / "mus-boss-stratum1.ogg")

    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
