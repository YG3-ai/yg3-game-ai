#!/usr/bin/env python3
"""Distill a transparent combat teacher into a tiny Godot-readable MLP."""

import json
import math
import random
from pathlib import Path

SEED = 1929
FEATURES = [
    "distance_m_over_9", "punch_clock_s_over_1_5", "dodge_cooldown_s_over_2",
    "fire_clock_s_over_1_2", "enemy_aim_clock_s", "enemy_punching",
    "enemy_dodging", "learner_health_ratio", "enemy_health_ratio",
]
N_IN, N_HIDDEN, N_OUT = 9, 24, 5
OUTPUT = Path(__file__).resolve().parent / "weights" / "combat_mlp.json"


def teacher_action(x):
    distance = x[0] * 9.0
    move = 0 if distance < 1.6 else (2 if distance > 3.2 else 1)
    fire = int(x[3] * 1.2 >= 0.55)
    dodge = int(x[5] > 0.5 and x[1] * 1.5 >= 0.18
                and distance <= 2.3 and x[2] * 2.0 <= 0.01)
    return move, fire, dodge


def sample(rng, far=False):
    if far:
        distance = rng.uniform(6.0, 9.0)
    else:
        band = rng.randrange(3)
        distance = (rng.uniform(0.75, 1.58) if band == 0 else
                    rng.uniform(1.62, 3.18) if band == 1 else
                    rng.uniform(3.22, 6.0))
    state = rng.random()
    x = [distance / 9.0, rng.random(),
         0.0 if rng.random() < 0.55 else rng.uniform(0.05, 1.0),
         rng.random(), rng.random(), float(state < 0.42),
         float(0.42 <= state < 0.57), rng.uniform(0.2, 1.0),
         rng.uniform(0.1, 1.0)]
    return x, teacher_action(x)


def sigmoid(value):
    value = max(-30.0, min(30.0, value))
    return 1.0 / (1.0 + math.exp(-value))


def forward(x, w1, b1, w2, b2):
    hidden = [math.tanh(sum(w * v for w, v in zip(row, x)) + bias)
              for row, bias in zip(w1, b1)]
    output = [sum(w * v for w, v in zip(row, hidden)) + bias
              for row, bias in zip(w2, b2)]
    return hidden, output


def predict(x, w1, b1, w2, b2):
    _, y = forward(x, w1, b1, w2, b2)
    return max(range(3), key=lambda i: y[i]), int(sigmoid(y[3]) >= 0.5), int(sigmoid(y[4]) >= 0.5)


def main():
    rng = random.Random(SEED)
    s1 = math.sqrt(2.0 / (N_IN + N_HIDDEN))
    s2 = math.sqrt(2.0 / (N_HIDDEN + N_OUT))
    w1 = [[rng.uniform(-s1, s1) for _ in range(N_IN)] for _ in range(N_HIDDEN)]
    b1 = [0.0] * N_HIDDEN
    w2 = [[rng.uniform(-s2, s2) for _ in range(N_HIDDEN)] for _ in range(N_OUT)]
    b2 = [0.0] * N_OUT
    training = [sample(rng) for _ in range(1800)]
    for epoch in range(40):
        rng.shuffle(training)
        rate = 0.025 * (1.0 - 0.65 * epoch / 40.0)
        for x, (move, fire, dodge) in training:
            hidden, y = forward(x, w1, b1, w2, b2)
            top = max(y[:3])
            exp_y = [math.exp(value - top) for value in y[:3]]
            total = sum(exp_y)
            grad = [exp_y[i] / total - float(i == move) for i in range(3)]
            grad += [(sigmoid(y[3]) - fire) * 1.25,
                     (sigmoid(y[4]) - dodge) * 2.0]
            old_w2 = [row[:] for row in w2]
            for o in range(N_OUT):
                for h in range(N_HIDDEN):
                    w2[o][h] -= rate * grad[o] * hidden[h]
                b2[o] -= rate * grad[o]
            for h in range(N_HIDDEN):
                gh = sum(old_w2[o][h] * grad[o] for o in range(N_OUT)) * (1.0 - hidden[h] ** 2)
                for i in range(N_IN):
                    w1[h][i] -= rate * gh * x[i]
                b1[h] -= rate * gh

    def accuracy(far):
        correct = [0, 0, 0]
        for _ in range(1000):
            x, label = sample(rng, far)
            guess = predict(x, w1, b1, w2, b2)
            for i in range(3):
                correct[i] += int(guess[i] == label[i])
        return dict(zip(("movement", "fire", "dodge"), (n / 1000 for n in correct)))

    artifact = {
        "schema": "yg3.game_ai.combat_mlp.v1", "seed": SEED,
        "method": "scripted_teacher_distillation_sgd", "features": FEATURES,
        "architecture": {"inputs": N_IN, "hidden": N_HIDDEN, "outputs": N_OUT,
                         "activation": "tanh", "heads": ["movement_3way", "fire", "dodge"]},
        "weights": {"w1": w1, "b1": b1, "w2": w2, "b2": b2},
        "synthetic_accuracy": {"sampled": accuracy(False), "far_6_to_9m": accuracy(True)},
        "limitations": ["structured privileged observations", "scripted teacher labels", "not trained from pixels"],
    }
    OUTPUT.parent.mkdir(exist_ok=True)
    OUTPUT.write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(artifact["synthetic_accuracy"], indent=2))
    print(f"Saved {OUTPUT}")


if __name__ == "__main__":
    main()
