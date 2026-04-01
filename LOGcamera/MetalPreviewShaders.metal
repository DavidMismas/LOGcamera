#include <metal_stdlib>
using namespace metal;

struct PreviewVertexIn {
    float2 position;
    float2 texCoord;
};

struct PreviewVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct PreviewUniforms {
    uint lookMode;
    uint colorProfile;
    uint sourceType;
    uint yCbCrMatrix;
    uint isFullRange;
    uint padding;
};

vertex PreviewVertexOut previewVertex(const device PreviewVertexIn *vertices [[buffer(0)]],
                                      uint vertexID [[vertex_id]]) {
    PreviewVertexOut out;
    out.position = float4(vertices[vertexID].position, 0.0, 1.0);
    out.texCoord = vertices[vertexID].texCoord;
    return out;
}

float sampleTransfer(constant float *samples, float encodedValue) {
    constexpr float lastIndex = 32.0;
    float clampedValue = clamp(encodedValue, 0.0, 1.0);
    float scaled = clampedValue * lastIndex;
    uint index = min(uint(floor(scaled)), uint(lastIndex - 1.0));
    float t = scaled - float(index);
    return mix(samples[index], samples[index + 1], t);
}

float rec709OETF(float linearValue) {
    float linear = max(linearValue, 0.0);
    if (linear < 0.018) {
        return 4.5 * linear;
    }
    return 1.099 * pow(linear, 0.45) - 0.099;
}

float3 yCbCrToRGB(float ySample, float2 cbcrSample, uint matrixCode, bool isFullRange) {
    float y;
    float cb;
    float cr;

    if (isFullRange) {
        y = ySample;
        cb = cbcrSample.x - 0.5;
        cr = cbcrSample.y - 0.5;
    } else {
        y = clamp((ySample - (16.0 / 255.0)) * (255.0 / 219.0), 0.0, 1.0);
        cb = (cbcrSample.x - (128.0 / 255.0)) * (255.0 / 224.0);
        cr = (cbcrSample.y - (128.0 / 255.0)) * (255.0 / 224.0);
    }

    if (matrixCode == 0) {
        return float3(
            y + 1.4020 * cr,
            y - 0.344136 * cb - 0.714136 * cr,
            y + 1.7720 * cb
        );
    }

    return float3(
        y + 1.5748 * cr,
        y - 0.187324 * cb - 0.468124 * cr,
        y + 1.8556 * cb
    );
}

fragment float4 previewFragment(PreviewVertexOut in [[stage_in]],
                                texture2d<float> colorTexture [[texture(0)]],
                                texture2d<float> lumaTexture [[texture(1)]],
                                texture2d<float> chromaTexture [[texture(2)]],
                                sampler textureSampler [[sampler(0)]],
                                constant PreviewUniforms &uniforms [[buffer(0)]],
                                constant float *appleLogTransfer [[buffer(1)]],
                                constant float *appleLog2Transfer [[buffer(2)]]) {
    float3 encodedRGB;

    if (uniforms.sourceType == 0) {
        encodedRGB = colorTexture.sample(textureSampler, in.texCoord).rgb;
    } else {
        float ySample = lumaTexture.sample(textureSampler, in.texCoord).r;
        float2 cbcrSample = chromaTexture.sample(textureSampler, in.texCoord).rg;
        encodedRGB = yCbCrToRGB(
            ySample,
            cbcrSample,
            uniforms.yCbCrMatrix,
            uniforms.isFullRange != 0
        );
    }

    if (uniforms.lookMode == 0 || uniforms.colorProfile == 0) {
        return float4(clamp(encodedRGB, 0.0, 1.0), 1.0);
    }

    constant float *transfer = uniforms.colorProfile == 2 ? appleLog2Transfer : appleLogTransfer;
    float3 linearRGB = float3(
        sampleTransfer(transfer, encodedRGB.r),
        sampleTransfer(transfer, encodedRGB.g),
        sampleTransfer(transfer, encodedRGB.b)
    );

    float3 rec709RGB = float3(
        rec709OETF(linearRGB.r),
        rec709OETF(linearRGB.g),
        rec709OETF(linearRGB.b)
    );

    return float4(clamp(rec709RGB, 0.0, 1.0), 1.0);
}
