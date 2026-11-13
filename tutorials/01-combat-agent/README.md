[ENGLISH](#english) · [MANDARIN 中文](#mandarin)

<a id="english"></a>

# Chapter 01: Train a Game Combat Agent: From Scripted Policy to Neural Policy

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

<a id="training-explained"></a>

## Training explained, step by step

1. **Define the decisions.** The script chooses one of retreat, strafe, or advance, plus separate fire and dodge flags. Both the scripted and neural policies send these decisions through Vita's `set_combat_command()` interface, so the game executes them in the same way.
2. **Make labeled examples.** `sample()` in `train.py` draws 1,800 randomized nine-value combat states. `teacher_action()` labels each state: retreat inside 1.6 m, advance beyond 3.2 m, fire after 0.55 s, and dodge when a nearby punch has progressed far enough and dodge is ready. These are generated state–action pairs, not recorded gameplay frames.
3. **Fit the network.** The 9 inputs pass through 24 `tanh` hidden units to 5 outputs. Three outputs compete for movement; the other two predict fire and dodge. For 40 passes through the examples, stochastic gradient descent compares each prediction with the teacher's label and nudges the weights to reduce the error. The seed is fixed so the training run is repeatable.
4. **Use the weights in Godot.** The trainer writes `weights/combat_mlp.json`. `scripts/neural_combat_policy.gd` builds the same nine features in the same order, runs the network, converts its outputs into decisions, and calls `set_combat_command()`. Matching feature meanings and normalization between Python and Godot is essential.
5. **Check behavior, not just labels.** The trainer reports accuracy on new sampled states, including a 6–9 m distance split. `scripts/evaluate.gd` also runs both policies in the actual Godot fight from the same three starting distances and records damage, actions, and score. The distance split alone is easy for this teacher's “advance when far away” rule, so it is not evidence of broad out-of-distribution skill.

Why can a small network do this? The teacher's choices are mostly thresholds on a few low-dimensional values. Random sampling puts examples on both sides of those thresholds, and the network learns a smooth approximation. The health and enemy-aim features are available to the model, but the current teacher labels do not depend on them; adding features alone does not teach new behavior. The learned policy can imitate the teacher within this setup, while real-game rollouts reveal timing mistakes and compounding errors that label accuracy can miss. It is not trained to read images, build a world model, or improve beyond its teacher.

<a id="math-behind-it"></a>

## The Math Behind It

For each sample, let `x` be the nine normalized features and let the teacher labels be `m` (one of three movement choices), `f` (fire: 0 or 1), and `d` (dodge: 0 or 1). The trainer uses these dimensions:

```text
x: 9 values         W1: 24 × 9       b1: 24 values
h = tanh(W1 x + b1)                 h: 24 values
z = W2 h + b2       W2: 5 × 24       b2: 5 values
```

The first three entries of `z` become movement probabilities through `softmax(z[0:3])`. The other two become `p_fire = sigmoid(z[3])` and `p_dodge = sigmoid(z[4])`. Training minimizes a combined classification loss:

```text
L = -log(p_move[m]) + 1.25 × BCE(f, p_fire) + 2.0 × BCE(d, p_dodge)
BCE(y, p) = -y log(p) - (1-y) log(1-p)
weights ← weights - learning_rate × gradient(L)
```

The coefficients `1.25` and `2.0` give extra weight to fire and dodge errors. `train.py` performs this update after each sample for 40 epochs, with a learning rate that decreases from `0.025` to about `0.0092`. At runtime, Godot takes the largest movement output and fires or dodges when the corresponding sigmoid probability reaches `0.5`. These equations reproduce the implemented trainer; they do not describe a reward-maximizing RL algorithm.

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

# 第 01 章：训练游戏战斗智能体：从脚本策略到神经网络策略

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

<a id="mandarin-training-explained"></a>

## 训练过程详解

1. **先定义动作。** 脚本从后退、侧移、前进中选一个动作，再分别决定是否开火、是否闪避。脚本策略和神经网络策略都通过 Vita 的 `set_combat_command()` 接口提交决定，因此游戏以相同方式执行动作。
2. **生成带标签的样本。** `train.py` 中的 `sample()` 随机生成 1,800 个由九个数值组成的战斗状态。`teacher_action()` 为每个状态标注动作：距离小于 1.6 米时后退，大于 3.2 米时前进，开火计时达到 0.55 秒时射击；附近敌人的出拳达到指定阶段且闪避已就绪时闪避。这些是生成的“状态与动作”样本，不是从游戏画面录制的帧。
3. **拟合神经网络。** 九个输入经过 24 个使用 `tanh` 的隐藏单元，得到五个输出。前三个输出竞争选择移动方式，后两个分别预测开火和闪避。训练器对样本重复学习 40 轮：每次将预测与教师标签比较，再用随机梯度下降微调权重，使误差减小。固定随机种子让训练可以复现。
4. **在 Godot 中使用权重。** 训练器写出 `weights/combat_mlp.json`。`scripts/neural_combat_policy.gd` 按相同顺序构造九个特征，运行网络，把输出转成动作，并调用 `set_combat_command()`。Python 与 Godot 两端必须对特征含义及归一化方式保持一致。
5. **检查实际行为，而不只看标签准确率。** 训练器报告新采样状态上的准确率，也包括 6–9 米的距离划分。`scripts/evaluate.gd` 还会让两种策略分别从相同的三个起始距离进入真实的 Godot 战斗，并记录伤害、动作和得分。仅靠远距离划分并不能证明广泛的分布外能力，因为对这个教师策略而言，“距离远就前进”很容易判断。

小网络为何能学会？教师决策主要是在少量低维数值上设置阈值。随机采样让网络见到阈值两侧的例子，因此可以学到平滑的近似规则。模型虽然能读取生命值和敌人瞄准时间，但当前教师生成标签时并不依赖这些特征；单纯增加特征不会产生新行为。在本示例范围内，网络可以模仿教师；真实游戏回合还能暴露标签准确率无法发现的时机错误及误差累积。它尚未学习读取图像、建立世界模型或超越教师策略。

<a id="mandarin-math-behind-it"></a>

## 背后的数学原理（The Math Behind It）

对每个样本，用 `x` 表示九个归一化特征；教师标签分别为 `m`（三种移动方式之一）、`f`（开火：0 或 1）和 `d`（闪避：0 或 1）。训练器使用以下维度和计算过程：

```text
x：9 个数值        W1：24 × 9       b1：24 个数值
h = tanh(W1 x + b1)                 h：24 个数值
z = W2 h + b2      W2：5 × 24       b2：5 个数值
```

`z` 的前三项通过 `softmax(z[0:3])` 变成移动方式的概率；后两项分别得到 `p_fire = sigmoid(z[3])` 和 `p_dodge = sigmoid(z[4])`。训练目标是减小组合分类损失：

```text
L = -log(p_move[m]) + 1.25 × BCE(f, p_fire) + 2.0 × BCE(d, p_dodge)
BCE(y, p) = -y log(p) - (1-y) log(1-p)
权重 ← 权重 - 学习率 × 梯度(L)
```

系数 `1.25` 和 `2.0` 让开火与闪避预测错误受到更高权重。`train.py` 对每个样本更新一次权重，共训练 40 轮；学习率从 `0.025` 逐步降到约 `0.0092`。运行时，Godot 选择数值最高的移动输出；开火或闪避概率达到 `0.5` 时执行相应动作。这些公式对应仓库中实际实现的训练器，而不是以奖励最大化为目标的强化学习算法。

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
