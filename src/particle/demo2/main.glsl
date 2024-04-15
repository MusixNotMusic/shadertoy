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

   fragColor = vec4(position / iResolution.xy, 1.0, 1.0);  
}

// void mainImage( out vec4 col, in vec2 pos )
// {
// 	vec2 R = iResolution.xy; 
// 	float time = iTime;
// 	float dt = 1.0;

//     pos = R*0.495 + pos*0.03; //zoom in
//     ivec2 p = ivec2(pos);
    
//     float rho = 0.; float varr = 0.;
//     range(i, -2, 2) range(j, -2, 2)
//     {
//         vec2 ij = vec2(i,j);

//         vec4 data = texture(iChannel0, vec2(p) + ij);

// 		vec2 position = data.xy;   
		
// 		vec2 velocity = data.zw;

//         rho += smoothstep(0.1, 0.09, distance(pos, position)); 

//     	float rad = dif / 2.;
		
//         varr += smoothstep(0.03, 0.01, sdArrow(pos, position, position + 20. * velocity));
//         varr += smoothstep(0.03, 0.01, sdBox(pos - position - velocity * dt, vec2(rad)));
//     }
    
//     float sdgrid = sdBox(mod(pos + 0.5, vec2(1.0)), vec2(1.0));
   
//     vec3 particles = vec3(0.2)*(rho + varr);
//     vec3 cellcol = vec3(1.);
//    	vec3 grid = cellcol*smoothstep(0.0, -0.1, sdgrid);
	
//     // Output to screen
//     col.xyz = grid - particles;
//     col.xyz = col.xyz;
// }