// One seat at a white desk of the Agents tab's office, on a 22 × 22 pixel canvas: chair,
// keyboard, monitor, and its agent at work (the same critter as avatar.metal) or an empty
// chair. Seats drawn side by side make one desk; values.w says which ends of it this one is.
// values.x: 0 working (types, code scrolls on a green screen), 1 needs you (waves, the
// screen blinks yellow, a "!" over its head), 2 errored (shakes, red screen, smoke), 3 away
// (empty chair, monitor asleep).
// values.y: phase offset in seconds, so seats don't move in step.
// values.z: 1 for Claude (terracotta), 0 for other harnesses (grey).
// values.w: 1 the desk's left end, 2 its right end, 3 both (a desk of one seat), 0 a middle seat.

constant int RAISED = -1;

float3 hex(uint c) {
    return float3(float((c >> 16) & 255u), float((c >> 8) & 255u), float(c & 255u)) / 255.0;
}

float noise(int a, int b) {
    return fract(sin(float(a) * 12.9898 + float(b) * 78.233) * 43758.5453);
}

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
    int state = int(shader.values.x + 0.5);
    float t = shader.time + shader.values.y;
    int ends = int(shader.values.w + 0.5);
    bool leftEnd = (ends & 1) != 0, rightEnd = (ends & 2) != 0;
    int x = int(min(floor(uv.x * 22.0), 21.0));
    int y = int(min(floor(uv.y * 22.0), 21.0));
    int fast = int(floor(t * 6.0)) & 1;
    int slow = int(floor(t * 3.0)) & 1;

    // Over the monitor: smoke while it errored.
    if (state == 2 && y <= 1 && x >= 16 && x <= 20) {
        float rise = fract(t * 0.9 + float(x) * 0.37);
        int puff = 1 - int(rise * 2.0);
        if (y == puff && noise(x, int(floor(t * 0.9 + float(x) * 0.37))) > 0.35) {
            return float4(hex(0x8A8F9B), 0.8 - 0.3 * float(1 - y));
        }
    }
    // Over its head: a blinking yellow "!" while it waits for you.
    if (state == 1 && (x == 7 || x == 8) && (y <= 2 || y == 4) && fract(t * 1.6) < 0.75) {
        return float4(hex(0xFFD60A), 1.0);
    }

    // The monitor: bezel, screen, stand.
    if (x >= 15 && x <= 21 && y >= 2 && y <= 9) {
        if (x >= 16 && x <= 20 && y >= 3 && y <= 8) {
            int sx = x - 16, sy = y - 3;
            if (state == 0) {
                int line = sy + int(floor(t * 2.5));
                int indent = int(noise(line, 7) * 2.0);
                int run = 1 + int(noise(line, 3) * 3.0);
                bool lit = sx >= indent && sx < indent + run;
                if (sy == 5 && sx == indent + run && fast == 1) return float4(hex(0xB8F5C9), 1.0);
                return float4(lit ? hex(0x46D07A) : hex(0x0F2A1A), 1.0);
            }
            if (state == 1) return float4(mix(hex(0x6B5A10), hex(0xFFD60A), 0.6 + 0.4 * sin(t * 5.0)), 1.0);
            if (state == 2) return float4(hex(0xFF453A) * (fract(t * 7.0) < 0.5 ? 1.0 : 0.6), 1.0);
            return float4(hex(0x101217), 1.0);
        }
        if (state == 3 && x == 20 && y == 9) {
            return float4(mix(hex(0x22252C), hex(0x30D158), 0.5 + 0.5 * sin(t * 1.5)), 1.0);
        }
        return float4(hex(0x22252C), 1.0);
    }
    if (x == 18 && y == 10) return float4(hex(0x3A3F4B), 1.0);
    if (x >= 17 && x <= 19 && y == 11) return float4(hex(0x3A3F4B), 1.0);

    // Keyboard and mouse on the desk, dark against the white top.
    if (y == 11 && ((x >= 4 && x <= 10) || x == 12)) return float4(hex(0x4A505E), 1.0);

    // The white desk: top, a drawer unit per seat (shaded at the bottom), legs at its ends.
    if (y == 12) return float4(hex(0xF5F5F3), 1.0);
    if (y == 13) return float4(hex(0xD6D6D2), 1.0);
    if (y >= 14 && y <= 18 && x >= (leftEnd ? 1 : 0) && x <= (rightEnd ? 20 : 21)) {
        if (y == 16 && x >= 9 && x <= 12) return float4(hex(0x9DA1AA), 1.0);
        if (y == 18 || (x == 0 && !leftEnd)) return float4(hex(0xC4C4C0), 1.0);
        return float4(hex(0xE4E4E0), 1.0);
    }
    if (y >= 19 && ((leftEnd && (x == 1 || x == 2)) || (rightEnd && (x == 19 || x == 20)))) {
        return float4(hex(0xB8B9BC), 1.0);
    }

    // Its agent, at the desk.
    if (state != 3) {
        int bob = 0, shake = 0, leftArm = 3, rightArm = 3;
        bool eyes = fract(t / 3.7) > 0.04;
        if (state == 0) {
            bob = int(floor(t * 4.0)) & 1;
            leftArm = 3 + fast;
            rightArm = 4 - fast;
        } else if (state == 1) {
            rightArm = slow == 1 ? RAISED : 1;
        } else {
            shake = fract(t * 0.7) < 0.3 ? fast * 2 - 1 : 0;
            leftArm = 4;
            rightArm = 4;
        }
        if (critter(x - 1 - shake, y - 5 + bob, leftArm, rightArm, eyes)) {
            if (state == 2) return float4(hex(0xFF453A), 1.0);
            return shader.values.z > 0.5 ? float4(hex(0xD97757), 1.0) : float4(hex(0xBDBDC7), 1.0);
        }
    }

    // The chair behind it.
    if (x >= 2 && x <= 13 && y >= 3 && y <= 11) {
        bool edge = x == 2 || x == 13 || y == 3;
        return float4(edge ? hex(0x3F4452) : hex(0x343844), 1.0);
    }
    return float4(0.0);
}
