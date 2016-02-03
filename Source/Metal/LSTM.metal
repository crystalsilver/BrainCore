// Copyright © 2016 Venture Media Labs. All rights reserved.
//
// This file is part of BrainCore. The full BrainCore copyright notice,
// including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

#include <metal_stdlib>

using namespace metal;

struct LSTMParameters {
    ushort unitCount;
    ushort inputSize;
    float clipTo;
};

inline float sigmoid(const float x) {
    return 1.0 / (1.0 + exp(-x));
}

kernel void lstm_forward(const device float* input,
                         const device float* weights,
                         const device float* biases,
                         device float* output,
                         device float* state,
                         constant LSTMParameters& params,
                         uint unit [[ thread_position_in_grid ]])
{
    if (unit >= params.unitCount)
        return;

    const auto previousActivation = state[unit];
    const auto previousOutput = state + unit + params.unitCount;

    const auto inputGateIndex  = 0 * params.unitCount + unit;
    const auto newInputIndex   = 1 * params.unitCount + unit;
    const auto forgetGateIndex = 2 * params.unitCount + unit;
    const auto outputGateIndex = 3 * params.unitCount + unit;

    auto inputGate  = biases[inputGateIndex];
    auto newInput   = biases[newInputIndex];
    auto forgetGate = biases[forgetGateIndex];
    auto outputGate = biases[outputGateIndex];

    for (uint i = 0; i < params.inputSize; i += 1) {
        inputGate  += weights[inputGateIndex  + i * 4 * params.unitCount] * input[i];
        newInput   += weights[newInputIndex   + i * 4 * params.unitCount] * input[i];
        forgetGate += weights[forgetGateIndex + i * 4 * params.unitCount] * input[i];
        outputGate += weights[outputGateIndex + i * 4 * params.unitCount] * input[i];
    }
    for (uint i = 0; i < params.unitCount; i += 1) {
        const auto j = i + params.inputSize;
        inputGate  += weights[inputGateIndex  + j * 4 * params.unitCount] * previousOutput[i];
        newInput   += weights[newInputIndex   + j * 4 * params.unitCount] * previousOutput[i];
        forgetGate += weights[forgetGateIndex + j * 4 * params.unitCount] * previousOutput[i];
        outputGate += weights[outputGateIndex + j * 4 * params.unitCount] * previousOutput[i];
    }

    auto activation = sigmoid(forgetGate + 1) * previousActivation + sigmoid(inputGate) * tanh(newInput);
    if (params.clipTo > 0) {
        activation = clamp(activation, -params.clipTo, params.clipTo);
    }
    const auto out = sigmoid(outputGate) * tanh(activation);

    output[unit] = out;
    state[unit] = activation;
    state[unit + params.unitCount] = out;
}