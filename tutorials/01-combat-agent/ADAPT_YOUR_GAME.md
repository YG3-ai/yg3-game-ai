# Adapt the combat agent to your game

There are two useful starting points. If you want to see **your art in this arena**, swap the model scenes and keep the combat rules. If you want the AI to control **your own game**, connect its state and actions to the same small interface, then retrain against your rules. A GLB swap changes appearance; it does not teach the network new behavior.

## 1. Reproduce the reference first

Clone with Git LFS installed (`git lfs install` before cloning, or `git lfs pull` afterward). In `tutorials/01-combat-agent`, run `python3 train.py`, then run Godot with `-- --scripted-combat`, `-- --neural-combat`, and `-- --eval` as shown in the chapter README. Compare the generated `weights/combat_mlp.json` with the tracked version if you change the trainer. The `seed` and `synthetic_accuracy` fields make a quick sanity check.

For a video walkthrough, watch the [scripted](../../media/vita-scripted.mp4) and [neural](../../media/vita-neural.mp4) eight-second clips. They show the same desert encounter with different decision makers.

## 2. Replace the visuals in this arena

In `scenes/characters/vita.tscn`, keep the `CharacterBody3D`, `CollisionShape3D`, `VisualPivot`, camera rig, and node path `VisualPivot/Model`. Replace the instance at `Model` with your imported character scene. In `scenes/enemies/meshy_space_enemy.tscn`, do the same for the enemy's `VisualPivot/Model`. Keep an actor scale close to the collision capsule first; adjust the capsule once the model is correctly placed. Do not edit the desert level scene to swap a model.

The player controller currently looks for a `Skeleton3D` with a `mixamorig_Hips` bone and an `AnimationPlayer` with these clips: `Short_Breathe_and_Look_Around`, `Walking_Woman`, `Running`, `Jump_Run`, `Roll_Dodge_1`, `_360_Power_Spin_Jump`, `Walk_Forward_While_Shooting`, `Walk_Backward_While_Shooting_inplace`, `Run_and_Shoot`, and `Hit_Reaction`. The enemy needs `Walking`, `Running`, `Punch_Combo`, and `Roll_Dodge`. Map different clip names in `scripts/vita_controller.gd` or `scripts/enemy_controller.gd`; the assertions in their `_ready()` functions identify missing clips immediately.

`scripts/rifle_actions.gd` looks for a visual node named `eden_rifle_v001`, a `Muzzle` under it, and the `mixamorig_RightHand` bone. Rename those lookups for your own rig and weapon. If you have no visible rifle yet, keep a simple marker for the firing origin and adapt the script before running the scene. Test manual movement and shooting before testing AI control.

## 3. Connect a different game's observations

The neural policy builds this nine-element array in `scripts/neural_combat_policy.gd`, in exactly the order consumed by `train.py`:

| Index | Value | Normalization |
| --- | --- | --- |
| 0 | Horizontal enemy distance | metres / 9, clamped to 0–1 |
| 1 | Enemy punch clock | seconds / 1.5, clamped |
| 2 | Player dodge cooldown | seconds / 2, clamped |
| 3 | Player fire clock | seconds / 1.2, clamped |
| 4 | Enemy aim clock | seconds, clamped to 0–1 |
| 5 | Enemy is punching | 0 or 1 |
| 6 | Enemy is dodging | 0 or 1 |
| 7 | Player health / maximum health | 0–1 |
| 8 | Enemy health / maximum health | 0–1 |

Feature order and scale are part of the model contract. If your game lacks one of these signals, decide what replaces it and change both the Godot feature builder and Python sampler. Do not silently feed a different meaning into an old weight file. These values include privileged state; a later chapter will cover visual observations.

## 4. Connect your actions and teacher

The network returns five numbers. Outputs 0–2 compete to choose **retreat**, **strafe**, or **advance**. Output 3 is a fire probability; output 4 is a dodge probability. `scripts/neural_combat_policy.gd` turns those choices into a world-space movement vector plus fire and dodge requests through `set_combat_command()` in the player controller. The scripted policy in `scripts/autonomous_combat_policy.gd` calls the same method. Preserve that shared action boundary when you port to your game.

`teacher_action()` in `train.py` labels sampled states using the simple distance, fire-timing, and punch-response rules. If your weapon, enemy, or dodge timing differs, update this teacher and the state sampler. The current training examples are **synthetic states labeled by the script**, not trajectories captured from play. To learn something beyond the teacher, you will need new supervision or a different training objective.

## 5. Retrain and verify in play

Run `python3 train.py` after changing features or labels, then run your Godot scene with the neural policy. Check that its `schema`, feature count, and output heads still match the loader. Run paired episodes with the scripted and neural policies from the same starts. In this chapter, `scripts/evaluate.gd` resets Vita and the enemy at 3.6, 5.2, and 7.0 metres and reports score, damage, shots, punches, and dodges. Adapt that evaluator to your game's win conditions; do not judge only by imitation accuracy.

Useful checks: does the actor actually fire when the policy says fire? Does dodge start before punch contact? Does health change only on a real hit? Can the agent recover when its first shot misses? Record failures as well as successful clips. If your agent just runs in a straight line, inspect the observation array and action mapping before changing network size.

This first chapter gets a trained, structured-state policy running in Godot. It does not claim that a model trained on Vita's game will transfer unchanged to yours, or that it learns from animation pixels. Those are later lessons.
