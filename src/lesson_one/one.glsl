void mainImage(out vec4 fragColor, in vec2 fragCood) {
    vec2 uv = fragCood.xy / iResolution.xy;

    vec2 q = uv - vec2(0.33, 0.7);

    vec3 col = mix(vec3(1.0, .3, 0.0), vec3(1., .8, .3), sqrt(uv.y));

    float r = .2  + 0.1*cos(atan(q.y, q.x) * 10.0 + 20.0 * q.x + 1.0);

    col *= smoothstep(r, r + 0.01, length(q));

    r = 0.015;
    r += .002 * cos(120.0 * q.y);
    r += exp(-40.0 * uv.y);
    col *= 1. - 
        (1. - smoothstep(r, r+.002, abs(q.x - 0.25*sin(2.0 *q.y)))) *
        (1.0 - smoothstep(0.0, 0.1, q.y));

    fragColor = vec4(col, 1.0); 
}