# Behavior Builder (Godot)

A node-graph "do ACTION if CONDITION" prototyping UI for the ant colony sim.
Built on `GraphEdit`/`GraphNode`. **Requires Godot 4.2+.**

## Install

1. Copy the `behavior_builder/` folder into your project (`res://behavior_builder/`).
2. Open and run `behavior_builder.tscn` (F6). A seeded demo graph loads:
   `health < 30 AND enemy_dist < 25 → BEHAVIOR`.
3. Drag Health below 30 and Enemy distance below 25 in the side panel — the
   BEHAVIOR node flashes, counts the fire, and prints to Output.

## Controls

| Action | How |
|---|---|
| Add a node | Right-click empty graph space |
| Wire | Drag port → port (one wire per input; new wire replaces old) |
| Create + auto-connect | Drag a wire into empty space → pick a node from the menu |
| Auto-compose | Drop a node **on top of** another node → wires into a free input |
| Multi-select | Box-drag or Ctrl+click |
| Save selection as named condition | **Ctrl+G** (selection shrinks into one ◈ node) |
| Peek inside a condition | **👁** button on the node (expand/collapse, live values inside) |
| Edit a saved condition | Right-click the ◈ node → **Unpack into graph**, edit, Ctrl+G again |
| Copy a node's debug JSON | **⧉** button, or select + **Ctrl+Shift+C** |
| Copy the whole graph as JSON | "Copy graph JSON" in the toolbar |
| Copy / paste / duplicate / delete | Ctrl+C / Ctrl+V / Ctrl+D / Del |
| Reuse a condition | Double-click it in the library panel, or right-click menu → Saved conditions |

## Semantics

- **Types**: cyan ports carry floats, orange ports carry bools. GraphEdit only
  lets you wire matching types.
- **Unknown**: an unwired input is `null` ("unknown"). AND/OR ignore unknown
  inputs; a node with no usable inputs shows `= —`. Wires carrying TRUE light up.
- **AND/OR growth**: whenever every input is wired, a fresh free port appears;
  trailing free ports collapse back. There's always exactly one open slot.
- **Conditions must be self-contained**: they can contain world values,
  constants, comparisons, logic, and *other conditions* (nesting is fine —
  cycles are detected and evaluate as unknown). Wires coming *into* the
  selection from outside are dropped on save, with a warning toast.
- **Saving is by-reference**: condition nodes look their definition up in the
  library by name, so overwriting a condition updates every instance.

## Files

```
behavior_builder.tscn      minimal host scene
behavior_builder.gd        controller: UI, menus, save/unpack, evaluation loop
world_state.gd             slider-backed world snapshot (edit FIELDS to add more)
condition_library.gd       named serialized subgraphs; persists to user://behavior_conditions.json
bb_eval.gd                 pure evaluation engine (no UI dependencies)
nodes/bb_node.gd           base GraphNode (ports, value display, debug button)
nodes/world_value_node.gd  world state reader (float out)
nodes/constant_node.gd     literal number (float out)
nodes/compare_node.gd      A op B → bool (inline B or wired B)
nodes/logic_node.gd        AND / OR / NOT with auto-growing inputs
nodes/condition_node.gd    collapsed reusable condition + eyeball preview
nodes/behavior_node.gd     action stub — flashes/counts/prints on rising edge
```

## Hooking into the actual game later

`BBEval` has zero UI dependencies. The library persists plain JSON, so your
ants can evaluate authored conditions directly:

```gdscript
var result = BBEval.eval_condition("EnemyNearby", ant_world_state, library)
```

Give `ant_world_state` anything with a `get_value(key) -> float` method (an
adapter over your entity components) and the exact graphs you author here run
in-game. Replace `BBBehaviorNode`'s stub with real action nodes when you're
ready — everything upstream of the WHEN port stays the same.

## Notes

- The 👁 / ⧉ glyphs are consts (`GLYPH_EYE`, `GLYPH_COPY`) at the top of
  `nodes/bb_node.gd` — swap them if your font renders boxes.
- Debug JSON includes the node's params, current value, its full input tree,
  and a world snapshot — paste it straight into a chat to debug together.
