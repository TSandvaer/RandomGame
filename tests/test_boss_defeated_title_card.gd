extends GutTest
## M3-T4 — defeat title card unit tests.
##
## Per Uma's brief §6 note 3 — paired GUT pin is **structural** only:
## label existence, copy correctness, templating, idempotence. Tween-timing
## tests are HTML5-renderer-fragile and live in the Playwright spec
## instead (`tests/playwright/specs/boss-defeat-title-card.spec.ts`).
##
## **Bug class this catches.** If a future refactor breaks one of:
##   1. `show_for(boss)` doesn't update title text from `display_name`
##   2. Subtitle drifts from "STRATUM 1 CLEARED"
##   3. The CanvasLayer instantiates outside the post-HUD layer band
##   4. `mouse_filter` regresses from IGNORE (would absorb clicks meant
##      for the loot Pickup that drops UNDER the card per Uma §3)
##   5. Title-templating fallback fails on a null / empty / unusual boss
## …this test bounces in headless CI before the visual gate ever sees it.
##
## **What this test does NOT cover** (intentional — see Playwright spec):
##   - Tween timing (game-time delays, fade-in duration). Renderer-fragile.
##   - Boss-defeated signal end-to-end wire from Stratum1BossRoom → Main →
##     card instantiation. Covered by the Playwright HTML5 spec.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const BossDefeatedTitleCardScript := preload("res://scripts/ui/BossDefeatedTitleCard.gd")
const BOSS_CARD_SCENE_PATH: String = "res://scenes/ui/BossDefeatedTitleCard.tscn"

var _warn_guard: NoWarningGuard


# ---- Lifecycle --------------------------------------------------------

func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Helpers ----------------------------------------------------------

func _make_card() -> BossDefeatedTitleCard:
	var packed: PackedScene = load(BOSS_CARD_SCENE_PATH) as PackedScene
	assert_not_null(packed, "BossDefeatedTitleCard.tscn must load")
	var card: BossDefeatedTitleCard = packed.instantiate() as BossDefeatedTitleCard
	add_child_autofree(card)
	return card


## Minimal boss stub — exposes a `mob_def`-shaped object with a
## `display_name`. The card's `resolve_short_name` tolerates both
## typed-Stratum1Boss + duck-typed stubs.
class FakeMobDef:
	var display_name: String


class FakeBoss extends Node:
	var mob_def: FakeMobDef = null


func _make_fake_boss(display_name: String) -> FakeBoss:
	var fb: FakeBoss = FakeBoss.new()
	var fd: FakeMobDef = FakeMobDef.new()
	fd.display_name = display_name
	fb.mob_def = fd
	add_child_autofree(fb)
	return fb


# ---- Spec test 1: scene loads and structure is right -----------------

func test_title_card_scene_loads() -> void:
	var packed: PackedScene = load(BOSS_CARD_SCENE_PATH)
	assert_not_null(packed, "BossDefeatedTitleCard.tscn must load")
	var instance: Node = packed.instantiate()
	assert_true(instance is BossDefeatedTitleCard, "root is BossDefeatedTitleCard typed")
	instance.free()


func test_title_card_has_root_control_and_two_labels() -> void:
	var card: BossDefeatedTitleCard = _make_card()
	assert_not_null(card.get_root_control(), "root Control exists")
	assert_not_null(card.get_title_label(), "title Label exists")
	assert_not_null(card.get_subtitle_label(), "subtitle Label exists")


func test_canvas_layer_above_hud() -> void:
	# HUD lives at layer <= 49; the card sits at 50 per Uma §1 so it draws
	# above HUD elements during the fade.
	var card: BossDefeatedTitleCard = _make_card()
	assert_gte(card.layer, 50, "card CanvasLayer >= 50")


func test_root_mouse_filter_is_ignore() -> void:
	# Loot drops UNDER the card during the hold phase (Uma §3 — T+1.6 loot
	# drop). The Root must pass clicks through to the Pickup beneath.
	var card: BossDefeatedTitleCard = _make_card()
	assert_eq(card.get_root_control().mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"Root Control mouse_filter is IGNORE")


# ---- Spec test 2: copy locks ------------------------------------------

func test_subtitle_text_is_locked_constant() -> void:
	var card: BossDefeatedTitleCard = _make_card()
	assert_eq(card.get_subtitle_label().text, BossDefeatedTitleCardScript.SUBTITLE_TEXT,
		"subtitle text matches authoritative constant")
	assert_eq(BossDefeatedTitleCardScript.SUBTITLE_TEXT, "STRATUM 1 CLEARED",
		"subtitle copy is locked — 'STRATUM 1 CLEARED'")


func test_title_template_includes_period() -> void:
	# Period at end is intentional — declarative sentence, not banner
	# (Uma §1). If this drifts the tonal register breaks.
	assert_eq(BossDefeatedTitleCardScript.TITLE_TEMPLATE, "The %s falls.",
		"title template includes trailing period")


# ---- Spec test 3: display_name templating ----------------------------

func test_show_for_templates_title_from_warden_display_name() -> void:
	# Real boss spec: `display_name = "Warden of the Outer Cloister"` →
	# rendered title `The Warden falls.` per Uma §6 note 1.
	var card: BossDefeatedTitleCard = _make_card()
	var boss: FakeBoss = _make_fake_boss("Warden of the Outer Cloister")
	card.show_for(boss)
	assert_eq(card.get_title_label().text, "The Warden falls.",
		"first-word templating produces 'The Warden falls.'")


