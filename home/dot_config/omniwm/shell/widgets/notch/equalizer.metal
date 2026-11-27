// Four capsule bars that bob while music plays, for the notch island. Synthetic, so it
// needs no audio-capture permission. values.x: 1 animates the bars, 0 rests them low.
float4 shade(float2 uv, constant OmniShader& shader) {
    const float bars = 4.0;
    float slot = floor(min(uv.x * bars, bars - 1.0));
    float phase = slot * 1.93 + 0.4;
    float t = shader.time;
    float wave = 0.55 + 0.25 * sin(t * 7.3 + phase) + 0.2 * sin(t * 11.9 + phase * 2.7);
    float level = mix(0.2, clamp(wave, 0.15, 1.0), clamp(shader.values.x, 0.0, 1.0));
    float cell = shader.size.x / bars;
    float radius = max(1.0, cell * 0.3);
    float height = max(radius * 2.0, level * shader.size.y);
    float2 point = float2(uv.x * shader.size.x - (slot + 0.5) * cell, (uv.y - 0.5) * shader.size.y);
    float2 edge = abs(point) - float2(radius, height * 0.5) + radius;
    float distance = length(max(edge, 0.0)) + min(max(edge.x, edge.y), 0.0) - radius;
    float alpha = clamp(0.5 - distance * shader.scale, 0.0, 1.0);
    return float4(1.0, 1.0, 1.0, alpha * 0.92);
}
