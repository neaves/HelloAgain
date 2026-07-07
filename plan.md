# Hello Again — Addon Plan

## Original Objectives

Social familiarity tracker for **Project Ascension** (WotLK 3.3.5a). Builds a persistent,
cross-session database of player interactions, weighted into a **familiarity score**. Surfaces
that score passively so the player remembers who they've adventured with.

- Tooltip line on player inspect/hover: "Hello Again: Familiarity 47"
- Party join announcement in chat if score exceeds threshold
- Score built from weighted interaction events recorded automatically during play
- No manual input required; entirely passive observation

### Interaction Weights
| Event | Weight | Cooldown |
|---|---|---|
| Buff given to them | 5 | 5 min |
| Buff received from them | 5 | 5 min |
| Party join (either direction) | 10 | 5 min |
| Quest completion together | 10 | 5 min |
| Dungeon boss kill together | 20 | 5 min |

---

## Current Implementation State

All files are present and syntactically complete. The addon loads without errors. Core
infrastructure is in place but **has not been tested with live party members**.

### Files
```
HelloAgain/
├── HelloAgain.toc
├── HelloAgain.lua     — event frame, party diff, buff detection via CLEU
├── db.lua             — SavedVariables CRUD, rate limiting, score accumulation
├── score.lua          — weight table, announce threshold, cooldown constant
└── tooltip.lua        — GameTooltip hook
```

### SavedVariables (`HelloAgainDB`)
```
HelloAgainDB = {
  ["CharacterName"] = {
    score        = 142,
    interactions = [ { type, timestamp, weight }, ... ],
    lastSeen     = { [interactionType] = timestamp },
  }
}
```

### Events Registered
- `ADDON_LOADED` — init DB, snapshot current party
- `PARTY_MEMBERS_CHANGED` — diff party, record joins, announce if familiar
- `QUEST_COMPLETE` — record for all current party members (fires when quest screen appears)
- `COMBAT_LOG_EVENT_UNFILTERED` — buff_given/buff_received via SPELL_AURA_APPLIED; boss kills
  via UNIT_DIED inside instances

---

## Lessons Learned (from BuffMe session, applicable here)

### CLEU on Project Ascension
- Some Ascension custom spells emit **no CLEU events** at all. The `buff_given` path via
  `SPELL_AURA_APPLIED` will silently miss these spells. Consider supplementing with
  `UNIT_SPELLCAST_SUCCEEDED` + `UNIT_AURA` diff (as done in BuffMe) if coverage gaps appear.
- CLEU `sourceName` can be `nil` in some events. All uses of `sourceName` should guard with
  `or "?"` or an explicit nil check before recording interactions.
- Proc-sourced auras appear with `playerGUID` as source — the same problem BuffMe had with
  "Vitality Surge". `buff_given` should ideally also gate on UNIT_SPELLCAST_SUCCEEDED to avoid
  false-positive "we gave them a buff" records for passive procs.

### WotLK API
- `UnitBuff` does not return `unitCaster` reliably in all WotLK builds. The CLEU approach
  (checking `sourceGUID == playerGUID` in `SPELL_AURA_APPLIED`) is more reliable.
- `GetNumPartyMembers()` is the correct WotLK API (not `GetNumGroupMembers()`).
- `PARTY_MEMBERS_CHANGED` is the correct event (not `GROUP_ROSTER_UPDATE`).
- `IsInInstance()` returns `(inInstance, instanceType)` — `instanceType` can be `"party"`,
  `"raid"`, `"pvp"`, `"arena"`, or `"none"`.

### Boss kill detection
- `UNIT_DIED` fires for every NPC death in CLEU range, not just bosses. The current filter
  (inside an instance + destFlags not PLAYER) will record boss_kill for every non-player death
  in a dungeon — trash mobs included. This inflates scores. See Outstanding Goals #3.

### Data keying
- Characters are currently keyed by bare name (`"Leaves"`) with no realm suffix. This will
  cause cross-realm collisions if the server ever merges realms or if two players share a name
  across realms. The plan originally specified `"CharacterName-RealmName"` format. This is
  worth fixing before scores accumulate significantly.

