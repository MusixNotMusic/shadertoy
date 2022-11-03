#define sqrt2 0.707107
// #define sqrt2 0.1

float noise(vec2 p) {
    return abs(fract(114514.114514 * sin(dot(p, vec2(123., 456.)))));
}

float line(vec2 p, float dir) {
    float d = dot(p, dir > 0.5 ? vec2(sqrt2, sqrt2) : vec2(-sqrt2, sqrt2));
    // return smoothstep(.01, 0., abs(d));
    return smoothstep(.01, 0., abs(d));
    // return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = 5. * 2. * (fragCoord - .5 * iResolution.xy) / iResolution.y;
    p += iTime / 5.;
    vec3 col = vec3(line(fract(p) - .5, noise(floor(p))));
    fragColor = vec4(col, 1.);
}