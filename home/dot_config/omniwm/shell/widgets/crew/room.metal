// The Agents tab's office, behind the desks (desk.metal) and the critters (avatar.metal),
// on a grid of values.z points per pixel: a wall with a clock and a picture, a wooden
// floor, a counter with the coffee machine on the left, the lounge on the right (lamp,
// rug, three poufs, a swaying plant). Positions match component.luau.
// values.x: minutes since midnight, for the clock's hands.
// values.y: 1 while someone gets a coffee (the machine brews and steams).

constant int TRIM = 29;    // the wainscot's top
constant int WALL_END = 41;
constant int FLOOR_Y = 44;
constant int GROUND = 58;  // things stand on this row: their last row is GROUND - 1

float3 hex(uint c) {
    return float3(float((c >> 16) & 255u), float((c >> 8) & 255u), float(c & 255u)) / 255.0;
}

float noise(int a, int b) {
    return fract(sin(float(a) * 12.9898 + float(b) * 78.233) * 43758.5453);
}

// A pouf: 18 wide and 9 tall, rounder on top.
bool pouf(int x, int y, int center) {
    int r = y - (GROUND - 9);
    if (r < 0 || r > 8) return false;
    int span = r == 0 ? 5 : (r == 1 ? 7 : (r == 8 ? 8 : 9));
    int dx = x - center;
    return dx >= -span && dx < span;
}

