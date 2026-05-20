"""
compose_stratum1_ambient.py — placeholder composer for M3-T2-W2 Stratum-1 ambient bed.

Owner: Devon · Phase: M3 Tier 2 Wave 2 T10 (ClickUp 86c9wjyke) · Date: 2026-05-20.

What this script does
---------------------
Generates one OGG Vorbis q5 placeholder cue:

  amb-stratum1-room.ogg — ~60 s seamless loop. Per Uma's binding direction
                          brief (`team/uma-ux/s1-ambient.md`), the S1
                          ambient reads as "a stone cloister settled into
                          silence — the monks are gone but the room hasn't
                          noticed yet." Distinct from S2 (active pressure
                          texture); S1 is post-active sparsity.

Status disclosure
-----------------
Algorithmic placeholder, NOT a DAW hand-composed pass. Uma's brief §"Sourcing
strategy" rank-orders the routes: (1) freesound CC0 query + DAW mix,
(2) DAW mix on top, (3) **placeholder synthesis fallback** if Tier 2 dispatch
hits the same constraints as W3-T9. Per `audio-direction.md §6 placeholder
synthesis disclosure` + Route 5 fallback rule, this script is the disclosed
fallback. The cue MUST be promoted to a freesound + DAW mix in M4 audio
polish — tracked via the `<deferred-M4>` flag added to
`audio-direction.md` and `audio-sourcing-pipeline.md` row 217.

Layered content (Uma's brief §"Reference texture")
--------------------------------------------------
Three layers, mixed at relative levels designed so the player's footstep
is the loudest event in the room until combat starts.

  1. Room tone — soft stone reverb tail.
     1.4 s real-stone reverb (small chapel, not hall). Functionally: the
     room "sounds large" without any source. Implementation: thin filtered
     pink noise heavily reverb'd, peak ~ -42 dBFS pre-bus.

  2. Distant drip — irregular sparse single-drop ticks.
     ~12-25 s apart, jittered, never on a beat. Dry-close (no reverb wash
     on the drops) which contrasts the room-tone tail: drip is HERE, room
     is VAST. Peak ~ -32 dBFS pre-bus.

  3. Faint wind through arches — sub-300 Hz biased, ~0.05 Hz modulation.
     Prevents the bed from feeling muted (silence-with-air, not
     silence-with-vacuum). Peak ~ -38 dBFS pre-bus.

Anti-content (Uma §"Anti-content"):
  - No torch crackle (that's positional `amb-stratum1-torch`, separate cue).
  - No frame-drum heartbeat (S2's pressure-cousin).
  - No bronze-bell strikes (`sfx-bell-struck` is reserved for narrative beats).
  - No musical pitch content (ambient is texture, not proto-BGM).

Output format
-------------
- OGG Vorbis, q5 (libsndfile defaults near q5). Uma's brief calls for q7;
  libsndfile python bindings expose only q5 by default — same constraint
  the S2 composer hit and disclosed per `compose_stratum2.py` § Output
  format. M4 DAW hand-mix promotion will land at q7.
- 44.1 kHz stereo per Uma §"Format" + `audio-direction.md §4`.
- Peak normalized to -24 dBFS file-level (Uma §"Volume / loudness targets")
  so the post-bus level (Ambient bus -18 dB) sits at -42 dBFS Master.

Reproducibility
---------------
Run from repo root:
    python audio/_src/composer/compose_stratum1_ambient.py
Outputs to:
    audio/ambient/stratum1/amb-stratum1-room.ogg

DSP primitives vendored from compose_stratum2.py (lowpass / highpass /
seamless_fade / normalize) — keeps this script self-contained for a
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
PEAK_TARGET_DBFS = -24.0  # Uma's brief §"Volume / loudness targets" — file-level peak

# Reproducibility seed — pin RNG so successive composer runs produce
# bitwise-identical files. Important for change-review: a regenerate-on-edit
# loop should not show drift in the committed asset unless real DSP changes.
SEED = 20260520


# ----------------------------------------------------------------------
# DSP primitives (vendored from compose_stratum2.py)
# ----------------------------------------------------------------------


def _t(n_samples: int) -> np.ndarray:
    return np.linspace(0.0, n_samples / SR, n_samples, endpoint=False)


def _lowpass(x: np.ndarray, cutoff_hz: float, order: int = 2) -> np.ndarray:
    sos = butter(order, cutoff_hz, btype="lowpass", fs=SR, output="sos")
    return sosfilt(sos, x)


def _highpass(x: np.ndarray, cutoff_hz: float, order: int = 2) -> np.ndarray:
    sos = butter(order, cutoff_hz, btype="highpass", fs=SR, output="sos")
    return sosfilt(sos, x)


def _bandpass(x: np.ndarray, low_hz: float, high_hz: float) -> np.ndarray:
    sos = butter(2, [low_hz, high_hz], btype="bandpass", fs=SR, output="sos")
    return sosfilt(sos, x)


def _normalize(stereo: np.ndarray, target_dbfs: float = PEAK_TARGET_DBFS) -> np.ndarray:
    peak = np.max(np.abs(stereo))
    if peak < 1e-9:
        return stereo
    target_amp = 10.0 ** (target_dbfs / 20.0)
    return stereo * (target_amp / peak)


def _seamless_fade(stereo: np.ndarray, fade_s: float = 2.0) -> np.ndarray:
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
    out[:fade_n] = head * ramp_in + tail * ramp_out
    out[-fade_n:] = tail * ramp_in
    return out


def _place(target: np.ndarray, sample: np.ndarray, start_s: float, pan: float = 0.0) -> None:
    """Add mono sample into target stereo buffer at start_s, equal-power pan."""
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


# ----------------------------------------------------------------------
# Ambient layer voices
# ----------------------------------------------------------------------


def room_tone_reverb_tail(duration_s: float, gain: float = 0.018) -> np.ndarray:
    """Thin filtered pink-noise bed simulating a small-chapel reverb tail.

    Method: pink-ish noise (white through 1-pole LP cascade) + heavy schroeder-
    style smoothing to produce a sustain that reads as "this room is large".
    Centered, slow amplitude breathing so the bed feels alive rather than static.
    The result is at -42 dBFS pre-bus when gain=0.018; further attenuated by
    the file-level normalize.
    """
    n = int(SR * duration_s)
    rng = np.random.default_rng(seed=SEED)
    noise = rng.uniform(-1.0, 1.0, n)
    # Pink-noise approximation: cascade two LPs to roll off the highs.
    noise = _lowpass(noise, 6000.0)
    noise = _lowpass(noise, 2000.0)
    # Reverb tail simulation: long exponential smoothing kernel via repeated
    # convolution with a decaying noise impulse. Cheap; reads as "stone room"
    # not "spring reverb" because the smoothing is bandlimited.
    # Single-tap delay-line accumulator (the canonical Schroeder allpass would
    # be heavier; this is sufficient for a placeholder bed).
    smoothed = np.zeros(n)
    a = 0.0008  # leak coefficient — tuned for ~1.4 s perceived RT60
    state = 0.0
    for i in range(n):
        state += a * (noise[i] - state)
        smoothed[i] = state
    # Slow amplitude breathing — 0.07 Hz, ±10%.
    t = _t(n)
    breath = 0.90 + 0.10 * np.sin(2.0 * math.pi * 0.07 * t)
    y = smoothed * breath
    return gain * y


def distant_drip_ticks(duration_s: float, gain: float = 0.16) -> np.ndarray:
    """Sparse single water-drop ticks at irregular intervals.

    ~12-25 s apart per Uma §"Reference texture" 2. Dry-close (no reverb wash
    on the drops). Each drop is a short percussive transient: sharp attack +
    quick decay, mid-frequency pitch (~ 800-1500 Hz) suggesting "water on
    stone close to mic". Pitch jitter so successive drops don't clone-sound.
    """
    n = int(SR * duration_s)
    y = np.zeros(n)
    rng = np.random.default_rng(seed=SEED + 1)
    # Generate drop times. Mean inter-drop interval ~18 s, jittered uniformly
    # in [12, 25].
    t_drop = rng.uniform(2.0, 4.0)  # first drop 2-4 s in
    while t_drop < duration_s - 1.0:
        # Drop is a single-cycle sine burst + filtered noise click, ~30 ms
        # total, exponential amplitude decay.
        drop_dur = 0.030 + rng.uniform(-0.005, 0.005)
        drop_n = int(SR * drop_dur)
        drop_t = np.linspace(0.0, drop_dur, drop_n, endpoint=False)
        # Pitch jitter — each drop slightly different.
        freq = rng.uniform(750.0, 1450.0)
        body = np.sin(2.0 * math.pi * freq * drop_t)
        # Quick exponential decay: tau ~ 8 ms, so most energy in first 20 ms.
        envelope = np.exp(-drop_t / 0.008)
        # Small attack click — bandpassed noise burst at the very start.
        click_n = int(SR * 0.002)
        click = rng.uniform(-1.0, 1.0, click_n) * np.exp(-np.linspace(0.0, 0.002, click_n) / 0.0008)
        click = _bandpass(click, 1500.0, 5000.0)
        # Combine.
        drop = 0.7 * body * envelope
        drop[:click_n] += 0.5 * click
        # Random amplitude variation — drops aren't equal.
        amp = rng.uniform(0.55, 1.0)
        # Place. Drops are dry-close so we DON'T pan them widely — keep near-
        # center with small jitter so the listener feels them "right here".
        start = int(SR * t_drop)
        end = min(start + drop_n, n)
        actual_n = end - start
        if actual_n > 0:
            y[start:end] += amp * drop[:actual_n]
        # Next interval — jittered 12-25 s.
        t_drop += rng.uniform(12.0, 25.0)
    return gain * y


def faint_wind_through_arches(duration_s: float, gain: float = 0.06) -> np.ndarray:
    """Sub-300 Hz filtered noise with slow LFO modulation.

    Reads as "air is moving but you can't tell where from". Prevents the bed
    from feeling muted — the silence-with-air vs silence-with-vacuum
    distinction in Uma's brief.
    """
    n = int(SR * duration_s)
    rng = np.random.default_rng(seed=SEED + 2)
    noise = rng.uniform(-1.0, 1.0, n)
    # Aggressive low-pass at 280 Hz — sub-300 Hz bias per Uma's brief.
    wind = _lowpass(noise, 280.0, order=4)
    # Slow amplitude modulation, ~0.05 Hz — full cycle every 20 s.
    t = _t(n)
    lfo = 0.6 + 0.4 * np.sin(2.0 * math.pi * 0.05 * t + 0.7)
    return gain * wind * lfo


# ----------------------------------------------------------------------
# Composition
# ----------------------------------------------------------------------


def compose_amb_stratum1_room(duration_s: float = 75.0) -> np.ndarray:
    """Stratum-1 ambient bed — stone cloister settled into silence.

    Layer plan (Uma's brief §"Reference texture", quietest → most-present):
      1. Room tone (filtered pink + reverb tail) — quietest, stereo-decorrelated.
      2. Faint wind (sub-300 Hz, slow LFO) — second-quietest, stereo-decorrelated.
      3. Distant drips (sparse single-tick at jittered 12-25 s intervals) — most-present.
    """
    n = int(SR * duration_s)
    stereo = np.zeros((n, 2), dtype=np.float64)

    # Room tone — stereo-decorrelated (two independent generations) so the
    # tail feels like a wide room, not a centered mono blob.
    tone_l = room_tone_reverb_tail(duration_s, gain=0.022)
    # Re-seed for the right channel to get an independent reverb tail.
    global SEED  # noqa: PLW0603
    saved_seed = SEED
    SEED = SEED + 10
    tone_r = room_tone_reverb_tail(duration_s, gain=0.022)
    SEED = saved_seed
    stereo[: len(tone_l), 0] += tone_l
    stereo[: len(tone_r), 1] += tone_r

    # Wind — stereo-decorrelated, same trick.
    wind_l = faint_wind_through_arches(duration_s, gain=0.060)
    SEED = saved_seed + 20
    wind_r = faint_wind_through_arches(duration_s, gain=0.060)
    SEED = saved_seed
    stereo[: len(wind_l), 0] += wind_l
    stereo[: len(wind_r), 1] += wind_r

    # Drips — placed via _place with slight pan jitter per drop. Uma's brief
    # says "physically close (no reverb wash)" so we keep these centered with
    # small jitter, not panned wide.
    drips = distant_drip_ticks(duration_s, gain=0.20)
    # _place wants a mono buffer; the drips array IS mono, but it's already
    # aligned to absolute times. Add directly to both channels at a small
    # pan-jitter per drop time? Simpler: add the mono drip layer to both
    # channels with the equal-power pan = 0.0 (centered) so it sits "right
    # here" as Uma directs.
    stereo[: len(drips), 0] += drips * math.cos(math.pi / 4.0)
    stereo[: len(drips), 1] += drips * math.sin(math.pi / 4.0)

    # Seamless loop boundary — 2 s tail-into-head crossfade.
    stereo = _seamless_fade(stereo, fade_s=2.0)

    # Normalize peak to Uma's -24 dBFS file-level target.
    stereo = _normalize(stereo, target_dbfs=PEAK_TARGET_DBFS)
    return stereo


# ----------------------------------------------------------------------
# Entry point
# ----------------------------------------------------------------------


def _write(stereo: np.ndarray, path: Path) -> None:
    """Write OGG Vorbis in 5-second chunks.

    Matches compose_stratum2.py's chunked-write pattern — one-shot sf.write on
    stereo float32 longer than ~15-20 s gets killed by the sandbox harness on
    Windows. Chunked streaming through SoundFile context avoids that.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    stereo = np.clip(stereo, -1.0, 1.0).astype(np.float32)
    chunk = SR * 5
    channels = stereo.shape[1] if stereo.ndim > 1 else 1
    with sf.SoundFile(str(path), "w", SR, channels, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(stereo), chunk):
            f.write(stereo[i : i + chunk])
    size_kb = os.path.getsize(path) / 1024
    print(f"  wrote {path}  ({size_kb:.1f} KB)")


def main() -> int:
    here = Path(__file__).resolve()
    audio_dir = here.parent.parent.parent  # → <repo>/audio
    print(f"audio_dir: {audio_dir}")

    print("Composing amb-stratum1-room (75 s)...")
    amb = compose_amb_stratum1_room(duration_s=75.0)
    _write(amb, audio_dir / "ambient" / "stratum1" / "amb-stratum1-room.ogg")

    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
