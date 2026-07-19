# Behavior Graph System

The node-graph condition editor for the ant colony sim, fully integrated
with the runtime resource library. The standalone prototype (`behavior_builder.tscn`)
is gone; graphs are now authored inside the game through the Behavior Designer.

## Opening the editor

Main menu → **Behavior Designer** (or the sandbox debug menu → **Designer**),
select the Behaviors kind, then **New** / **Edit** / double-click. The editor
(`BehaviorGraphEditorPopup`) shows the behavior form (name / action / priority /
enabled) above an embedded graph canvas (`BBGraphPanel`). The graph **is** the
condition: wire it into the single ⚡ Output node.

## Semantics

- **Types**: cyan ports carry floats, orange carry bools; GraphEdit only wires
  matching types. Lists (👁 Sense → filter/sort/pick/item value/count) flow
  through the purple pipeline nodes.
- **Unknown**: an unwired input is `null`. AND/OR ignore unknown inputs; a rule
  gated on an unknown condition never fires.
- **Empty graph**: behavior has no condition → always fires. A behavior with a
  legacy raw-expression condition keeps it while the graph stays empty (gold
  banner explains); wiring any node replaces it on save.
- **⏱ Hold true** latches a condition for N seconds. Do not put STICKY or EVENT
  eval policies on graphs containing timers — the cached value never expires,
  so holds freeze (see `GraphLogic` docs).
- **Ctrl+G** collapses a selection into a named, reusable ◈ condition/value.
  Saves are by-reference: every ◈ node resolves by name at read time.

## Persistence & validation

Graphs persist as `GraphLogic` resources (KIND_LOGIC) under
`user://behavior/expressions/` via `BBGraphLibrary` — same unified catalog,
never-clobber seeding, and manifest-tracked deletions as every other behavior
resource. `graph_data` is the runtime truth; `expression_string` stays empty
by design. Three validation gates (`BBGraphValidator`, mirroring
LogicValidator's doctrine): live on every edit, at save, and at first
evaluation.

## File map

| File | Role |
|---|---|
| `bb_vocabulary.gd` | Single source of truth for world keys / list sources / item properties |
| `bb_eval.gd` | Pure graph evaluation (editor previews AND the live sim) |
| `graph_validator.gd` | Closed-whitelist validation of serialized graphs |
| `graph_library_bridge.gd` | `BBGraphLibrary` — ResourceLibrary-backed ◈ library |
| `graph_logic.gd` | `GraphLogic extends Logic` — the runtime resource |
| `ant_world_adapter.gd` | Live-ant world implementation |
| `world_state.gd` | Mock slider world for authoring without a running sim |
| `builder_settings.gd` | Grid/snap prefs (`user://behavior_builder_settings.json`) |
| `graph_panel.gd` | `BBGraphPanel` — the embeddable canvas + side panel |
| `behavior_graph_editor_popup.gd` | The Behavior Editor window hosting the panel |
| `nodes/` | GraphNode visuals shared by the canvas |
