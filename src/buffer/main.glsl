#iChannel0 "file://D:/_workspace/shadertoy/src/buffer/bufferA.glsl"

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{  
	vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 col = texture(iChannel0, uv);
    fragColor = vec4(col.rgb, 1.);
}
