[ENGLISH](#english) · [MANDARIN 中文](#mandarin)

<a id="english"></a>

# YG3 Game AI

Open-source, runnable lessons on training game agents. The series begins in YG3's desert combat scene, with Vita and an animated melee enemy. Each chapter states what the agent observes, what it controls, how it learns, and how we evaluate it.

## Start here

[Chapter 01: Train a Game Combat Agent: From Scripted Policy to Neural Policy](tutorials/01-combat-agent/README.md)

Clone the repository with Git LFS enabled, install Godot 4.7.2 and Python 3, and follow the chapter's commands. The example includes desert dunes and ruined city scenery, Vita, the enemy, and the combat code. The other characters and their models are absent.

The character and enemy scenes use ordinary Godot model instances. You can replace their GLBs with your own art while retaining the same controller and policy interface. Match the required animation clips and weapon node as explained in the chapter.

![Vita dodging the enemy in the desert](media/vita-neural-preview.png)

Watch the same arena with the [scripted policy](media/vita-scripted.mp4) and the [neural policy](media/vita-neural.mp4). Both clips use Vita and the tutorial enemy.

## How the AI learns and why this approach works

The first lesson starts with a readable scripted combat policy: keep a useful distance, fire when the weapon is ready, and dodge a nearby punch. `train.py` generates many different combat states and asks that script what to do in each one. A small neural network practices predicting those answers, adjusting its weights after each example. Godot then feeds the network live combat state and executes its movement, fire, and dodge choices. The [chapter explanation](tutorials/01-combat-agent/README.md#training-explained) walks through each stage.

This works in the example because the teacher's decisions depend on a few explicit measurements, such as distance and timing, and the network can approximate those rules from varied examples. The agent learns to imitate a teacher using structured game state. It does not learn from the videos or discover the rules by reinforcement learning; changing the game or its observations calls for new training and a real-game evaluation.

## The Math Behind It

Nine normalized combat measurements form an input vector `x`. The network computes `h = tanh(W1 x + b1)` with 24 hidden values, then `z = W2 h + b2` with five outputs. The first three outputs choose movement; a sigmoid converts each of the last two into a fire or dodge probability. Training lowers the difference between these predictions and the scripted teacher's answers by updating the weights after each example. See [the equations and loss function in Chapter 1](tutorials/01-combat-agent/README.md#math-behind-it).

## Series roadmap

1. Structured-state combat: scripted teacher, small neural policy, matched evaluation.
2. Timestamped action, event, and camera-aligned trajectories.
3. Learning from visual observations and partial visibility.
4. Memory, navigation, and longer-horizon decisions.
5. Action-conditioned world models and counterfactual evaluation.

Later chapters will be added as they are implemented and measured. Contributions are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

## Licenses and attribution

Tutorial code and writing are MIT licensed; the [English license](LICENSE) is authoritative, with a [Mandarin reference translation](LICENSE.zh-CN.md). Included models, environment art, font, and videos have their own terms; see [ASSETS.md](ASSETS.md). YG3 maintains the tutorials. Vita, the enemy, and the desert scene are the game content used for this chapter; no other squad models or private environments are included.

Vita is © OTR HVN and may be used non-commercially with credit; commercial use requires separate permission. See [ASSETS.md](ASSETS.md) for the asset-by-asset terms.

## About YG3 and OTR HVN

YG3 builds open environments and practical AI experiments for agents, games, and embodied learning. OTR HVN develops the game that provides this chapter's desert example. As a small side note, Vita is an early character design for OTR HVN's upcoming game, a spiritual successor to *IRON ABYSS*.

---

<a id="mandarin"></a>

# YG3 游戏 AI

这是一套开源、可以实际运行的游戏 AI 教程。系列从 YG3 的沙漠战斗场景开始：Vita 与一名带动画的近战敌人交手。每一章都会说明智能体能观察什么、能控制什么、怎样学习，以及如何评估结果。

## 从这里开始

[第 01 章：训练游戏战斗智能体：从脚本策略到神经网络策略](tutorials/01-combat-agent/README.md#mandarin)

克隆仓库前请启用 Git LFS，然后安装 Godot 4.7.2 和 Python 3，按章节中的命令操作。示例包含沙丘、废弃城市遗迹、Vita、敌人以及战斗代码；其他角色及其模型不在仓库中。

角色和敌人都通过普通的 Godot 模型实例加载。你可以替换成自己的 GLB 美术资源，同时保留控制器和策略接口；动画片段和武器节点的名称需要按章节说明对应起来。

![Vita 在沙漠中躲避敌人](media/vita-neural-preview.png)

观看同一场景中的[脚本策略视频](media/vita-scripted.mp4)和[神经网络策略视频](media/vita-neural.mp4)。两段视频都使用 Vita 和教程敌人。

## AI 如何学习，以及这种方法为何有效

第一课先编写一个容易理解的战斗脚本策略：保持合适的距离、武器准备好时开火、附近敌人出拳时闪避。`train.py` 生成许多不同的战斗状态，并请脚本为每个状态给出动作。小型神经网络反复预测这些答案，每看过一个样本就调整权重。随后，Godot 将实时战斗状态输入网络，并执行它选择的移动、开火和闪避动作。[章节详解](tutorials/01-combat-agent/README.md#mandarin-training-explained)会逐步说明这一过程。

这种方法在示例中有效，是因为教师策略主要依靠距离、时间等少量明确的数值做决定，而网络能通过多样化的样本近似这些规则。智能体学习的是根据结构化游戏状态模仿教师；它没有从视频中学习，也没有通过强化学习自行发现规则。更换游戏或观察数据后，需要重新训练，并在实际游戏回合中评估。

## 背后的数学原理（The Math Behind It）

九个归一化的战斗测量值组成输入向量 `x`。网络先计算 `h = tanh(W1 x + b1)`，得到 24 个隐藏层数值；再计算 `z = W2 h + b2`，得到五个输出。前三个输出用于选择移动方式；后两个经 sigmoid 函数变成开火和闪避概率。训练时，网络比较预测与脚本教师给出的答案，并在每个样本后更新权重以减小误差。具体公式和损失函数见[第 01 章](tutorials/01-combat-agent/README.md#mandarin-math-behind-it)。

## 系列路线图

1. 基于结构化状态的战斗：脚本教师策略、小型神经网络策略及配对评估。
2. 带时间戳的动作、事件和摄像机对齐轨迹。
3. 根据视觉观察学习，并处理视野不完整的问题。
4. 记忆、导航和更长时间跨度的决策。
5. 以动作为条件的世界模型，以及反事实评估。

后续章节会在实现并完成测量后陆续加入。欢迎参与贡献；请阅读[贡献指南](CONTRIBUTING.md#mandarin)。

## 许可与署名

教程代码和文字采用 MIT 许可证；以[英文许可证原文](LICENSE)为准，另提供[中文参考译文](LICENSE.zh-CN.md#mandarin)。模型、场景美术、字体及视频各有各的使用条款，详见[资源说明](ASSETS.md#mandarin)。本系列由 YG3 维护。本章使用的游戏内容仅包括 Vita、敌人和沙漠场景；不包含小队其他角色的模型或其他私人场景。

Vita 的版权归 OTR HVN 所有；注明 OTR HVN 后可用于非商业用途。商业使用需要另行取得许可。各项资源的条款见[资源说明](ASSETS.md#mandarin)。

## 关于 YG3 与 OTR HVN

YG3 为智能体、游戏及具身学习构建开放环境，并开展实践性的 AI 实验。OTR HVN 正在开发提供本章沙漠示例的游戏。顺带一提，Vita 是 OTR HVN 即将推出的游戏中的早期角色设计；该游戏是 *IRON ABYSS* 的精神续作。
