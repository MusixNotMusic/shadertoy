//Track mouse movement and resolution change between frames and set camera position.

#iChannel0 "file://./bufferB.glsl"
#iChannel1 "self"
//Simple cloud map to define where clouds occur.

float circularOut(float t) {
  return sqrt((2.0 - t) * t);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    
    bool resolutionChanged = (texelFetch(iChannel0, ivec2(0.5, 2.5), 0).x == 1.0);
    
    //Draw map at the first frame or when the resolution has changed.
    if(iFrame < 1 || resolutionChanged){
    	vec2 uv = fragCoord/iResolution.xy;
        uv -= 0.5;

        //Three overlapping circles.
        uv *= 5.0;
        float dist = circularOut(max(0.0, 1.0-length(uv)));
        uv *= 1.2;
        dist = max(dist, 0.8*circularOut(max(0.0, 1.0-length(uv+0.65))));
        uv *= 1.3;
        dist = max(dist, 0.75*circularOut(max(0.0, 1.0-length(uv-0.75))));

        vec3 col = vec3(dist);

        fragColor = vec4(col,1.0);
    }else{
        //Reuse data in buffer.
    	fragColor = texelFetch(iChannel1, ivec2(fragCoord - 0.5), 0).rgba;;
    }
}