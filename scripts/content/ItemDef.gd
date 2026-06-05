class_name ItemDef
extends Resource
## Designer-authored item template. Immutable at runtime — `LootRoller`
## produces an `ItemInstance` from this def with rolled tier/affixes.
## See `team/drew-dev/tres-schemas.md`.

## Equipment slot the item fits. M1 only uses WEAPON and ARMOR.
enum Slot { WEAPON, ARMOR, OFF_HAND, TRINKET, RELIC }

## Tier — drives drop level, base-stat magnitude, affix count, and color in
## UI. Per game-concept.md: T1 worn (0 affixes), T2 common (1), T3 fine (1–2),
## T4 rare (2–3), T5 heroic (3), T6 mythic (3 + set). M1 ships T1–T3 only.
enum Tier { T1, T2, T3, T4, T5, T6 }

## WeaponClass — drives the player's body attack-SET selection (the "punch vs
## swing" felt read, `team/uma-ux/visible-equipment-system.md §2`). FIST is the
## implicit class when no weapon is equipped (the `_equipped_weapon == null`
## branch already in `Damage.compute_player_damage`); it never needs a `.tres`.
## ONE_HAND_MELEE is the default so existing weapon `.tres` files (`iron_sword`)
## read as 1H with no edit. M3 ships FIST + ONE_HAND_MELEE; the rest are forward
## hooks the 3-layer rig generalizes to (Warden two-hander, S2 staff, future bow).
enum WeaponClass { FIST, ONE_HAND_MELEE, TWO_HAND_MELEE, STAFF, RANGED }

## Stable identifier (snake_case, unique).
@export var id: StringName = &""

@export var display_name: String = ""

@export var slot: Slot = Slot.WEAPON

@export var tier: Tier = Tier.T1

## Weapon class — selects the player body's attack-SET (fist-punch vs 1H-swing)
## per `team/uma-ux/visible-equipment-system.md §2 / §7 step 1`. Default
## ONE_HAND_MELEE is back-compat: every existing WEAPON `.tres` reads as 1H
## without an edit. Ignored for non-WEAPON slots (armor/trinket/etc. have no
## attack-SET). FIST is never authored here — it is the runtime class when
## `_equipped_weapon == null` (see `Player._resolve_attack_set`).
@export var weapon_class: WeaponClass = WeaponClass.ONE_HAND_MELEE

@export_file("*.png") var icon_path: String = ""

## Wrapped in a sub-resource for inspector grouping + future-proofing.
@export var base_stats: ItemBaseStats

## Allowed affixes for this item. The roller picks N from this pool with no
## duplicates per item. Empty for T1 (0 affixes by spec).
@export var affix_pool: Array[AffixDef] = []
