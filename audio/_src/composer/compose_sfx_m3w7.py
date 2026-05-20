"""
compose_sfx_m3w7.py — algorithmic placeholder composer for M3W-7 combat SFX cues.

Owner: Devon · Phase: M3W-7 (ClickUp 86c9va3d0) · Date: 2026-05-18.

What this script does
---------------------
Generates short OGG Vorbis SFX cues that the M3W-7 audio-cue wiring connects
to existing combat signals on Player + S1 mob roster + Boss. The set is the
load-bearing minimum for "combat has audio identity":

  1. sfx-mob-hit.ogg          — generic mob hit-take (Grunt/Charger/Shooter share)
  2. sfx-mob-die.ogg          — generic mob death thud
  3. sfx-boss-die.ogg         — boss-specific death (longer, heavier)
  4. sfx-player-attack-light.ogg  — short blade-swing whoosh
  5. sfx-player-attack-heavy.ogg  — longer + grunt-effort layered
  6. sfx-player-hit.ogg       — player took damage
  7. sfx-player-dodge.ogg     — cloth whoosh
  8. sfx-attack-telegraph.ogg — mob windup tone (used by Grunt light_telegraph,
                                Charger charge_telegraph, Shooter aim_started)
  9. sfx-attack-impact.ogg    — mob swing-fire impact (used by Grunt swing_spawned,
                                Charger charge_hit_spawned, Boss swing_spawned)

M3-T2-W1-T7 additions (ClickUp 86c9wjyak)
-----------------------------------------
 10. sfx-phase-break.ogg      — boss phase-transition tritone tension chord
                                (~400 ms). Fires once per boundary crossing
                                (66% / 33% HP) via Stratum1Boss.phase_changed.
                                Uma boss-intro.md BI-18.
 11. sfx-boss-wake.ogg        — boss-intro Beat 3 stinger: low brass + impact
                                (~600 ms). Fires once on Stratum1Boss.boss_woke.
                                Uma boss-intro.md BI-06.

Status disclosure (matches `audio-direction.md §6 placeholder synthesis disclosure`)
-----------------------------------------------------------------------------------
These are algorithmic placeholders, NOT freesound-sourced or hand-Foley
recordings. They satisfy the M3W-7 ship-acceptable bar per the
`audio-sourcing-pipeline.md` Route 5 fallback ("placeholder loop is explicit-
acceptable when authoring latency exceeds dispatch window"). The files MUST be
promoted to freesound + hand-Foley sourced cues in M4 — tracked via the
`<deferred-M4>` flag added below.

The synthesis emulates the right tonal direction per `audio-direction.md §1`
(dark-folk chamber acoustic identity — wood, leather, bone, no synths-as-
synths) using filtered noise bursts + low-body sines + bell-partial decay
patterns. Each cue is short (50ms–500ms) so it fits comfortably on the SFX
bus's -6 dB level without ducking or hiding the BGM.

Output format
-------------
- OGG Vorbis, q5 (libsndfile defaults near q5).
- 44.1 kHz **mono** per `audio-direction.md §4` SFX format rule.
- Peak normalized to -3 dBFS (combat headroom; BGM mix headroom is at -1 dBFS).

Reproducibility
---------------
Run from repo root:
    python audio/_src/composer/compose_sfx_m3w7.py
Outputs to:
    audio/sfx/player/sfx-player-attack-light.ogg
    audio/sfx/player/sfx-player-attack-heavy.ogg
    audio/sfx/player/sfx-player-hit.ogg
    audio/sfx/player/sfx-player-dodge.ogg
    audio/sfx/mobs/sfx-mob-hit.ogg
    audio/sfx/mobs/sfx-mob-die.ogg
    audio/sfx/mobs/sfx-boss-die.ogg
    audio/sfx/mobs/sfx-attack-telegraph.ogg
    audio/sfx/mobs/sfx-attack-impact.ogg
    audio/sfx/mobs/sfx-phase-break.ogg
    audio/sfx/mobs/sfx-boss-wake.ogg
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
# DSP primitives (vendored from compose_stratum2.py to keep this script
# self-contained — no shared module risk for a placeholder pipeline).
# ----------------------------------------------------------------------

def _t(n_samples: int) -> np.ndarray:
    return np.linspace(0.0, n_samples / SR, n_samples, endpoint=False)


def _lowpass(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    sos = butter(2, cutoff_hz, btype="lowpass", fs=SR, output="sos")
    return sosfilt(sos, x)


def _highpass(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    sos = butter(2, cutoff_hz, btype="highpass", fs=SR, output="sos")
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


def _exp_decay(n: int, tau_s: float) -> np.ndarray:
    t = _t(n)
    return np.exp(-t / max(tau_s, 1e-4))


# ----------------------------------------------------------------------
# Cue compositions
# ----------------------------------------------------------------------

def compose_mob_hit(rng: np.random.Generator) -> np.ndarray:
    """Mob hit-take: short pained-yelp + thud. 0.20 s."""
    duration_s = 0.20
    n = int(SR * duration_s)
    t = _t(n)
    # Thud body: low sine ~120 Hz, fast decay.
    body = np.sin(2.0 * math.pi * 120.0 * t) * _exp_decay(n, 0.05)
    # Voice-ish formant: bandpassed noise around 600-1200 Hz (a yelp's vowel band).
    noise = rng.uniform(-1.0, 1.0, n).astype(np.float64)
    yelp = _bandpass(noise, 600.0, 1200.0) * _exp_decay(n, 0.08)
    y = 0.6 * body + 0.45 * yelp
    return _normalize(y)


def compose_mob_die(rng: np.random.Generator) -> np.ndarray:
    """Mob death: gurgle + collapse-thud. 0.40 s."""
    duration_s = 0.40
    n = int(SR * duration_s)
    t = _t(n)
    # Body collapse: low sine slow decay.
    body = np.sin(2.0 * math.pi * 80.0 * t) * _exp_decay(n, 0.18)
    # Gurgle: noise bandpassed low + amplitude-modulated.
    noise = rng.uniform(-1.0, 1.0, n).astype(np.float64)
    gurgle = _bandpass(noise, 200.0, 800.0)
    am = 0.5 + 0.5 * np.sin(2.0 * math.pi * 14.0 * t)  # 14 Hz tremolo, throaty
    gurgle = gurgle * am * _exp_decay(n, 0.22)
    y = 0.55 * body + 0.40 * gurgle
    return _normalize(y)


def compose_boss_die(rng: np.random.Generator) -> np.ndarray:
    """Boss death: bestial bellow + heavy stone-thud + bell tail. 0.80 s."""
    duration_s = 0.80
    n = int(SR * duration_s)
    t = _t(n)
    # Bellow: 60 Hz fundamental + 90 + 150 harmonics with formant tilt.
    bellow = (
        1.00 * np.sin(2.0 * math.pi * 60.0 * t)
        + 0.55 * np.sin(2.0 * math.pi * 90.0 * t)
        + 0.30 * np.sin(2.0 * math.pi * 150.0 * t)
    ) * _exp_decay(n, 0.35)
    bellow = _lowpass(bellow, 600.0)
    # Stone thud: very low body + sub-bass click.
    thud = np.sin(2.0 * math.pi * 50.0 * t) * _exp_decay(n, 0.10)
    # Bell tail: hint of E4 bronze (carries through boss-kill horn aesthetic).
    bell_phase = 2.0 * math.pi * 329.63 * t
    bell = (
        1.00 * np.sin(bell_phase) * np.exp(-t / 0.5)
        + 0.45 * np.sin(2.0 * bell_phase) * np.exp(-t / 0.3)
    )
    y = 0.60 * bellow + 0.35 * thud + 0.20 * bell
    return _normalize(y)


def compose_player_attack_light(rng: np.random.Generator) -> np.ndarray:
    """Player light-swing: short blade-air whoosh. 0.15 s."""
    duration_s = 0.15
    n = int(SR * duration_s)
    t = _t(n)
    # Whoosh = high-band filtered noise with sweep upward.
    noise = rng.uniform(-1.0, 1.0, n).astype(np.float64)
    swept = _bandpass(noise, 1800.0, 4500.0)
    # Amplitude envelope: fast attack, fast decay.
    env = np.exp(-((t - 0.06) ** 2) / (2 * 0.025 ** 2))  # gaussian envelope
    y = swept * env
    return _normalize(y)


def compose_player_attack_heavy(rng: np.random.Generator) -> np.ndarray:
    """Player heavy-swing: blade-air whoosh + effort-grunt layered. 0.30 s."""
    duration_s = 0.30
    n = int(SR * duration_s)
    t = _t(n)
    # Whoosh (heavier, lower band than light).
    noise = rng.uniform(-1.0, 1.0, n).astype(np.float64)
    swept = _bandpass(noise, 1200.0, 3200.0)
    swept_env = np.exp(-((t - 0.10) ** 2) / (2 * 0.045 ** 2))
    # Effort grunt: bandpassed noise 400-900 Hz, gaussian envelope earlier.
    grunt_band = _bandpass(noise, 400.0, 900.0)
    grunt_env = np.exp(-((t - 0.05) ** 2) / (2 * 0.035 ** 2))
    y = 0.65 * swept * swept_env + 0.40 * grunt_band * grunt_env
    return _normalize(y)


def compose_player_hit(rng: np.random.Generator) -> np.ndarray:
    """Player took damage: leather-impact thud + soft male-grunt. 0.25 s."""
    duration_s = 0.25
    n = int(SR * duration_s)
    t = _t(n)
    # Leather thud: low body + soft transient click.
    body = np.sin(2.0 * math.pi * 110.0 * t) * _exp_decay(n, 0.06)
    # Soft inhale-gasp: bandpass noise 500-1400 Hz, slow amplitude swell-decay.
    noise = rng.uniform(-1.0, 1.0, n).astype(np.float64)
    gasp = _bandpass(noise, 500.0, 1400.0)
    gasp_env = np.exp(-((t - 0.07) ** 2) / (2 * 0.04 ** 2))
    y = 0.55 * body + 0.40 * gasp * gasp_env
    return _normalize(y)


def compose_player_dodge(rng: np.random.Generator) -> np.ndarray:
    """Cloak/cloth whoosh — dodge i-frame start. 0.18 s. Dry, no synth swoosh."""
    duration_s = 0.18
    n = int(SR * duration_s)
    t = _t(n)
    # High-mid bandpass noise, smooth envelope (not a tight transient).
    noise = rng.uniform(-1.0, 1.0, n).astype(np.float64)
    cloth = _bandpass(noise, 1500.0, 5000.0)
    env = np.sin(math.pi * t / duration_s)  # half-sine: ramps in + out smoothly
    y = cloth * env
    return _normalize(y)


def compose_attack_telegraph(rng: np.random.Generator) -> np.ndarray:
    """Mob attack windup: low pitched scrape + breath. 0.30 s. Used by every
    M3 mob's telegraph-start beat (Grunt light_telegraph_started, Charger
    charge_telegraph_started, Shooter aim_started)."""
    duration_s = 0.30
    n = int(SR * duration_s)
    t = _t(n)
    # Scrape: low rumbling sine slowly pitching up, simulating wind-up tension.
    f0 = 90.0
    f_sweep = f0 + 30.0 * t / duration_s  # 90→120 Hz over duration
    phase = 2.0 * math.pi * np.cumsum(f_sweep) / SR
    rumble = np.sin(phase) * 0.7
    # Breath: bandpass noise low 200-500 Hz, slow swell.
    noise = rng.uniform(-1.0, 1.0, n).astype(np.float64)
    breath = _bandpass(noise, 200.0, 500.0)
    env = np.sin(math.pi * t / duration_s) ** 1.5
    y = (rumble + 0.4 * breath) * env
    return _normalize(y)


def compose_attack_impact(rng: np.random.Generator) -> np.ndarray:
    """Mob swing-fire impact: heavy meat-thwack + slight bone-crack. 0.25 s.
    Used by every M3 mob's swing-fire beat (Grunt swing_spawned, Charger
    charge_hit_spawned, Boss swing_spawned-melee)."""
    duration_s = 0.25
    n = int(SR * duration_s)
    t = _t(n)
    # Meat thwack: dense low-mid transient.
    body = np.sin(2.0 * math.pi * 95.0 * t) * _exp_decay(n, 0.04)
    # Crack: bandpass noise transient 1500-3500 Hz, very fast decay.
    noise = rng.uniform(-1.0, 1.0, n).astype(np.float64)
    crack = _bandpass(noise, 1500.0, 3500.0) * _exp_decay(n, 0.015)
    # Sub-bass thump for visceral weight.
    sub = np.sin(2.0 * math.pi * 55.0 * t) * _exp_decay(n, 0.06)
    y = 0.55 * body + 0.40 * crack + 0.40 * sub
    return _normalize(y)


# ----------------------------------------------------------------------
# M3-T2-W1-T7 — phase-break + boss-wake stings
# ----------------------------------------------------------------------

def compose_phase_break(rng: np.random.Generator) -> np.ndarray:
    """Phase-break sting: tritone tension chord (~400 ms).

    Per `audio-direction.md` §"SFX — mobs" sfx-boss-phase-break row:
    "tritone tension chord ... hand-composed (cello + double-stop) — only
    acoustic source". Uma's spec is hand-composed cello but the M3 ship-
    acceptable bar permits algorithmic placeholder per Route 5 fallback.

    Tritone = augmented fourth = 6 semitones. We use D2 (73.42 Hz) + G#2
    (103.83 Hz) — the most dissonant interval inside the cello range,
    classically "the devil in music". Sustained 400 ms with a sharp
    attack and slow decay so the phase-break moment lands hard then
    bleeds into the world-time-slow window (T3, ships parallel).

    Fires on Stratum1Boss.phase_changed (signal emits once per boundary).
    """
    duration_s = 0.40
    n = int(SR * duration_s)
    t = _t(n)
    # Tritone bed: two cello-ish drones at D2 + G#2, harmonically rich.
    def _bowed(freq_hz: float, gain: float) -> np.ndarray:
        phase = 2.0 * math.pi * freq_hz * t
        # Sub-stack approximating bowed string: fundamental + 5 harmonics.
        h = (
            1.00 * np.sin(phase)
            + 0.55 * np.sin(2.0 * phase)
            + 0.35 * np.sin(3.0 * phase)
            + 0.18 * np.sin(4.0 * phase)
            + 0.10 * np.sin(5.0 * phase)
        )
        h = _lowpass(h, 1100.0)
        # Attack-heavy envelope: 30 ms attack, sustained at 80%, 150 ms release.
        env = np.zeros(n)
        a = int(SR * 0.030)
        r = int(SR * 0.150)
        s = max(0, n - a - r)
        env[:a] = np.linspace(0.0, 1.0, a, endpoint=False)
        env[a:a + s] = 0.80
        if r > 0:
            env[a + s:a + s + r] = np.linspace(0.80, 0.0, r, endpoint=False)
        return gain * h * env

    low = _bowed(73.42, gain=0.75)   # D2
    high = _bowed(103.83, gain=0.60)  # G#2 (tritone)
    # Bow-noise sheen: faint high-band noise for the rough-bow texture.
    noise = rng.uniform(-1.0, 1.0, n).astype(np.float64)
    sheen = _bandpass(noise, 2000.0, 4500.0) * np.exp(-t / 0.10) * 0.12
    y = low + high + sheen
    return _normalize(y)


def compose_boss_wake(rng: np.random.Generator) -> np.ndarray:
    """Boss-wake stinger: low brass note + impact stinger (~600 ms).

    Per `audio-direction.md` §"SFX — mobs" sfx-boss-aggro row + `boss-intro.md`
    §"Audio map" Beat 3: "low brass + impact stinger". The brass voice is
    intentionally rhymed with Beat F2 boss-kill-horn (also low brass) — the
    boss's entry and exit share a harmonic palette so the climax callbacks
    the intro.

    Brass note: A2 (110 Hz) fundamental with a fast attack and slow decay.
    Layered with a hand-impact (low body thump + brief high-band crack)
    for the "stone impact" tell — the boss stands up and the floor knows.

    Fires on Stratum1Boss.boss_woke.
    """
    duration_s = 0.60
    n = int(SR * duration_s)
    t = _t(n)
    # Brass note: A2 (110 Hz), rich harmonic stack, ADSR.
    phase = 2.0 * math.pi * 110.0 * t
    brass = (
        1.00 * np.sin(phase)
        + 0.65 * np.sin(2.0 * phase)
        + 0.45 * np.sin(3.0 * phase)
        + 0.28 * np.sin(4.0 * phase)
        + 0.15 * np.sin(5.0 * phase)
    )
    brass = _lowpass(brass, 950.0)
    # ADSR: 80 ms attack, 100 ms decay, 60% sustain, 350 ms release.
    a = int(SR * 0.080)
    d = int(SR * 0.100)
    r = int(SR * 0.350)
    s = max(0, n - a - d - r)
    env = np.zeros(n)
    env[:a] = np.linspace(0.0, 1.0, a, endpoint=False)
    env[a:a + d] = np.linspace(1.0, 0.60, d, endpoint=False)
    env[a + d:a + d + s] = 0.60
    if r > 0:
        env[a + d + s:a + d + s + r] = np.linspace(0.60, 0.0, r, endpoint=False)
    brass = brass * env * 0.70

    # Impact layer: heavy body thump + brief high-band crack at t=0.
    body = np.sin(2.0 * math.pi * 60.0 * t) * _exp_decay(n, 0.08)
    noise = rng.uniform(-1.0, 1.0, n).astype(np.float64)
    crack = _bandpass(noise, 1500.0, 3500.0) * _exp_decay(n, 0.020)
    impact = 0.55 * body + 0.35 * crack

    y = brass + impact
    return _normalize(y)


# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------

CUES = [
    ("audio/sfx/player/sfx-player-attack-light.ogg", compose_player_attack_light, 11),
    ("audio/sfx/player/sfx-player-attack-heavy.ogg", compose_player_attack_heavy, 12),
    ("audio/sfx/player/sfx-player-hit.ogg",          compose_player_hit,          13),
    ("audio/sfx/player/sfx-player-dodge.ogg",        compose_player_dodge,        14),
    ("audio/sfx/mobs/sfx-mob-hit.ogg",               compose_mob_hit,             21),
    ("audio/sfx/mobs/sfx-mob-die.ogg",               compose_mob_die,             22),
    ("audio/sfx/mobs/sfx-boss-die.ogg",              compose_boss_die,            23),
    ("audio/sfx/mobs/sfx-attack-telegraph.ogg",      compose_attack_telegraph,    24),
    ("audio/sfx/mobs/sfx-attack-impact.ogg",         compose_attack_impact,       25),
    # M3-T2-W1-T7 additions (86c9wjyak)
    ("audio/sfx/mobs/sfx-phase-break.ogg",           compose_phase_break,         31),
    ("audio/sfx/mobs/sfx-boss-wake.ogg",             compose_boss_wake,           32),
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
        print(f"[compose_sfx_m3w7] wrote {rel_path}  peak={peak_db:+.2f} dBFS  samples={len(mono)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
