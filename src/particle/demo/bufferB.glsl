#iChannel0 'file://./bufferA.glsl'
#iChannel1 'self'


// display with motion blur   ( no use of parallelism :-( )
// indeed, this is the slowest part. :-( Any idea for optimising ?

#define N 20     // N*N partics. to be changed in all tabs !
#define Nf float(N)
#define Rp 16.
#define Rm 2.
#define PASS 1   // display pass 0 or pass 1

#define tex(i,j) texture(iChannel0, (vec2(i,j)+.5)/iResolution.xy)
#define W(i,j)   tex(i,j+N).z


void mainImage( out vec4 O,  vec2 U )
{
#if 0 // test
    float n = 3.*Nf/iResolution.y,
        r = iResolution.x/iResolution.y;
    U /= iResolution.xy;
	O.xy =  U.x < .5 ? texture(iChannel0,U*n).xy
                     : texture(iChannel0,(U-vec2(2.*n,0))*n).zw;
   if (U.y < 1./3.) O /= iResolution.y;
   else if (U.x>.5 && max((U.x-.5)*r,U.y-1./3.)<1./3.) O = O.x==0. ? vec4(1) : O.x>0. ? vec4(O.x,0,0,1) : vec4(0,0,-O.x,1);
   // O = fract(O);
    
#else    
    
    O = (1.-.05)*texture(iChannel1,U/iResolution.xy); // blur relaxation of past

    for (int j=0; j<N; j++)
        for (int i=0; i<N; i++) 
        {
            vec2 d = tex(i+PASS*N,j).xy - U.xy;
            float l = dot(d,d),
                  w = W(i,j);    // particle vorticity
         // O += 2.*abs(w)/l;
            if (l<Rp)              
              if   (w==0.) O += smoothstep(Rm,Rm/2.,l) * .2; // passiwe marker : white
              else { l = smoothstep(Rp,Rp/2.,l) * .3;        // active vortices : red/blue
                     if (w>0.) O.x += w*l; else O.z += -w*l;
                   }
     }
#endif
    
}