func test_show_for_templates_title_from_alternate_display_name() -> void:
	# Future-boss probe — proves the templating is not hard-coded to
	# "Warden". Per Uma §6 note 1 this is the rule that scales across
	# M2/M3 bosses without per-boss copy fields.
	var card: BossDefeatedTitleCard = _make_card()
	var boss: FakeBoss = _make_fake_boss("Stoker of Vault Forge")
	card.show_for(boss)
	assert_eq(card.get_title_label().text, "The Stoker falls.",
		"first-word templating produces 'The Stoker falls.' for non-Warden bosses")


func test_show_for_handles_single_word_display_name() -> void:
	# Single-word boss name → no whitespace to split. Should fall back to
	# the single word unmodified.
	var card: BossDefeatedTitleCard = _make_card()
	var boss: FakeBoss = _make_fake_boss("Vorgath")
	card.show_for(boss)
	assert_eq(card.get_title_label().text, "The Vorgath falls.",
		"single-word display_name renders unmodified")


func test_show_for_falls_back_on_null_boss() -> void:
	# Defensive — if a future caller passes null, the card should still
	# render a sensible title, not crash or render "The %s falls.".
	var card: BossDefeatedTitleCard = _make_card()
	card.show_for(null)
	assert_eq(card.get_title_label().text, "The Warden falls.",
		"null boss falls back to 'Warden' literal")


func test_show_for_falls_back_on_empty_display_name() -> void:
	var card: BossDefeatedTitleCard = _make_card()
	var boss: FakeBoss = _make_fake_boss("")
	card.show_for(boss)
	assert_eq(card.get_title_label().text, "The Warden falls.",
		"empty display_name falls back to 'Warden' literal")


# ---- Spec test 4: idempotence + signal ordering ----------------------

func test_show_for_is_idempotent_within_one_card_life() -> void:
	# Card should only kick its tween once. Stratum1BossRoom emits
	# `boss_defeated` exactly once per fight (the room's deferred guards
	# enforce this), but a second call is a no-op anyway.
	var card: BossDefeatedTitleCard = _make_card()
	var boss: FakeBoss = _make_fake_boss("Warden of the Outer Cloister")
	card.show_for(boss)
	assert_true(card.is_shown(), "first show_for marks shown=true")
	# Second call with a different boss must NOT overwrite the title
	# (idempotence guard fires before _apply_title_text_from_boss).
	var second: FakeBoss = _make_fake_boss("Vorgath")
	card.show_for(second)
	assert_eq(card.get_title_label().text, "The Warden falls.",
		"second show_for is a no-op — title text NOT overwritten")


# ---- Spec test 5: visual color targets are HTML5-safe ----------------

func test_title_color_is_off_white_html5_safe() -> void:
	# Per html5-export.md HDR clamp rule — every channel sub-1.0. Title is
	# off-white #E8E4D6 per Uma §1 / palette.md:24. Crucially NOT
	# (1.4, 1.0, 0.7) which would clamp on WebGL2 to (1.0, 1.0, 0.7).
	var c: Color = BossDefeatedTitleCardScript.TITLE_COLOR
	assert_lt(c.r, 1.0, "title.r strictly sub-1.0 (HDR-safe)")
	assert_lt(c.g, 1.0, "title.g strictly sub-1.0")
	assert_lt(c.b, 1.0, "title.b strictly sub-1.0")
	# Off-white shape — green & blue channels close to red but slightly cooler.
	assert_gt(c.r, 0.85, "title.r is bright (off-white range)")


func test_subtitle_color_is_muted_parchment() -> void:
	# Per Uma §1 — subtitle is muted parchment #B8AC8E. It must recede
	# relative to the off-white title; if a future refactor flips them to
	# the same value the visual hierarchy breaks.
	var c: Color = BossDefeatedTitleCardScript.SUBTITLE_COLOR
	var title: Color = BossDefeatedTitleCardScript.TITLE_COLOR
	assert_lt(c.r, title.r, "subtitle is dimmer than title")
	assert_lt(c.g, title.g, "subtitle green dimmer than title")
	assert_lt(c.b, title.b, "subtitle blue dimmer than title")


# ---- Spec test 6: timing constants match Uma's locked spec -----------

func test_pre_fade_delay_is_one_two_seconds() -> void:
	# Per Uma §3 timeline — card starts fading at T+1.2 game-time post
	# `boss_defeated`. If this drifts the card lands during the horn or
	# during the ember dissolve, both of which break the silence beat.
	assert_almost_eq(BossDefeatedTitleCardScript.PRE_FADE_DELAY, 1.2, 0.001,
		"pre-fade delay locked to 1.2 s game-time")


func test_fade_durations_are_locked() -> void:
	# Per Uma §1 — symmetric 0.4 s + 0.8 s + 0.4 s = 1.6 s on screen.
	assert_almost_eq(BossDefeatedTitleCardScript.FADE_IN_DURATION, 0.4, 0.001,
		"fade-in duration locked to 0.4 s")
	assert_almost_eq(BossDefeatedTitleCardScript.HOLD_DURATION, 0.8, 0.001,
		"hold duration locked to 0.8 s")
	assert_almost_eq(BossDefeatedTitleCardScript.FADE_OUT_DURATION, 0.4, 0.001,
		"fade-out duration locked to 0.4 s")


# ---- Spec test 7: regression-guard — card wires to room signal -------

func test_card_layer_separate_from_descend_screen() -> void:
	# DescendScreen sits on layer >= 100 (`test_descend_screen.gd:58`).
	# The defeat card runs BEFORE descend (T+0.0 → T+2.8 vs descend at
	# T+2.4+) — if both ever live in the tree simultaneously, the
	# descend screen must paint over the card. Different layers enforce
	# this ordering.
	var card: BossDefeatedTitleCard = _make_card()
	assert_lt(card.layer, 100,
		"card CanvasLayer < DescendScreen (100) so descend paints over card")
