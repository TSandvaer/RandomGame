# PixelLab Animation Dispatch Queue (M3 batch)

Tracked across away-mode ticks. Each tick: check this file, dispatch the next `pending` item if slots free.

## Character IDs

- Player: `a6eddc72-3256-44c8-81e9-51065cd0e5ac`
- Grunt v2: `e92d6924-44b3-4968-a3fd-ee5aecfe5ea5`
- Charger: `a114419e-23e9-43c8-bb47-4ef8eb21cc61`
- Shooter eye-variant: `10c0e95f-ab8b-434a-bb50-3e29429f2030`
- Boss eye-variant: `80a555b9-a2cc-4b81-b66b-f9de61415e4c`
- PracticeDummy: `02471680-be01-4bd1-9420-1909565062fd`
- NPC Vendor: `d3d753c3-d9b7-4b44-8515-1ec99ca498c4`
- NPC Anvil-keeper: `2a2da74d-c6c0-4a60-a0e3-ae6b50fa74ff`
- NPC Bounty-poster: `70806893-cd64-4e7d-b8ae-d01954e2cced`

## Queue

| Status | Character | Template | Animation Name |
|---|---|---|---|
| done | Player | walking-4-frames | player-walk |
| done | Player | lead-jab | player-attack-light |
| done | Player | cross-punch | player-attack-heavy |
| done | Player | running-slide | player-dodge |
| done | Player | taking-punch | player-hit |
| done | Player | falling-back-death | player-die |
| done | Grunt v2 | scary-walk | grunt-walk |
| done | Grunt v2 | fight-stance-idle-8-frames | grunt-attack-telegraph |
| done | Grunt v2 | cross-punch | grunt-attack |
| done | Grunt v2 | taking-punch | grunt-hit-react |
| done | Grunt v2 | falling-back-death | grunt-die |
| done | Charger | running-4-frames | charger-walk |
| done | Charger | angry | charger-attack-telegraph |
| done | Charger | jump-attack | charger-attack |
| done | Charger | going-to-sleep | charger-die |
| done | Shooter eye-variant | sad-walk | shooter-walk |
| done | Shooter eye-variant | picking-up | shooter-attack-telegraph |
| done | Shooter eye-variant | throw-object | shooter-attack |
| done | Shooter eye-variant | taking-punch | shooter-hit-react |
| done | Shooter eye-variant | falling-back-death | shooter-die |
| done | Boss eye-variant | walking-8-frames | boss-walk |
| done | Boss eye-variant | fight-stance-idle-8-frames | boss-attack-telegraph-A |
| done | Boss eye-variant | roundhouse-kick | boss-attack-A |
| done | Boss eye-variant | pushing | boss-attack-telegraph-B |
| done | Boss eye-variant | surprise-uppercut | boss-attack-B |
| done | Boss eye-variant | taking-punch | boss-hit-react |
| done | Boss eye-variant | falling-back-death | boss-die |
| done | PracticeDummy | taking-punch | dummy-hit-react |
| done | PracticeDummy | falling-back-death | dummy-die |
| done | NPC Vendor | breathing-idle | vendor-talk |
| done | NPC Anvil-keeper | breathing-idle | anvil-talk |
| done | NPC Bounty-poster | breathing-idle | bounty-talk |

## Tick protocol

1. Check `mcp__pixellab__list_characters` — find the `in flight` row in this table
2. Verify its animation appears in that character's `Animations (N)` list count (means done)
3. If done: edit this file, mark in-flight row `done`, then dispatch next `pending` row + mark it `in flight`
4. If not done yet: skip dispatch, just update last_tick
5. Only ONE animation can be in flight at a time on Tier 1 (8 slots; an 8-direction animate call needs all 8)

---

## Follow-ups (next session)

- **Implement `auto-pixellab` skill** at `~/.claude/skills/auto-pixellab/SKILL.md` mirroring auto-status structure. State file at `.claude/auto-pixellab.state`. Independent on/off so it doesn't pollute auto-status pulse cadence. Move PixelLab dispatch-advancement logic out of auto-status away. Sponsor decision 2026-05-17 (option B: defer implementation, finish current PixelLab work first).
- **Inspect Player walking-8-frames south frames** (re-roll for flip fix) before deciding whether to swap walking-4-frames south with walking-8-frames south OR re-roll yet another template.
