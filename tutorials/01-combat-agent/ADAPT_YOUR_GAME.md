[ENGLISH](#english) · [MANDARIN 中文](#mandarin)

<a id="english"></a>

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

---

<a id="mandarin"></a>

# 将战斗智能体适配到你的游戏

可以从两个方向入手。如果只是想在**本教程的竞技场中展示自己的美术资源**，替换模型场景，保留战斗规则即可。如果想让 AI 操作**你自己的游戏**，需要把该游戏的状态和动作接入同一套小型接口，再根据自己的规则重新训练。替换 GLB 只会改变外观，不会让网络自动学会新行为。

## 1. 先复现参考示例

克隆前安装 Git LFS 并执行 `git lfs install`；如果已经克隆，则执行 `git lfs pull`。进入 `tutorials/01-combat-agent`，运行 `python3 train.py`，然后按本章 README 中的命令分别使用 `-- --scripted-combat`、`-- --neural-combat` 和 `-- --eval` 启动 Godot。若修改训练器，可把新生成的 `weights/combat_mlp.json` 与仓库中的版本比较；其中的 `seed` 和 `synthetic_accuracy` 字段可用于快速检查。

也可以观看八秒的[脚本策略](../../media/vita-scripted.mp4)与[神经网络策略](../../media/vita-neural.mp4)视频。它们展示同一场沙漠遭遇战，只是决策者不同。

## 2. 在本竞技场中替换模型

在 `scenes/characters/vita.tscn` 中保留 `CharacterBody3D`、`CollisionShape3D`、`VisualPivot`、摄像机节点，以及 `VisualPivot/Model` 节点路径；把 `Model` 处的实例换成导入的角色场景。在 `scenes/enemies/meshy_space_enemy.tscn` 中，同样替换敌人的 `VisualPivot/Model`。先让角色大小与碰撞胶囊接近，确认模型位置正确后再调整胶囊。替换模型时不必修改沙漠关卡场景。

玩家控制器目前会查找带 `mixamorig_Hips` 骨骼的 `Skeleton3D`，以及含有以下片段的 `AnimationPlayer`：`Short_Breathe_and_Look_Around`、`Walking_Woman`、`Running`、`Jump_Run`、`Roll_Dodge_1`、`_360_Power_Spin_Jump`、`Walk_Forward_While_Shooting`、`Walk_Backward_While_Shooting_inplace`、`Run_and_Shoot` 和 `Hit_Reaction`。敌人需要 `Walking`、`Running`、`Punch_Combo` 和 `Roll_Dodge`。若片段名称不同，请在 `scripts/vita_controller.gd` 或 `scripts/enemy_controller.gd` 中映射；这两个文件的 `_ready()` 断言会立即指出缺失的片段。

`scripts/rifle_actions.gd` 会查找名为 `eden_rifle_v001` 的可视节点、其下的 `Muzzle` 节点，以及 `mixamorig_RightHand` 骨骼。请根据自己的骨架和武器修改这些名称。如果暂时没有可见的步枪，可先放置简单的射击起点标记，并在运行场景前调整脚本。测试 AI 控制之前，先确认手动移动和射击正常。

## 3. 接入另一款游戏的观察数据

`scripts/neural_combat_policy.gd` 会按以下严格顺序构造九个特征；`train.py` 使用相同顺序：

| 索引 | 数值 | 归一化方式 |
| --- | --- | --- |
| 0 | 与敌人的水平距离 | 米数除以 9，限制在 0–1 |
| 1 | 敌人出拳计时器 | 秒数除以 1.5，限制在 0–1 |
| 2 | 玩家闪避冷却时间 | 秒数除以 2，限制在 0–1 |
| 3 | 玩家开火计时器 | 秒数除以 1.2，限制在 0–1 |
| 4 | 敌人瞄准计时器 | 秒数，限制在 0–1 |
| 5 | 敌人是否正在出拳 | 0 或 1 |
| 6 | 敌人是否正在闪避 | 0 或 1 |
| 7 | 玩家当前生命值／最大生命值 | 0–1 |
| 8 | 敌人当前生命值／最大生命值 | 0–1 |

特征的顺序和取值范围是模型接口的一部分。如果你的游戏没有其中某个信号，请确定替代方式，并同时修改 Godot 的特征构造代码与 Python 的采样代码。不要让旧权重接收含义不同的数值。这些特征包含游戏内部状态；后续章节才会讨论视觉观察。

## 4. 接入动作与教师策略

网络输出五个数值。第 0–2 项相互竞争，选择**后退**、**侧移**或**前进**；第 3 项对应开火概率，第 4 项对应闪避概率。`scripts/neural_combat_policy.gd` 将这些选择转换为世界坐标系中的移动向量及开火、闪避请求，再通过玩家控制器的 `set_combat_command()` 执行。`scripts/autonomous_combat_policy.gd` 中的脚本策略也调用同一个方法。移植到自己的游戏时，应保留这种共用的动作接口。

`train.py` 中的 `teacher_action()` 根据距离、开火时间和应对出拳的简单规则，为采样状态生成标签。如果你的武器、敌人或闪避时间不同，需要同时修改教师规则与状态采样器。目前的训练样本是**由脚本标注的合成状态**，并非从游戏过程采集的轨迹。要学到超出教师策略的行为，需要新的监督信号或不同的训练目标。

## 5. 重新训练，并在游戏中验证

修改特征或标签后，运行 `python3 train.py`，再让神经网络策略控制 Godot 场景。检查生成文件的 `schema`、特征数量和输出分支是否仍与加载器一致。从相同起始状态分别运行脚本策略与神经网络策略。本章的 `scripts/evaluate.gd` 会在距离为 3.6、5.2 和 7.0 米处重置 Vita 与敌人，并报告得分、伤害、射击、出拳及闪避次数。移植时，请根据自己游戏的胜利条件修改评估器，不要只看模仿准确率。

实际检查时可以问：策略发出开火指令后，角色真的射击了吗？闪避是否在出拳命中前开始？生命值是否只在真实命中时减少？第一枪落空后，智能体能否恢复？成功与失败片段都值得记录。如果智能体只会沿直线跑，先检查观察数组和动作映射，再考虑增大网络。

本章能让一个根据结构化状态训练的策略在 Godot 中运行。它并不表示在 Vita 的游戏中训练出的模型可以原样迁移到你的游戏，也不表示模型从动画画面中学习。这些是后续章节的主题。
