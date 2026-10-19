#version 440
// Kalyna liquid glass: a rounded slab of glass that bends what is behind it near its edges
// (like a lens), softly blurs it, splits colours a little at the rim and catches light on the
// top-left edge. Same idea as the web edition's SVG lens, done in one GPU pass.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;     // glass size in pixels
    vec2 srcSize;      // backdrop texture size in pixels (glass + 2 * pad)
    float pad;         // extra backdrop around the glass (so the edge can bend light from outside)
    float radius;      // corner radius in pixels
    float refraction;  // how far the edge pulls the image, in pixels
    float blur;        // blur radius in pixels
    float chroma;      // colour split at the rim (0..0.3)
    float rim;         // edge highlight strength
    float tintAmt;     // 0 = clear, 1 = solid tint
    vec4 tint;
};
layout(binding = 1) uniform sampler2D src;

float sdRoundBox(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main()
{
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 h = itemSize * 0.5;
    float r = min(radius, min(h.x, h.y));
    float d = sdRoundBox(p - h, h, r);                // < 0 inside the glass
    if (d > 1.0) {
        fragColor = vec4(0.0);
        return;
    }
    float aa = clamp(0.5 - d, 0.0, 1.0);

    // surface normal from the distance field
    const float e = 1.0;
    vec2 grad = vec2(sdRoundBox(p - h + vec2(e, 0.0), h, r) - sdRoundBox(p - h - vec2(e, 0.0), h, r),
                     sdRoundBox(p - h + vec2(0.0, e), h, r) - sdRoundBox(p - h - vec2(0.0, e), h, r));
    vec2 n = dot(grad, grad) > 1e-6 ? normalize(grad) : vec2(0.0);

    // the glass is thick in the middle and curves down at the rim: light bends most there
    float thickness = clamp(-d / max(6.0, min(h.x, h.y)), 0.0, 1.0);
    float bend = pow(1.0 - thickness, 2.6);
    vec2 offset = n * bend * refraction;              // sample from further out: the rim magnifies

    vec2 base = (p + vec2(pad)) / srcSize;
    vec2 o = offset / srcSize;
    vec2 px = vec2(blur * 0.5) / srcSize;

    vec3 col = vec3(0.0);
    float wsum = 0.0;
    for (int i = -2; i <= 2; ++i) {
        for (int j = -2; j <= 2; ++j) {
            vec2 bo = vec2(float(i), float(j)) * px;
            float w = exp(-float(i * i + j * j) / 4.5);
            col.r += texture(src, base + o * (1.0 + chroma) + bo).r * w;
            col.g += texture(src, base + o + bo).g * w;
            col.b += texture(src, base + o * (1.0 - chroma) + bo).b * w;
            wsum += w;
        }
    }
    col /= wsum;

    // a touch brighter and more saturated, like real glass over a lit scene
    float l = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(l), col, 1.25) * 1.05 + 0.015;
    col = mix(col, tint.rgb, tintAmt);

    // rim light: bright on the top-left edge, a faint reflection on the bottom-right
    float edge = smoothstep(3.0, 0.0, -d);
    float lit = max(dot(n, normalize(vec2(-0.55, -0.85))), 0.0);
    float back = max(dot(n, normalize(vec2(0.55, 0.85))), 0.0);
    col += edge * (lit * 0.6 + back * 0.22) * rim;
    // a soft inner glow along the whole rim
    col += smoothstep(10.0, 0.0, -d) * 0.04 * rim;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * aa * qt_Opacity;
}
