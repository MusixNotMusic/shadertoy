#iChannel0 'self'
#include 'common.glsl'

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;
   
    float dt = iTimeDelta; 
    float t =  iTime;
    
    if (iFrame % 2 == 0) {
       fragColor = texture(iChannel0, uv);
    } else {
       vec4 tex = texture(iChannel0, uv);
       
       vec2 p = tex.xy;
       vec2 v = tex.zw;
       
       //float t = G(vec2(cos(dt), sin(dt)));
       
       vec2 t = vec2(cos(dt), sin(dt));
       
       vec2 p2 = floor(p / grid) * grid + mod((v * dt * grid), vec2(2.0));

       //vec2 p2 = floor(p / grid) * grid;
    
       // fragColor = vec4(p + v * t, v);
       
       fragColor = vec4(p2, v);
    }
   
    // init
   
    if (iFrame < 1) {
        vec2 position = floor(fragCoord / grid) * grid + grid * 0.5;        
        
        vec2 velocity = rand(fragCoord + 2.13);

        // vec2 velocity = vec2(3.0, 2.0) * vec2(cos(uv.x * PI * 2.0), sin(uv.y * PI * 2.0));
        // vec2 velocity = vec2(2.0, 2.0);

        fragColor = vec4(position, velocity);
    }
}