---

## Outstanding Implementation Goals

### 1. Live party testing
The addon has never been used with real party members. First test goals:
- Verify tooltip appears on hovering a player character
- Verify party join announcement fires correctly when a known player joins
- Verify `buff_given` records when buffing a party member (requires BuffMe or manual /cast)
- Verify `QUEST_COMPLETE` fires reliably (it triggers when the quest completion screen appears,
  not on turn-in — may miss cases where the player skips reading the quest)

### 2. Key format: name → name-realm
Change the DB key from bare `"CharacterName"` to `"CharacterName-RealmName"` for robustness.
Use `UnitName("unit", true)` (the second argument returns the full name with realm suffix on
cross-realm contacts) when recording, and `UnitName(unit, true)` in the tooltip hook.
Fall back to bare name if the realm suffix is nil (same-realm character).

### 3. Boss kill precision
Replace the `UNIT_DIED` + "inside an instance" heuristic with a better signal. Options:
- Check `UnitClassification(destUnit)` for `"worldboss"` or `"rareelite"` — but the destUnit
  isn't available from CLEU directly
- Match `destName` against a known boss list — fragile, especially on Ascension
- Use `BOSS_KILL` event if the server emits it (fires specifically for boss deaths)
- Use `INSTANCE_ENCOUNTER_END` (fires at the end of an encounter) if available in WotLK

The simplest improvement: add a minimum health threshold check — bosses tend to have
significantly more health than trash. Requires tracking destGUID health, which is expensive.
Best near-term fix: register `BOSS_KILL` event and fall back to UNIT_DIED only if it doesn't
fire.

### 4. Score decay
Familiarity scores only ever increase. A player encountered briefly years ago retains their
score permanently. Options:
- Time-weighted decay: multiply old interactions by a decay factor on each DB access
- Hard cap: ignore interactions older than N days when computing the display score
- Simple: display score = sum of interactions in the last 90 days only (don't change storage)

Recommended: compute the score on the fly from the `interactions` array using a 90-day window,
rather than storing a running total. The stored `score` field then becomes a cached value,
recalculated on load or on explicit invalidation.

### 5. Config panel
No Interface > AddOns panel exists yet. Minimum viable config:
- Announce threshold slider or input (currently hardcoded at 10)
- Toggle: enable/disable party join announcements
- "Reset Database" button (same pattern as BuffMe)
- Optionally: list of top N most familiar characters

### 6. In-game familiarity browser
A slash command (`/helloagain` or `/ha`) that lists the top 10 most familiar characters by
score. Useful for verifying the DB is building correctly and for player curiosity.

### 7. Proc guard for buff_given
Mirror BuffMe's `recentlyCastName` approach: only record `buff_given` when CLEU
`SPELL_AURA_APPLIED` on a party member is paired with a preceding `UNIT_SPELLCAST_SUCCEEDED`
for the same spell name. Prevents proc-sourced buffs from generating false familiarity credit.

### 8. BuffMe integration
If BuffMe is loaded, HelloAgain can hook into successful buff casts to record `buff_given`
without duplicating CLEU monitoring. Pattern:
```lua
-- In BuffMe.lua, after a successful cast is confirmed:
if HelloAgain_AddInteraction then
    HelloAgain_AddInteraction(targetName, "buff_given", 5)
end
```
This gives HelloAgain higher-confidence data than CLEU alone (already filtered by BuffMe's
proc guard and active-cast gate).

### 9. UNIT_SPELLCAST_SUCCEEDED supplement for buff tracking
For CLEU-less spells (same class of problem as Grove Instinct in BuffMe), buff_given will never
fire via CLEU. Supplement with a `UNIT_SPELLCAST_SUCCEEDED` + `UNIT_AURA` check on party
members: if the player just cast spell X and a party member gained a new buff matching that
spell name, record `buff_given`. Lower priority until CLEU gaps are confirmed as a real problem
in testing.
