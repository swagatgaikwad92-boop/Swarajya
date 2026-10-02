# Swarajya 0.1 — vertical slice

STAGE: Phase 0–2 combined into a playable slice.
GOAL: Map, armies, movement, combat, forts, AI, turns, victory/defeat, save/load.
WHAT WORKS: Main menu, new campaign, continue, 11 territories, 4 forts, two factions, movement, attack, recruitment, AI turn, income, supply tick, save/load, victory/defeat with historical comparison.

## How to run
1. Install Godot 4.3 or 4.4.
2. Import this folder (project.godot).
3. Press F5.
4. Project → Export → Android after installing export templates.

## Android
Package name to set in the export preset: com.swarajya.marathaage
Debug APK: Project → Export → Android → Export Project.
Install: adb install -r Swarajya.apk
or copy the APK to the phone and open it (allow unknown sources if prompted).

## Historical vs gameplay
All attack/defense/revenue/supply numbers are gameplay abstractions.
Fort histories and commander biographies are labelled. Confidence is medium on simplified campaign dating.
This scenario is not a reconstruction of the 1659 Pratapgad encounter.

## Test checklist
- [ ] Launch
- [ ] New campaign
- [ ] Select army territory
- [ ] Move to adjacent friendly/empty
- [ ] Attack
- [ ] Recruit
- [ ] End turn (AI acts)
- [ ] Save
- [ ] Continue from menu
- [ ] Victory or defeat panel shows both outcomes

## Known limitations
- Schematic positions, not a geographic coastline.
- One tactic (aggressive) exposed in UI.
- No fog of war, diplomacy, or pinch-zoom yet.
- Era II / III locked.
- AI is priority-based and intentionally simple.

## 0.2 additions
- Era select screen (II and III locked).
- Historical Atlas / Codex.
- Attack tactics: aggressive, defensive, harass.

## 0.3 additions
- Fog of war: unexplored territories show as Unknown. Owning or moving next to a territory reveals it.
- Diplomacy stub: offer peace (rejected while relation is low), declare war. AI will not attack during peace.
- Relation is a gameplay value, not a historical measurement.

## 0.4 additions
- Scroll wheel or pinch-style drag pans/zooms the map (mouse wheel, middle-drag, screen drag).
- Tribute (25 revenue, raises relation) and seek access (granted only if relation >= 0).
- While at peace with access, armies may enter enemy-owned empty territory without capturing it by attack. Entering still reveals fog.
- Era II data file added; scenario remains locked.

## 0.5 additions
- Playable Era II scenario: Cavalry into the Deccan (Peshwa abstraction, start ~1728).
- New map: 10 territories, 3 forts, factions Maratha / Nizam / Mughal remnant.
- Commanders Baji Rao I and Nizam-ul-Mulk.
- Campaign-specific victory/defeat and fog seeds.
- Era select starts either Era I or Era II.
- Historical notes still separated from gameplay numbers; Palkhed is referenced, not simulated.

## 0.6 additions
- Playable Era III: Houses under Pressure.
- Multi-faction AI for all non-player factions.
- Era select starts I, II, or III.
