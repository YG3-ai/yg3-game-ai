[ENGLISH](#english) · [MANDARIN 中文](#mandarin)

<a id="english"></a>

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

---

<a id="mandarin"></a>

# 第 01 章——训练游戏战斗智能体：从脚本策略到神经网络策略

本章使用与 YG3 的 Level 0 游戏原型相同的沙丘及废弃城市布局。Vita 是玩家角色；带动画的敌人会接近她、出拳，也会躲避步枪射击。双方都使用 Godot 的物理角色和动画片段。

## 环境要求

- Godot 4.7.2
- Python 3.10 或更新版本；不需要安装 Python 第三方包
- Git LFS，用于下载示例 GLB

## 运行方法

在本章目录中执行：

```sh
python3 train.py
godot --path . -- --scripted-combat
godot --path . -- --neural-combat
godot --headless --path . -- --eval
```

前两个 Godot 命令会在同一个关卡中分别展示脚本教师策略和神经网络策略。评估命令会从三个起始距离各运行一对六秒回合，共六个回合，并打印 JSON 汇总。如果 macOS 上的 Godot 是以应用程序形式安装，可以在编辑器中打开 `project.godot`，或使用应用程序内部的可执行文件传入上述参数。不加参数启动时，Vita 由玩家手动控制。

## 模型学到什么

`train.py` 采样 1,800 个结构化战斗状态，使用 `teacher_action()` 生成标签，再通过随机梯度下降训练一个 9→24→5 的前馈神经网络。输出文件为 `weights/combat_mlp.json`。Godot 端按相同的特征顺序读取权重，并输出移动选择、开火和闪避三个决策。

这种方法是**教师策略蒸馏**，不是强化学习，也不是视觉策略。网络读取距离、动作计时器、敌人攻击状态和生命值等游戏内部状态；它不读取 RGB 画面。最初的私人实验还通过短回合调过教师策略的几个时间参数。本章把这些参数作为明确的默认值，重点复现蒸馏过程和配对评估。

三个未见过的起始距离只构成小规模的冒烟测试，不能证明广泛的泛化能力。除了合成状态上的模仿准确率，还要观察实际动作和失败情况。

首次在本地运行六个回合时，教师策略和 MLP 的平均得分都是 66，平均造成 60 点伤害，均未受伤；它们分别在不同的起始距离取得更好的结果。这些数字只描述这一次运行。修改智能体或游戏后重新评估，才是更有价值的练习。

## 使用你自己的资源

可以保留 AI 代码，只替换 `scenes/characters/vita.tscn` 中 Vita 的模型，以及 `scenes/enemies/meshy_space_enemy.tscn` 中敌人的模型。`CharacterBody3D`、碰撞形状和 `VisualPivot/Model` 节点结构构成适配接口；必要时调整模型尺寸和朝向。

当前 Vita 控制器需要 `AnimationPlayer`、Mixamo 风格的髋部骨骼、文档列出的移动／闪避／受击动画，以及名为 `eden_rifle_v001` 的步枪节点。敌人需要 `Walking`、`Running`、`Punch_Combo` 和 `Roll_Dodge`。若自己的资源使用不同名称，请在 `scripts/vita_controller.gd`、`scripts/rifle_actions.gd` 和 `scripts/enemy_controller.gd` 中对应修改。也可以使用程序生成的角色动画，但要保持动作和观察接口一致。调整碰撞高度、出拳距离、射击起点、时间参数与摄像机画面后，重新训练并评估。附带的权重不能直接适用于另一款游戏。

请阅读[游戏适配操作指南](ADAPT_YOUR_GAME.md#mandarin)，了解准确的特征顺序、动作含义、资源接口、重新训练步骤和检查方法。

## 项目文件

- `scenes/levels/level_0.tscn`：沙漠和遗迹布局，以及 Vita 与敌人的实例。
- `scripts/level_0.gd`：出生位置、界面和回合模式选择。
- `scripts/autonomous_combat_policy.gd`：可读的脚本教师策略。
- `train.py`：合成状态采样、教师标签和神经网络训练。
- `scripts/neural_combat_policy.gd`：推理与动作执行。
- `scripts/evaluate.gd`：在实际游戏中进行配对评估。

下一章将采集带时间戳的轨迹及同步的摄像机观察。之后会逐步讨论视觉、记忆与世界模型。
