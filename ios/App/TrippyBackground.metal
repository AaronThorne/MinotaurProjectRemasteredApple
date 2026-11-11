#include <metal_stdlib>
using namespace metal;

struct BackgroundUniforms {
    float2 resolution;
    float time;
    float motion;
    uint4 sprites;
};

vertex float4 minotaurBackgroundVertex(uint vertexID [[vertex_id]]) {
    constexpr float2 corners[3] = {float2(-1,-1), float2(3,-1), float2(-1,3)};
    return float4(corners[vertexID], 0, 1);
}

float3 spectrum(float phase) {
    return 0.5 + 0.5 * cos(6.2831853 * (phase + float3(0.0, 0.33, 0.67)));
}

float hash21(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float4 spritePixel(texture2d<float> sheet, float2 offset, float width, float4 crop, bool flip) {
    float2 uv = offset * float2(1.0, crop.z / crop.w) / width + 0.5;
    if (any(uv < 0.0) || any(uv >= 1.0)) return 0.0;
    if (flip) uv.x = 1.0 - uv.x;
    constexpr sampler nearest(filter::nearest, address::clamp_to_edge);
    float2 atlasPixel = crop.xy + clamp(floor(uv * crop.zw), 0.0, crop.zw - 1.0) + 0.5;
    return sheet.sample(nearest, atlasPixel / float2(sheet.get_width(), sheet.get_height()));
}

float3 paintSprite(float3 background, texture2d<float> sheet, float2 position, float aspect,
                   float2 anchor, float width, float4 crop, float phase, float hue, bool flip) {
    if (sheet.get_width() == 1) return background;
    float2 offset = (position - anchor) * float2(aspect, 1.0);
    offset -= float2(0.028 * sin(phase), 0.027 * cos(phase * 1.2));
    float2 trail = float2(cos(phase), -sin(phase * 1.2)) * width * 0.19;
    float4 far = spritePixel(sheet, offset + trail * 2.0, width, crop, flip);
    float4 near = spritePixel(sheet, offset + trail, width, crop, flip);
    float4 sprite = spritePixel(sheet, offset, width, crop, flip);
    background = mix(background, spectrum(hue + 0.25), far.a * 0.27);
    background = mix(background, spectrum(hue), near.a * 0.40);
    return mix(background, mix(sprite.rgb, spectrum(hue + 0.12), 0.17), sprite.a * 0.92);
}

float3 paintPickerSprite(float3 ink, uint choice, array<texture2d<float>, 5> sheets,
                         float2 position, float aspect, float2 anchor, float width,
                         float phase, float hue, float time, bool onLeft) {
    uint atlas = 0;
    float4 crop;
    bool flip = false;
    switch (choice) {
        case 1: // Minotron camel, two walking frames.
            crop = fmod(floor(time * 3.0), 2.0) < 1.0 ? float4(19,108,26,22) : float4(46,108,26,22);
            flip = onLeft;
            break;
        case 2: // Minotron pixel sheep.
            crop = float4(156,270,28,22);
            flip = onLeft;
            break;
        case 3: // GoatUp 2 goat.
            atlas = 4;
            crop = float4(160,225,30,23);
            flip = onLeft;
            break;
        case 6: // Minotron rainbow-shirt minotaur.
            crop = float4(66,304,32,42);
            break;
        case 7: // Deflex white camel.
            atlas = 3;
            crop = float4(48,70,48,42);
            flip = !onLeft;
            break;
        case 9: // Super Ox Wars fighter.
            atlas = 1;
            crop = float4(173,79,15,16);
            break;
        case 11: // Gridrunner invader.
            atlas = 2;
            crop = float4(1,65,32,32);
            break;
        default:
            return ink;
    }
    return paintSprite(ink, sheets[atlas], position, aspect, anchor, width, crop, phase, hue, flip);
}

fragment float4 minotaurBackgroundFragment(float4 pixel [[position]],
                                          constant BackgroundUniforms &u [[buffer(0)]],
                                          array<texture2d<float>, 5> sheets [[texture(0)]]) {
    float t = u.motion > 0.0 ? u.time : 2.4;
    float2 position = pixel.xy / u.resolution;
    float aspect = u.resolution.x / u.resolution.y;
    float2 p = (position - 0.5) * float2(aspect, 1.0) * 2.0;

    // Fold a warped polar field into six mirrored petals.
    float2 q = p + 0.16 * sin(p.yx * 3.3 + float2(t * 0.44, -t * 0.39));
    float r = length(q);
    float angle = atan2(q.y, q.x) + 0.22 * sin(r * 4.3 - t * 0.54);
    float petal = abs(cos(angle * 3.0));
    float weave = sin(r * 8.0 - t * 1.05 + petal * 3.8);
    float ribs = sin(r * 20.0 + petal * 4.0 - t * 1.55);
    float ribbon = exp(-12.0 * abs(weave));
    float wire = exp(-26.0 * abs(ribs));
    float flare = pow(petal, 9.0) * smoothstep(0.10, 0.48, r);
    float silk = pow(0.5 + 0.5 * cos(r * 10.0 - petal * 5.0 + t * 0.85), 2.0);
    float rim = smoothstep(0.32, 1.12, length(p));
    float3 ink = float3(0.018, 0.010, 0.074);
    ink += spectrum(0.65 + weave * 0.16 + r * 0.11 - t * 0.025) * (0.12 + petal * 0.11);
    ink += spectrum(r * 0.39 + petal * 0.24 - t * 0.052) * (0.16 + silk * 0.30);
    ink += spectrum(r * 0.23 + t * 0.036 + petal * 0.16) * (ribbon * 0.55 + wire * 0.26 + flare * 0.12);

    // Pixel stars move behind the sprites, with brighter colour around the perimeter.
    float2 starGrid = p * 23.0 + float2(t * 0.27, t * 0.16);
    float random = hash21(floor(starGrid));
    float2 starPixel = abs(fract(starGrid) - 0.5);
    float spark = step(starPixel.x + starPixel.y, 0.10) * step(0.947, random);
    ink *= 0.60 + 0.40 * rim;
    ink += spectrum(random + t * 0.02) * spark * 0.75;
    ink *= 0.95 + 0.05 * cos(pixel.y * 3.14159265);

    float scale = min(aspect, 1.0);
    float edge = aspect < 0.8 ? 0.16 : 0.10;
    ink = paintPickerSprite(ink, u.sprites.x, sheets, position, aspect, float2(edge, 0.29),
                            0.15 * scale, t * 0.84, 0.76, t, true);
    ink = paintPickerSprite(ink, u.sprites.y, sheets, position, aspect, float2(1.0 - edge, 0.28),
                            0.15 * scale, t * 0.70 + 2.3, 0.54, t, false);
    ink = paintPickerSprite(ink, u.sprites.z, sheets, position, aspect, float2(edge * 0.88, 0.72),
                            0.12 * scale, t * 0.89 + 4.0, 0.85, t, true);
    ink = paintPickerSprite(ink, u.sprites.w, sheets, position, aspect, float2(1.0 - edge * 0.91, 0.75),
                            0.12 * scale, t * 0.95 + 3.0, 0.40, t, false);
    return float4(ink, 1);
}
