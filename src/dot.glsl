void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord.xy - .5 * iResolution.xy) / iResolution.y;
    vec3 col = vec3(0);
    // if (length(vec2(uv.x,  uv.y)) < 0.25) {
      col = vec3(clamp(cos(uv.x), 0.3, .9), clamp(sin(uv.y), 0.4, .8), 1);
    // }
    fragColor = vec4(col, 1.);
}