float4 shade(float2 uv, constant OmniShader& shader) {
    float pix = max(1.0, shader.values.z);
    int W = int(shader.size.x / pix);
    int H = int(shader.size.y / pix);
    int x = int(uv.x * shader.size.x / pix);
    int y = int(uv.y * shader.size.y / pix);
    float t = shader.time;
    bool brewing = shader.values.y > 0.5;
    int lamp = W - 79;
    int poufs[3] = { W - 67, W - 46, W - 25 };
    int plant = W - 8;

    // Wall, baseboard, floor.
    float3 c;
    if (y <= WALL_END) {
        c = y > TRIM ? hex(0x20232B) : (y == TRIM ? hex(0x2C303A) : hex(0x1B1D24));
        if (y < TRIM && x % 24 == 0) c = hex(0x1E2029);
    } else if (y < FLOOR_Y) {
        c = hex(0x343844);
    } else {
        int row = y - FLOOR_Y;
        c = hex(0x2A211B);
        if (row % 4 == 3 || (x + (row / 4) * 13) % 31 == 0) c = hex(0x221A15);
        c *= 0.88 + 0.16 * float(row) / float(max(1, H - FLOOR_Y));
    }

    // The lamp's warm light on the wall and floor, breathing a little.
    float glow = length(float2(x - lamp, (y - 19) * 1.3));
    c = mix(c, hex(0xFFD9A0), 0.13 * max(0.0, 1.0 - glow / 22.0) * (0.9 + 0.1 * sin(t * 1.7)));

    // A wall clock with the real time.
    {
        float2 p = float2(x - 108, y - 12);
        float d = length(p);
        if (d <= 5.6) {
            c = d > 4.6 ? hex(0x3A3F4B) : hex(0xE6E6E6);
            float minutes = shader.values.x;
            float m = fract(minutes / 60.0) * 6.2831853;
            float h = fract(minutes / 720.0) * 6.2831853;
            float2 md = float2(sin(m), -cos(m));
            float2 hd = float2(sin(h), -cos(h));
            float along = dot(p, md);
            if (along >= 0.0 && along <= 4.0 && abs(p.x * md.y - p.y * md.x) < 0.6) c = hex(0x1E1E1E);
            along = dot(p, hd);
            if (along >= 0.0 && along <= 2.7 && abs(p.x * hd.y - p.y * hd.x) < 0.7) c = hex(0x1E1E1E);
            if (x == 108 && y == 12) c = hex(0xD97757);
        }
    }

    // A small framed picture over the lounge: a terracotta sun on a dusk sky.
    {
        int px = x - (W - 58), py = y - 7;
        if (px >= 0 && px <= 15 && py >= 0 && py <= 10) {
            bool frame = px == 0 || px == 15 || py == 0 || py == 10;
            c = frame ? hex(0x8A6A4A) : (py < 6 ? hex(0x2E3A5C) : hex(0x3E4A6C));
            if (!frame && length(float2(px - 8, py - 6)) < 3.2) c = hex(0xD97757);
            if (!frame && py >= 7) c = hex(0x26303F);
        }
    }

    // The counter with the coffee machine (and a little succulent).
    if (x >= 2 && x <= 20 && y >= 45 && y < GROUND) {
        c = y == 45 ? hex(0x4A505E) : hex(0x3A3F4B);
        if (x == 11 && y > 46) c = hex(0x2C303A);
        if ((x == 9 || x == 13) && y == 49) c = hex(0x8A8F9B);
    }
    if (x >= 16 && x <= 19 && y >= 41 && y <= 44) {
        if (y >= 43) c = hex(0xA65A3A);
        else if ((x + y) % 2 == 0 || y == 42) c = hex(0x3FA45B);
    }
    if (x >= 5 && x <= 14 && y >= 31 && y <= 44) {
        c = y <= 32 ? hex(0x3A3F4B) : hex(0x2B2E36);
        if (x >= 6 && x <= 13 && y >= 33 && y <= 35) c = hex(0x5A6070);
        if (x == 12 && y == 34) {
            c = brewing ? (fract(t * 2.0) < 0.5 ? hex(0xFF453A) : hex(0x7A2420)) : hex(0x2F7A44);
        }
        if (x >= 7 && x <= 12 && y >= 37 && y <= 43) c = hex(0x111216);
        if (brewing && (x == 9 || x == 10)) {
            if (y >= 37 && y <= 41 && fract(t * 3.0 + float(y) * 0.2) < 0.6) c = hex(0x6B4226);
            if (y >= 42) c = hex(0xEDEDED);
        }
    }
    // Steam: one wavy wisp rising from the machine, fading as it goes up.
    if (brewing && y >= 24 && y <= 30) {
        int wisp = 9 + int(round(sin(t * 2.6 - float(y) * 0.8) * 1.4));
        if (x == wisp && fract(t * 0.8 - float(y) * 0.11) < 0.75) {
            c = mix(c, hex(0xD0D4DC), 0.25 + 0.05 * float(y - 24));
        }
    }

    // The lounge: a floor lamp, the rug, three poufs, a plant in the corner.
    if (x == lamp && y >= 21 && y < GROUND - 1) c = hex(0x555A66);
    if (y == GROUND - 1 && abs(x - lamp) <= 2) c = hex(0x555A66);
    if (y >= 15 && y <= 20) {
        int span = 2 + (y - 15) / 2;
        if (abs(x - lamp) <= span) c = y == 20 ? hex(0xFFE6B8) : hex(0xE8D8B0);
    }
    {
        float2 p = float2(float(x - (W - 46)) / 34.0, float(y - GROUND) / 3.5);
        float d = length(p);
        if (d <= 1.0) c = d > 0.82 ? hex(0x4A3C5C) : hex(0x3B2F4A);
    }
    uint colors[3] = { 0x2E8C86u, 0xC99A2Eu, 0x8E4A7Eu };
    for (int i = 0; i < 3; i++) {
        if (pouf(x, y, poufs[i])) {
            float3 base = hex(colors[i]);
            int r = y - (GROUND - 9);
            c = r <= 1 ? min(base * 1.25, 1.0) : (r >= 7 ? base * 0.7 : base);
            if (r == 4 && (x - poufs[i]) % 5 == 0) c = base * 0.82;
        }
    }
    if (x >= plant - 4 && x <= plant + 4 && y >= GROUND - 8 && y < GROUND) {
        c = y == GROUND - 8 ? hex(0xB86B49) : hex(0xA65A3A);
    }
    if (y >= 30 && y < GROUND - 8) {
        float height = float(GROUND - 9 - y);
        int sway = int(round(sin(t * 1.3 + height * 0.25) * height / 12.0));
        int dx = x - plant - sway;
        int spread = 1 + int(3.0 * sin(float(y - 30) / float(GROUND - 38) * 3.1415926));
        if (abs(dx) <= spread && noise(dx, y) > 0.18) {
            c = (x + y) % 3 == 0 ? hex(0x2E7D45) : hex(0x3FA45B);
        }
    }
    return float4(c, 1.0);
}
