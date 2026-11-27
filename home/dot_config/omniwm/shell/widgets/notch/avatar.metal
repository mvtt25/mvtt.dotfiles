// A pixel critter for one TUIOS agent, on a 16 × 12 pixel canvas.
// values.x: mood — 0 working (types and bobs), 1 needs you (waves, yellow "!"),
// 2 errored (red, shakes), 3 resting (dim, eyes shut, "z"), 4 just finished (hops, arms up).
// values.y: phase offset in seconds, so agents don't move in step.
// values.z: 1 for Claude (terracotta), 0 for other harnesses (grey).

// An arm is RAISED (straight up beside the head) or sideways at a body row.
constant int RAISED = -1;

// The critter is 14 × 7: a 10 × 5 body with tall eyes, on four legs, with 2-pixel arms.
bool critter(int x, int y, int leftArm, int rightArm, bool eyes) {
    if (leftArm == RAISED && x == 1 && (y == -1 || y == 0)) return true;
    if (rightArm == RAISED && x == 12 && (y == -1 || y == 0)) return true;
    if (y < 0 || y > 6 || x < 0 || x > 13) return false;
    if (x <= 1) return y == leftArm;
    if (x >= 12) return y == rightArm;
    if (y <= 4) {
        bool eye = x == 4 || x == 9;
        return !(eye && (eyes ? (y == 1 || y == 2) : y == 2));
    }
    return x == 3 || x == 5 || x == 8 || x == 10;
}

float4 shade(float2 uv, constant OmniShader& shader) {
    const float W = 16.0;
    const float H = 12.0;
    int mood = int(shader.values.x + 0.5);
    float t = shader.time + shader.values.y;
    int px = int(min(floor(uv.x * W), W - 1.0));
    int py = int(min(floor(uv.y * H), H - 1.0));

    int fast = int(floor(t * 6.0)) & 1;
    int slow = int(floor(t * 3.0)) & 1;
    int bob = 0;
    int shake = 0;
    int leftArm = 3;
    int rightArm = 3;
    bool eyes = fract(t / 3.7) > 0.04;
    if (mood == 0) {
        bob = int(floor(t * 4.0)) & 1;
        leftArm = 3 + fast;
        rightArm = 4 - fast;
    } else if (mood == 1) {
        rightArm = slow == 1 ? RAISED : 1;
    } else if (mood == 2) {
        shake = fract(t * 0.7) < 0.3 ? fast * 2 - 1 : 0;
        leftArm = 4;
        rightArm = 4;
    } else if (mood == 3) {
        leftArm = 4;
        rightArm = 4;
        eyes = false;
    } else {
        bob = fract(t * 1.5) < 0.35 ? 1 : 0;
        leftArm = RAISED;
        rightArm = RAISED;
    }

    float4 body = shader.values.z > 0.5 ? float4(0.851, 0.467, 0.341, 1.0) : float4(0.74, 0.74, 0.78, 1.0);
    if (mood == 2) body = float4(1.0, 0.271, 0.227, 1.0);
    if (mood == 3) body.a = 0.5;

    if (critter(px - 1 - shake, py - 5 + bob, leftArm, rightArm, eyes)) return body;

    // "!" beside the head while it waits for you, blinking.
    if (mood == 1 && px == 15 && (py <= 2 || py == 4) && fract(t * 2.0) < 0.65) {
        return float4(1.0, 0.839, 0.039, 1.0);
    }
    // A 5 × 5 "z" over its shoulder while it rests, breathing.
    if (mood == 3 && px >= 11 && py <= 4) {
        bool z = py == 0 || py == 4 || px == 15 - py;
        if (z) return float4(1.0, 1.0, 1.0, 0.3 + 0.2 * sin(t * 2.0));
    }
    return float4(0.0);
}
