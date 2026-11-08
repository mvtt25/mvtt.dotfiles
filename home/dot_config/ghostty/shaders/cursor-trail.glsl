// Cursor trail: when the cursor jumps, a streak in its color shrinks from where
// it was to where it is. Moves of a cell or two (typing) leave no trail.
// The uniforms: `ghostty +show-config --default --docs`, under custom-shader.

// Seconds the tail takes to catch up with the cursor.
const float DURATION = 0.2;

// Distance from p to the segment a-b.
float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return length(pa - ba * h);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);

    // xy is the cursor's top-left corner (y grows upwards), zw its size.
    vec2 cur = iCurrentCursor.xy + vec2(0.5, -0.5) * iCurrentCursor.zw;
    vec2 prev = iPreviousCursor.xy + vec2(0.5, -0.5) * iPreviousCursor.zw;
    float t = (iTime - iTimeCursorChange) / DURATION;
    if (t >= 1.0 || iFocus == 0 || iCursorVisible == 0 || distance(cur, prev) < 3.0 * iCurrentCursor.z) {
        return;
    }

    // Ease out: the tail leaves fast and lands softly, fading as it goes.
    vec2 tail = mix(prev, cur, 1.0 - pow(1.0 - t, 3.0));
    float radius = 0.5 * min(iCurrentCursor.z, iCurrentCursor.w);
    float inside = 1.0 - smoothstep(radius - 1.0, radius + 1.0, segment(fragCoord, tail, cur));
    fragColor.rgb = mix(fragColor.rgb, iCurrentCursorColor.rgb, inside * (1.0 - t) * 0.6);
}
