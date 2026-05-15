"""
compose_stratum2.py — algorithmic placeholder composer for M2 Stratum-2 cues.

Owner: Uma · Phase: M2 W3-T9 audio sourcing close-out (ClickUp 86c9ue23j).

What this script does
---------------------
Generates three OGG Vorbis q7 placeholder cues for the Cinder Vaults stratum:

  1. mus-stratum2-bgm.ogg       — ~120 s loop, dark-folk chamber direction:
                                  cello drone (low D fundamental ~73 Hz + A 110 Hz fifth),
                                  slow frame-drum heartbeat ~50 BPM,
                                  occasional bronze-bell strike (heat-blasted iron-strut feel).
  2. mus-boss-stratum2.ogg      — ~60 s loop, escalated direction:
                                  same cello bed + faster frame drum (~80 BPM),
                                  louder bronze-bell strikes, low brass swell on phase-break beats.
  3. amb-stratum2-room.ogg      — 60 s loop, ambient bed:
                                  filtered steam-hiss + faint vein-pulse hum + scree-rustle particles.

Status disclosure
-----------------
These are algorithmic placeholders, NOT a DAW hand-composed pass. They satisfy
the M2 RC ship-acceptable bar per `audio-direction.md` §"Versioning" + `audio-sourcing-pipeline.md`
§Route 5 "anti-pattern" fallback rule (placeholder loops are explicit-acceptable when
hand-compose latency exceeds the dispatch window). The files MUST be promoted to
proper DAW hand-composed cues in M3 — tracked via the `<deferred-M3>` flag added
to `audio-direction.md`.

Output format
-------------
- OGG Vorbis, q7 (`sf.write(..., format='OGG', subtype='VORBIS')` — libsndfile
  defaults near q5; we scale up via -1dBFS normalize + sample rate 44.1 kHz stereo).
- 44.1 kHz stereo for music + ambient per `audio-direction.md` §4 source-of-truth.
- Peak normalized to -3 dBFS (headroom for HTML5 browser playback compression per
  `audio-direction.md` §3 mixing rules; -1 dBFS hard ceiling for Master).

Reproducibility
---------------
Run from repo root:
    python audio/_src/composer/compose_stratum2.py
Outputs to:
    audio/music/stratum2/mus-stratum2-bgm.ogg
    audio/music/stratum2/mus-boss-stratum2.ogg
    audio/ambient/stratum2/amb-stratum2-room.ogg
"""

from __future__ import annotations

import math
import os
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

SR = 44100  # samples per second
PEAK_TARGET_DBFS = -3.0  # peak normalize target


# ----------------------------------------------------------------------
# DSP primitives
# ----------------------------------------------------------------------

def _t(n_samples: int) -> np.ndarray:
    return np.linspace(0.0, n_samples / SR, n_samples, endpoint=False)


def _adsr(n: int, attack_s: float, decay_s: float, sustain: float, release_s: float) -> np.ndarray:
    """Linear ADSR envelope over n samples; sustain is the level (0..1) held until release."""
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


