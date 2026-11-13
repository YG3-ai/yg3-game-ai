# Chapter 01 — Train a Game Combat Agent: From Scripted Policy to Neural Policy

This chapter uses the same desert dunes and abandoned city layout as YG3's Level 0 game prototype. Vita is the player character. An animated enemy approaches, punches, and can dodge rifle fire. Both use Godot physics bodies and animation clips.

## Requirements

- Godot 4.7.2
- Python 3.10 or newer; no Python packages required
- Git LFS to download the example GLBs

## Run

From this directory:

```sh
python3 train.py
godot --path . -- --scripted-combat
godot --path . -- --neural-combat
godot --headless --path . -- --eval
```

The first two runs show the scripted teacher and neural policy in the same level. The evaluation runs six paired six-second episodes at three starting distances and prints a JSON summary. If Godot is installed as a macOS app, open `project.godot` in the editor or run its executable with these arguments. Launching without a flag leaves Vita under manual control.

## What gets trained

`train.py` samples 1,800 structured combat states, labels them with `teacher_action()`, and trains a 9→24→5 feed-forward network with stochastic gradient descent. Its output is `weights/combat_mlp.json`. The Godot loader reads the same feature order and output heads: movement choice, fire, dodge.

This is **teacher distillation**, not reinforcement learning or a visual policy. The network sees privileged game state such as distance, action clocks, enemy attack state, and health. It does not see RGB. The original private experiment also tuned a few teacher timings through short real-game episodes; this chapter uses those timings as explicit defaults and focuses on reproducing the distillation and paired evaluation.

The three held-out start distances are a small smoke evaluation, not proof of broad generalization. Watch for successful actions and failure cases, not only synthetic imitation accuracy.

In the first local six-episode check, the teacher and MLP each averaged 66 points and 60 damage dealt, with no damage taken. They won different individual starting distances. These figures describe this one run; the meaningful exercise is to rerun the comparison after you change the agent or game.

## Bring your own assets

You can keep the AI code and replace Vita's model in `scenes/characters/vita.tscn` and the opponent model in `scenes/enemies/meshy_space_enemy.tscn`. Their `CharacterBody3D`, collision shape, and `VisualPivot/Model` structure form the adapter. Update the model's scale and facing direction if necessary.

The current Vita controller expects an `AnimationPlayer`, a Mixamo-style hips bone, the listed movement/dodge/hit animations, and a rifle node named `eden_rifle_v001`. The enemy expects `Walking`, `Running`, `Punch_Combo`, and `Roll_Dodge`. If your assets use different names, map them in `scripts/vita_controller.gd`, `scripts/rifle_actions.gd`, and `scripts/enemy_controller.gd`. You can instead animate procedural characters, provided you keep the action and observation contracts intact. Set your own collision heights, punch range, firing origin, timings, and camera framing, then retrain and rerun evaluation. The included weights will not transfer unchanged to a different game.

Follow the [adaptation walkthrough](ADAPT_YOUR_GAME.md) for the exact feature order, action meanings, asset hooks, retraining steps, and checks to run in your own game.

## Project map

- `scenes/levels/level_0.tscn`: desert and ruins layout, Vita and enemy instances.
- `scripts/level_0.gd`: spawning, HUD, and episode mode selection.
- `scripts/autonomous_combat_policy.gd`: readable scripted teacher.
- `train.py`: synthetic state sampler, teacher labels, neural training.
- `scripts/neural_combat_policy.gd`: inference and action application.
- `scripts/evaluate.gd`: matched real-game evaluation.

The next chapter will capture timestamped trajectories and synchronized camera observations. Later chapters will tackle vision, memory, and world models.
