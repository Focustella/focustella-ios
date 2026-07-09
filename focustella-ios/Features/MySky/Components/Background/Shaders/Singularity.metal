#include <metal_stdlib>
using namespace metal;

/*
 Ported from XorDev/Singularity (MIT License):
 https://github.com/XorDev/Singularity
 Source:
 https://raw.githubusercontent.com/XorDev/Singularity/main/Shaders/shadertoy-version.glsl
*/

struct FullscreenVertexOut {
    float4 position [[position]];
    float2 uv;
};

struct BlackHoleUniforms {
    float2 resolution;
    float time;
    float padding;
};

constant float kSizeScale = 0.7;
constant float4 kColorGradient = float4(0.58, 0.42, -1.18, 0.0);
constant float3 kWarmTint = float3(1.24, 1.14, 0.73);

vertex FullscreenVertexOut singularityFullscreenVertex(uint vertexID [[vertex_id]]) {
    constexpr float2 positions[3] = {
        float2(-1.0, -1.0),
        float2(3.0, -1.0),
        float2(-1.0, 3.0)
    };

    FullscreenVertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = positions[vertexID] * 0.5 + 0.5;
    return out;
}

fragment float4 singularityFragment(
    FullscreenVertexOut in [[stage_in]],
    constant BlackHoleUniforms& uniforms [[buffer(0)]]
) {
    float2 resolution = max(uniforms.resolution, float2(1.0));
    float2 fragCoord = in.uv * resolution;

    float i = 0.2;
    float a = 0.0;

    float2 r = resolution;
    // kSizeScale < 1.0 shrinks the hole on screen.
    float2 p = ((fragCoord + fragCoord) - r) / r.y / 0.7 / kSizeScale;
    float2 d = float2(-1.0, 1.0);
    float2 b = p - i * d;

    float denom = 0.1 + i / max(dot(b, b), 0.0001);
    float4 cMatrixValues = float4(1.0, 1.0, d / denom);
    float2x2 cMatrix = float2x2(
        float2(cMatrixValues.x, cMatrixValues.y),
        float2(cMatrixValues.z, cMatrixValues.w)
    );
    float2 c = p * cMatrix;

    a = max(dot(c, c), 0.0001);
    float4 vAngles = 0.5 * log(a) + uniforms.time * i + float4(0.0, 33.0, 11.0, 0.0);
    float4 vCos = cos(vAngles);
    float2x2 vMatrix = float2x2(float2(vCos.x, vCos.y), float2(vCos.z, vCos.w));
    float2 v = (c * vMatrix) / i;

    float2 w = float2(0.0);
    for (; i++ < 9.0; w += 1.0 + sin(v)) {
        v += 0.7 * sin(v.yx * i + uniforms.time) / i + 0.5;
    }

    i = length(sin(v / 0.3) * 0.4 + c * (3.0 + d));

    float4 wave = max(float4(w.x, w.y, w.y, w.x), float4(0.001));
    float4 gradient = exp(c.x * kColorGradient);

    float accretionBrightness = 2.0 + i * i / 4.0 - i;
    float centerDarkness = 0.5 + 1.0 / a;
    float rimHighlight = 0.03 + abs(length(p) - 0.7);

    float4 color = 1.0 - exp(
        -gradient
        / wave
        / max(accretionBrightness, 0.0001)
        / max(centerDarkness, 0.0001)
        / max(rimHighlight, 0.0001)
    );

    // Collapse RGB hue variation into a single intensity so only warm yellow-white remains.
    float intensity = dot(max(color.rgb, 0.0), float3(0.3333, 0.3333, 0.3333));
    float3 rgb = clamp(intensity * kWarmTint, 0.0, 1.0);
    return float4(rgb, 1.0);
}
