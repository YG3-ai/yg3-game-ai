# YG3 Game AI

Open-source, runnable lessons on training game agents. The series begins in YG3's desert combat scene, with Vita and an animated melee enemy. Each chapter states what the agent observes, what it controls, how it learns, and how we evaluate it.

## Start here

[Chapter 01: Train a Game Combat Agent: From Scripted Policy to Neural Policy](tutorials/01-combat-agent/README.md)

Clone the repository with Git LFS enabled, install Godot 4.7.2 and Python 3, and follow the chapter's commands. The example includes desert dunes and ruined city scenery, Vita, the enemy, and the combat code. The other characters and their models are absent.

The character and enemy scenes use ordinary Godot model instances. You can replace their GLBs with your own art while retaining the same controller and policy interface. Match the required animation clips and weapon node as explained in the chapter.

![Vita dodging the enemy in the desert](media/vita-neural-preview.png)

Watch the same arena with the [scripted policy](media/vita-scripted.mp4) and the [neural policy](media/vita-neural.mp4). Both clips use Vita and the tutorial enemy.

## Series roadmap

1. Structured-state combat: scripted teacher, small neural policy, matched evaluation.
2. Timestamped action, event, and camera-aligned trajectories.
3. Learning from visual observations and partial visibility.
4. Memory, navigation, and longer-horizon decisions.
5. Action-conditioned world models and counterfactual evaluation.

Later chapters will be added as they are implemented and measured. Contributions are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

## Licenses and attribution

Tutorial code and writing are MIT licensed. Included models, environment art, font, and videos have their own terms; see [ASSETS.md](ASSETS.md). YG3 maintains the tutorials. Vita, the enemy, and the desert scene are the game content used for this chapter; no other squad models or private environments are included.

## About YG3 and OTR HVN

YG3 builds open environments and practical AI experiments for agents, games, and embodied learning. OTR HVN develops the game that provides this chapter's desert example. As a small side note, Vita is an early character design for OTR HVN's upcoming game, a spiritual successor to *IRON ABYSS*.
