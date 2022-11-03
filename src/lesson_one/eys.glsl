mat2 m = mat2(0.8, 0.6, -0.6, 0.8);

float hash (float n) 
{
    return fract(sin(n) * 43758.5453);
}

float noise(in vec2 x) {
    vec2 p = floor(x);
    vec2 f = fract(x);
    
    f = f*f*(3.0-2.0*f);
    
    float n = p.x + p.y*57.0;

    return mix(mix( hash(n+ 0.0), hash(n + 1.0), f.x),
               mix( hash(n+ 57.0), hash(n + 58.0), f.x), f.y);
}



float fbm(vec2 p)
{
    float f = 0.0;

    f += 0.50000*noise( p ); p = m*p*2.02;
    f += 0.25000*noise( p ); p = m*p*2.03;
    f += 0.12500*noise( p ); p = m*p*2.01;
    f += 0.06250*noise( p ); p = m*p*2.04;
    f += 0.03125*noise( p );

    return f/0.984375;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord.xy / iResolution.xy;
    vec2 p = -1.0 + 2.0 * q;
    p.x *= iResolution.x / iResolution.y;
    float background = 1.0;

    float r = sqrt( dot(p, p) );
    float a = atan( p.y, p.x );
    vec3 col = vec3(1.0);
    
    if (r < 0.8) {
        col = vec3(0.0, 0.3, 0.4);
        
        float f = fbm(5.0 * p);
        col = mix( col, vec3(0.2, 0.5, 0.4), f);
        // 瞳孔边缘
        f = 1.0 - smoothstep(0.2, 0.4, r);
        col = mix(col, vec3(0.9, 0.6, 0.2), f);

        a += 0.05 * fbm(20.0 * p);
        // a += fbm(15.0 * p);
        //眼白
        f = smoothstep(0.3, 1.0, fbm(vec2(20.0 * a, 6.0 * r)));
        col = mix(col, vec3(1.0), f);

        f = smoothstep(0.4, 0.9, fbm(vec2(15.0 * a, 10.0 * r)));
        col *= 1.0 - 0.5 * f;

        f = smoothstep(0.6, 0.8, r);
        col *= 1.0 - 0.5 * f;
        // 眼仁
        f = 1.0-smoothstep( 0.2, 0.25, r );
        col = mix( col, vec3(0.0), f );
        // 反光 
        f = 1.0 - smoothstep(0.0, 0.5, length(p - vec2(0.24, 0.2)));
        col += vec3(1.0, 0.9, 0.8) * f * 0.9;

        f = smoothstep( 0.75, 0.8, r );
        col = mix( col, vec3(1.0), f);
    }

    fragColor = vec4(col * background, 1.0);
}