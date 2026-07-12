# Remember Me

A social familiarity tracker for [Project Ascension](https://ascension.gg).

Remember Me builds a persistent database of your interactions with other players and surfaces a **familiarity score** wherever you encounter them — in tooltips when you target or mouse over a character, and as a party-chat announcement when a known adventurer joins your group.

## Features

- Tracks buff exchanges, party invites, quest completions, and dungeon/raid boss kills
- Familiarity score persists across sessions via SavedVariables
- Tooltip integration: hover over any player to see your history with them
- Party join announcement: *"You've adventured with Thrall before! (Familiarity: 47)"*
- Rate-limited recording (same interaction counts at most once per 5 minutes per character)

## Interaction Weights

| Event | Score |
|---|---|
| Buff given / received | +5 |
| Party invite | +10 |
| Quest completion together | +10 |
| Boss / instance kill together | +20 |

## Installation

Copy the `RememberMe` folder into your WoW AddOns directory:

```
<WoW>/Interface/AddOns/RememberMe/
```

Enable **Remember Me** on the AddOns screen at character select.

## Compatibility

Built for the **Project Ascension** client (WoW 3.3.5a, Interface 30300).