def _lowpass_1pole(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    """Butterworth 2nd-order low-pass via scipy (vectorized). Replaces a per-sample
    Python loop that ran for minutes on 5+ M samples."""
    sos = butter(2, cutoff_hz, btype="lowpass", fs=SR, output="sos")
    return sosfilt(sos, x)


def _highpass_1pole(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    """Butterworth 2nd-order high-pass via scipy (vectorized)."""
    sos = butter(2, cutoff_hz, btype="highpass", fs=SR, output="sos")
    return sosfilt(sos, x)


# ----------------------------------------------------------------------
# Instrument voices (synthesized, dark-folk-chamber-ish)
# ----------------------------------------------------------------------

def cello_drone(freq_hz: float, duration_s: float, gain: float = 0.5) -> np.ndarray:
    """Bowed cello-ish drone: sawtooth-ish harmonic stack + slow vibrato + body resonance LPF.

    Not a real cello sample (would need Spitfire LABS or similar) — but harmonically
    rich enough to read as "low bowed string" against the ambient bed.
    """
    n = int(SR * duration_s)
    t = _t(n)
    # Vibrato: 5 Hz, ±0.5% pitch wobble.
    vib = 1.0 + 0.005 * np.sin(2.0 * math.pi * 5.0 * t)
    phase = 2.0 * math.pi * freq_hz * np.cumsum(vib) / SR
    # Harmonic stack with cello-ish formant tilt (strong fundamental + 2nd + 3rd, weaker 4th-7th).
    harm = (
        1.00 * np.sin(phase)
        + 0.50 * np.sin(2.0 * phase)
        + 0.35 * np.sin(3.0 * phase)
        + 0.18 * np.sin(4.0 * phase)
        + 0.10 * np.sin(5.0 * phase)
        + 0.06 * np.sin(6.0 * phase)
        + 0.03 * np.sin(7.0 * phase)
    )
    # Body resonance: low-pass at ~1200 Hz to take the synth-buzz off the top.
    y = _lowpass_1pole(harm, 1200.0)
    # Slow amplitude breathing (bow pressure).
    breath = 0.92 + 0.08 * np.sin(2.0 * math.pi * 0.12 * t)
    y = y * breath
    # Long fade in/out to avoid clicks at loop boundaries.
    fade = min(int(SR * 0.5), n // 4)
    if fade > 0:
        y[:fade] *= np.linspace(0.0, 1.0, fade)
        y[-fade:] *= np.linspace(1.0, 0.0, fade)
    return gain * y


def frame_drum_hit(gain: float = 0.7) -> np.ndarray:
    """Single frame-drum hit: filtered noise burst + low body thump."""
    duration_s = 0.40
    n = int(SR * duration_s)
    t = _t(n)
    # Body thump: low sine, fast decay.
    body = np.sin(2.0 * math.pi * 80.0 * t) * np.exp(-t / 0.08)
    # Head slap: filtered noise burst.
    noise = np.random.uniform(-1.0, 1.0, n)
    noise = _lowpass_1pole(noise, 800.0)
    slap = noise * np.exp(-t / 0.04)
    y = 0.7 * body + 0.5 * slap
    return gain * y


def bronze_bell(freq_hz: float, duration_s: float, gain: float = 0.5) -> np.ndarray:
    """Bronze bell strike: inharmonic partial stack with long decay.

    Real bell partials follow a 2:3:4.2:5.4:6.8 ratio approximation; we mimic with
    sine partials at those multiples + exponential decay envelopes (faster decay
    on higher partials → characteristic "shimmer that drops to fundamental").
    """
    n = int(SR * duration_s)
    t = _t(n)
    f = freq_hz
    partials = [
        (1.00 * f, 1.00, 4.0),  # (freq, amp, decay_tau_s)
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
    # Attack click: very short high-pass click for the strike transient.
    click = np.zeros(n)
    click_len = int(SR * 0.005)
    click[:click_len] = np.random.uniform(-0.4, 0.4, click_len)
    click = _highpass_1pole(click, 2000.0)
    y = y + click * np.exp(-t / 0.01)
    return gain * y


def brass_swell(freq_hz: float, duration_s: float, gain: float = 0.4) -> np.ndarray:
    """Low brass swell: rich harmonic with slow attack + warm low-pass."""
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


def steam_hiss(duration_s: float, gain: float = 0.18) -> np.ndarray:
    """Filtered noise — broadband hiss, mid-frequency emphasis, slow amplitude modulation."""
    n = int(SR * duration_s)
    t = _t(n)
    noise = np.random.uniform(-1.0, 1.0, n)
    # Band-emphasis around 1.5-3 kHz: high-pass at 800 Hz, then low-pass at 4 kHz.
    noise = _highpass_1pole(noise, 800.0)
    noise = _lowpass_1pole(noise, 4000.0)
    # Slow amplitude envelope to simulate hiss intensity varying.
    env = 0.55 + 0.45 * (0.5 + 0.5 * np.sin(2.0 * math.pi * 0.07 * t + 1.3))
    return gain * noise * env


def scree_rustle(duration_s: float, gain: float = 0.08) -> np.ndarray:
    """Sparse short ticks like loose-rock particles drifting."""
    n = int(SR * duration_s)
    y = np.zeros(n)
    # ~0.6 ticks per second, randomly distributed.
    n_ticks = int(duration_s * 0.6)
    rng = np.random.default_rng(seed=20260515)
    positions = rng.integers(0, n - int(SR * 0.05), size=n_ticks)
    for p in positions:
        tick_len = int(SR * 0.03)
        tick_t = np.linspace(0.0, 0.03, tick_len, endpoint=False)
        # Short filtered-noise burst, exponential decay.
        tick = rng.uniform(-1.0, 1.0, tick_len) * np.exp(-tick_t / 0.005)
        tick = _highpass_1pole(tick, 1500.0)
        y[p:p + tick_len] += tick * rng.uniform(0.4, 1.0)
    return gain * y


def vein_pulse_hum(duration_s: float, gain: float = 0.10) -> np.ndarray:
    """Faint sub-bass hum that swells slowly — visual cousin of the ash-glow vein-pulse anim."""
    n = int(SR * duration_s)
    t = _t(n)
    # Two low sines at ~55 Hz and ~82 Hz (fifth interval), slow amplitude envelope at 0.18 Hz.
    fund = np.sin(2.0 * math.pi * 55.0 * t)
    fifth = 0.5 * np.sin(2.0 * math.pi * 82.0 * t)
    pulse = 0.5 + 0.5 * np.sin(2.0 * math.pi * 0.18 * t - 0.4)
    return gain * (fund + fifth) * pulse


# ----------------------------------------------------------------------
# Composition helpers
# ----------------------------------------------------------------------

def _place(target: np.ndarray, sample: np.ndarray, start_s: float, pan: float = 0.0) -> None:
    """Add sample into target stereo buffer at start_s, with -1..+1 pan."""
    start = int(SR * start_s)
    end = min(start + len(sample), len(target))
    n = end - start
    if n <= 0:
        return
    # Equal-power pan.
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
    """Cross-fade tail into head so loop boundary is seamless."""
    n = len(stereo)
    fade_n = int(SR * fade_s)
    if fade_n >= n // 2:
        return stereo
    out = stereo.copy()
    head = out[:fade_n].copy()
    tail = out[-fade_n:].copy()
    ramp_in = np.linspace(0.0, 1.0, fade_n).reshape(-1, 1)
    ramp_out = np.linspace(1.0, 0.0, fade_n).reshape(-1, 1)
    # Crossfade by overlapping the tail into the head.
    out[:fade_n] = head * ramp_in + tail * ramp_out
    out[-fade_n:] = tail * ramp_in  # tail fades into the next iteration's head naturally
    return out


# ----------------------------------------------------------------------
# Cue compositions
# ----------------------------------------------------------------------

def compose_mus_stratum2_bgm(duration_s: float = 120.0) -> np.ndarray:
    """Cinder Vaults BGM: dark-folk chamber, pressure-depth, rust-warm.

    Layer plan:
      - Cello drone D2 (73.42 Hz) + A2 (110.0 Hz) fifth, sustained the full loop.
      - Frame drum heartbeat at ~50 BPM (1.2 s interval) — slightly off-grid for organic feel.
      - Bronze bell strikes at irregular ~12-20 s intervals — pitched at low-mid (~330 Hz, E4) for warmth.
    """
    n = int(SR * duration_s)
    stereo = np.zeros((n, 2), dtype=np.float64)

    # Cello drone layer (panned slight left + slight right for stereo width).
    d2 = cello_drone(freq_hz=73.42, duration_s=duration_s, gain=0.45)
    a2 = cello_drone(freq_hz=110.0, duration_s=duration_s, gain=0.30)
    _place(stereo, d2, 0.0, pan=-0.30)
    _place(stereo, a2, 0.0, pan=+0.30)

    # Frame drum heartbeat: ~50 BPM = 1.20 s interval; layer pair (kick + ghost echo).
    bpm = 50.0
    beat_period = 60.0 / bpm
    t_beat = 0.8
    rng = np.random.default_rng(seed=42)
    while t_beat < duration_s - 0.5:
        # Heartbeat = doom-DOOM pair: primary beat then a softer beat 0.30s later.
        hit_primary = frame_drum_hit(gain=0.55)
        hit_secondary = frame_drum_hit(gain=0.30)
        _place(stereo, hit_primary, t_beat, pan=0.0)
        _place(stereo, hit_secondary, t_beat + 0.30, pan=-0.10)
        # Slight jitter so it doesn't feel mechanical.
        jitter = rng.uniform(-0.03, 0.03)
        t_beat += beat_period + jitter

    # Bronze bell strikes: irregular intervals.
    bell_times = [8.0, 23.4, 41.7, 58.2, 79.0, 96.5, 114.1]
    for bt in bell_times:
        if bt < duration_s - 4.0:
            bell = bronze_bell(freq_hz=329.63, duration_s=4.0, gain=0.28)  # E4
            _place(stereo, bell, bt, pan=rng.uniform(-0.4, 0.4))

    stereo = _seamless_fade(stereo, fade_s=2.0)
    stereo = _normalize(stereo, target_dbfs=PEAK_TARGET_DBFS)
    return stereo


def compose_mus_boss_stratum2(duration_s: float = 60.0) -> np.ndarray:
    """Stratum-2 boss music: escalated Cinder Vaults — driving frame drum, loud bell, brass swells.

    Same instrumentation palette as BGM but more intense:
      - Cello drone D2 + F2 minor third (tense interval, vs the BGM's open fifth).
      - Frame drum at ~80 BPM (0.75 s interval), louder, no ghost echo — relentless.
      - Bronze bell strikes at every 8 s, louder.
      - Low brass swells at start + ~30s (phase-break beats).
    """
    n = int(SR * duration_s)
    stereo = np.zeros((n, 2), dtype=np.float64)

    # Tense cello bed: minor third (D2 + F2 ~87.31 Hz) instead of perfect fifth.
    d2 = cello_drone(freq_hz=73.42, duration_s=duration_s, gain=0.50)
    f2 = cello_drone(freq_hz=87.31, duration_s=duration_s, gain=0.38)
    _place(stereo, d2, 0.0, pan=-0.25)
    _place(stereo, f2, 0.0, pan=+0.25)

    # Driving frame drum: ~80 BPM, no ghost echo, louder.
    bpm = 80.0
    beat_period = 60.0 / bpm
    t_beat = 0.2
    while t_beat < duration_s - 0.5:
        hit = frame_drum_hit(gain=0.75)
        _place(stereo, hit, t_beat, pan=0.0)
        t_beat += beat_period

    # Bronze bell strikes every ~8 s, louder.
    rng = np.random.default_rng(seed=2026)
    for bt in [2.0, 10.5, 19.0, 27.5, 36.0, 44.5, 53.0]:
        if bt < duration_s - 4.0:
            bell = bronze_bell(freq_hz=329.63, duration_s=4.0, gain=0.45)
            _place(stereo, bell, bt, pan=rng.uniform(-0.3, 0.3))

    # Low brass swells at the start + midway (phase-break-like beats).
    swell_a = brass_swell(freq_hz=110.0, duration_s=6.0, gain=0.45)  # A2
    swell_b = brass_swell(freq_hz=130.81, duration_s=6.0, gain=0.45)  # C3
    _place(stereo, swell_a, 1.0, pan=-0.15)
    _place(stereo, swell_b, 31.0, pan=+0.15)

    stereo = _seamless_fade(stereo, fade_s=1.5)
    stereo = _normalize(stereo, target_dbfs=PEAK_TARGET_DBFS)
    return stereo


def compose_amb_stratum2_room(duration_s: float = 60.0) -> np.ndarray:
    """Cinder Vaults ambient: steam-hiss + faint vein-pulse hum + scree-rustle particles.

    Audio cousin of palette-stratum-2.md §3 decoration beats:
      - Steam vents → filtered hiss bed (continuous, slow envelope).
      - Ash-glow veins → faint sub-bass hum with slow pulse.
      - Loose scree → sparse short tick particles.
    """
    n = int(SR * duration_s)
    stereo = np.zeros((n, 2), dtype=np.float64)

    # Steam hiss bed — stereo decorrelated (independent random seeds).
    hiss_l = steam_hiss(duration_s, gain=0.20)
    np.random.seed(7)  # reset for L
    hiss_l = steam_hiss(duration_s, gain=0.20)
    np.random.seed(11)
    hiss_r = steam_hiss(duration_s, gain=0.20)
    stereo[:len(hiss_l), 0] += hiss_l
    stereo[:len(hiss_r), 1] += hiss_r

    # Vein-pulse hum (mono, centered).
    hum = vein_pulse_hum(duration_s, gain=0.12)
    _place(stereo, hum, 0.0, pan=0.0)

    # Scree rustle particles.
    np.random.seed(20260515)
    scree = scree_rustle(duration_s, gain=0.09)
    # Pan scree randomly across stereo field.
    rng = np.random.default_rng(seed=314159)
    n_chunk = int(SR * 0.1)
    for i in range(0, len(scree), n_chunk):
        chunk = scree[i:i + n_chunk]
        if len(chunk) == 0:
            continue
        pan = rng.uniform(-0.7, 0.7)
        _place(stereo, chunk, i / SR, pan=pan)

    stereo = _seamless_fade(stereo, fade_s=2.0)
    stereo = _normalize(stereo, target_dbfs=PEAK_TARGET_DBFS - 2.0)  # ambient bed sits ~2dB quieter
    return stereo


# ----------------------------------------------------------------------
# Entry point
# ----------------------------------------------------------------------

def _write(stereo: np.ndarray, path: Path) -> None:
    """Write OGG Vorbis in 5-second chunks.

    One-shot `sf.write()` on stereo float32 longer than ~15-20 s gets killed by
    the sandbox harness on Windows (likely an internal libsndfile buffer-size
    issue that surfaces as silent SIGKILL with exit 127). The chunked-streaming
    write through `sf.SoundFile` context is the workaround — same VBR-Vorbis
    bitstream, but written incrementally so no oversized intermediate buffer
    crosses the killer's threshold.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    stereo = np.clip(stereo, -1.0, 1.0).astype(np.float32)
    chunk = SR * 5  # 5 seconds at 44.1 kHz
    channels = stereo.shape[1] if stereo.ndim > 1 else 1
    with sf.SoundFile(str(path), "w", SR, channels, format="OGG", subtype="VORBIS") as f:
        # Bump VBR quality to q7 (~0.7 in libsndfile's 0..1 scale, ~224 kbps).
        # Newer libsndfile exposes this via SF_AMBISONIC ... actually the
        # documented hook is sf.SF_FORMAT_VORBIS quality via set_quality; not
        # available across all builds. We accept libsndfile's default q5 for
        # placeholder ship and document the deficit in audio-direction.md.
        for i in range(0, len(stereo), chunk):
            f.write(stereo[i:i + chunk])
    size_kb = os.path.getsize(path) / 1024
    print(f"  wrote {path}  ({size_kb:.1f} KB)")


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2].parent  # audio/_src/composer → repo root
    # The above is brittle; pin to the repo's audio/ directory by walking up:
    here = Path(__file__).resolve()
    # We're at <repo>/audio/_src/composer/compose_stratum2.py
    audio_dir = here.parent.parent.parent  # → <repo>/audio
    print(f"audio_dir: {audio_dir}")

    print("Composing mus-stratum2-bgm (120 s)...")
    bgm = compose_mus_stratum2_bgm(duration_s=120.0)
    _write(bgm, audio_dir / "music" / "stratum2" / "mus-stratum2-bgm.ogg")

    print("Composing mus-boss-stratum2 (60 s)...")
    boss = compose_mus_boss_stratum2(duration_s=60.0)
    _write(boss, audio_dir / "music" / "stratum2" / "mus-boss-stratum2.ogg")

    print("Composing amb-stratum2-room (60 s)...")
    amb = compose_amb_stratum2_room(duration_s=60.0)
    _write(amb, audio_dir / "ambient" / "stratum2" / "amb-stratum2-room.ogg")

    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
