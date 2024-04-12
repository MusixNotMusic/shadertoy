#iChannel0 'file://./bufferA.glsl'

#include 'common.glsl'

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;

    // Output to screen
   vec4 tex = texture(iChannel0, uv);
   
   vec2 position = tex.xy;   
   
   vec2 velocity = tex.zw;
   
   if (length(position - fragCoord) < 10.0) {
	   fragColor = vec4(position / iResolution.xy, 1.0, 1.0);
   } 
//    else {
	   fragColor = vec4(position / iResolution.xy, 1.0, 1.0);  
//    }
}