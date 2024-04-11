
#define PI				3.1415926535
#define SQRT2			0.707

#define LIGHT_DIR		normalize(vec3(cos(-iTime*.3+PI*.5), 1.0, sin(-iTime*.3+PI*.5)))
#define CAM_SPEED		.3
#define CAM_POS 		vec3(4.*cos(-iTime*CAM_SPEED), 4.0, 4.*sin(-iTime*CAM_SPEED))

const int KEY_LEFT  = 37;
const int KEY_UP    = 38;
const int KEY_RIGHT = 39;
const int KEY_DOWN  = 40;
const int KEY_A     = 65;
const int KEY_B     = 66;
const int KEY_C     = 67;
const int KEY_D     = 68;
const int KEY_E     = 69;
const int KEY_F     = 70;
const int KEY_G     = 71;
const int KEY_H     = 72;
const int KEY_I     = 73;
const int KEY_J     = 74;
const int KEY_K     = 75;
const int KEY_L     = 76;
const int KEY_M     = 77;
const int KEY_N     = 78;
const int KEY_O     = 79;
const int KEY_P     = 80;
const int KEY_Q     = 81;
const int KEY_R     = 82;
const int KEY_S     = 83;
const int KEY_T     = 84;
const int KEY_U     = 85;
const int KEY_V     = 86;
const int KEY_W     = 87;
const int KEY_X     = 88;
const int KEY_Y     = 89;
const int KEY_Z     = 90;
const int KEY_SPACE = 32;

#iChannel0 "file://../../resource/buffer00.png"
#define KEY_PRESSED(KEY) !(texelFetch( iChannel1, ivec2(KEY,2), 0 ).x>0.5)


// strait from https://iquilezles.org/articles/boxfunctions
// added a parameter for the far intersection normal computation
vec2 boxIntersection( vec3 ro, vec3 rd, vec3 boxSize, mat4 txx, out vec3 outNormal, out vec3 outNormal2 )
{
    // convert from ray to box space
    vec3 rdd = (txx*vec4(rd,0.0)).xyz;
    vec3 roo = (txx*vec4(ro,1.0)).xyz;

    vec3 m = 1.0/rd;
    vec3 n = m*roo;
    vec3 k = abs(m)*boxSize;

    vec3 t1 = -n - k;
    vec3 t2 = -n + k;

    float tN = max( max( t1.x, t1.y ), t1.z );
    float tF = min( min( t2.x, t2.y ), t2.z );

    if( tN > tF || tF < 0.0) return vec2(-1.0); // no intersection

    outNormal = -sign(rdd)*step(t1.yzx,t1.xyz)*step(t1.zxy,t1.xyz);
    
    vec3 d = abs(roo+rdd*tF);
    outNormal2 = -sign(rdd)*vec3(d.x>d.y&&d.x>d.z?1.:0., d.y>d.x&&d.y>d.z?1.:0., d.z>d.y&&d.z>d.x?1.:0.);

    return vec2( tN, tF );
}


float getVal(in vec3 p)
{
    vec4 val0 = texture(iChannel0, p.xz*.5+vec2(.5));
    p.y *= .5;
    
    //return p.y;
    //return length(p*vec3(1.,2.,1.)-vec3(1., 1., -1.));
    //return min(min(length(p*vec3(1.,2.,1.)-vec3(1., 1., -1.)), length(p*vec3(1.,2.,1.)-vec3(1., 0., 1.))),length(p*vec3(1.,2.,1.)-vec3(-1., 1., 0.)));
    
    //return mix(val0.x, val0.z, p.y);
    
    
    //float t = mod(3.*p.y, 1.);
    //t = smoothstep(0., 1., t);
    
    if(p.y<1./3.)
        //return mix(val0.x, val0.y, p.y*3.);
        return mix(val0.x, val0.y, smoothstep(0., 0.333, p.y));
    
    if(p.y<2./3.)
        //return mix(val0.y, val0.z, (p.y-1./3.)*3.);
        return mix(val0.y, val0.z, smoothstep(0.333, 0.666, p.y));
    
    //return mix(val0.z, val0.w, (p.y-2./3.)*3.);
    return mix(val0.z, val0.w, smoothstep(0.666, 1., p.y));
}


vec3 getNorm(in vec3 p)
{
    vec2 d = vec2(0.01, 0.);
    
    return vec3(getVal(p+d.xyy)-getVal(p), getVal(p+d.yxy)-getVal(p), getVal(p+d.yyx)-getVal(p));
}


float marchIso(vec3 ro, vec3 rd, float t_min, float t_max, float iso)
{
    float t;
    float dt = 0.01;
    
    
    vec3 p = ro+rd*(t_min);
    float inv = getVal(p)>iso?1.0:-1.0;
    //inv = 1.;
    
    for(t = t_min; t<t_max; t += dt)
    {
        p = ro+rd*t;
        float val = getVal(p);

        if((val-iso)*inv < 0.)
        {
            break;
        }
    }
    
    return t;
}


float marchMultiIso(vec3 ro, vec3 rd, float t_min, float t_max, float iso_[6], out int kkk)
{    
    float val = getVal(ro+rd*(t_min));

    int iso_k[2] = int[](0, 0);

    int kk;
    for(kk = 0; kk<iso_.length(); ++kk)
        if(val < iso_[kk])
            break;

    iso_k[0] = (val<iso_[0]) ? -1: kk-1;
    iso_k[1] = (val>iso_[iso_.length()-1]) ? -1: kk;
    

    float t_int = t_max;
    for(int k = 0; k<2; ++k)
    {
        if(iso_k[k] == -1)
            continue;

        float tt = marchIso(ro, rd, t_min, t_max, iso_[iso_k[k]]);

        if(tt < min(t_int, t_max))
        {
            t_int = tt;
            kkk = iso_k[k];
        }
    }
    
    return min(t_int, t_max);
}



float distIsoLine(vec3 p, vec3 n, vec3 grad, float iso, float val)
{
	return abs(val-iso)/length(grad);
}


vec3 render(in vec3 ro, in vec3 rd)
{
    
    float t = (-0.-ro.y)/rd.y;
    
    //t = 100.0;
    
    
    if(t<0. || rd.y >0.)
    	t = 10000.;
    
    vec3 col = mix(vec3(0.9), vec3(0.5,0.6,0.9), 1.-exp(-0.05*t));
    
    vec3 n, n2;    
        
    vec3 size = vec3(1.);
    mat4 txx = mat4(1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1., 0., 0. , -1., 0., 1.);
    
    
    float iso_[6] = float[](0.083, 0.25, 0.416, 0.583, 0.75, 0.916);
    vec3  color[6]     = vec3[](
        vec3(1., 0., 0.),
        vec3(SQRT2, SQRT2, 0.), 
        vec3(0., 1., 0.), 
        vec3(0., SQRT2, SQRT2), 
        vec3(0., 0., 1.), 
        vec3(SQRT2, 0., SQRT2));
    
    
    if(t<100.)
    {
        vec3 roo = ro+rd*t;
        vec3 rdd = LIGHT_DIR;

        vec2 tnf = boxIntersection(roo, rdd, size, txx, n, n2);
        
        float t_min = max(0., tnf.x), t_max = tnf.y;
        float depth = max(0., t_max-t_min);

        // shadow
        if(depth > 0. && KEY_PRESSED(KEY_S))
        {
            int kk;
            float tt = 0.;
    		if(KEY_PRESSED(KEY_C))
            	tt = marchMultiIso(roo, rdd, t_min, t_max, iso_, kk);
            if(tt < t_max)
            {
            	col *= 0.5;
            }
        }
        
        // ambiant occlusion (extremely cheap)
        
        if(KEY_PRESSED(KEY_C))
        {
            float val = getVal(roo);
            vec3 grad = getNorm(roo);
            grad.y = 0.;
            float w = 100.;
            for(int k = 0; k<6; ++k)
            {
                w = min(w,abs(val-iso_[k])/length(grad));
            }
            w = max(w, max(max(abs(roo.x),abs(roo.z)) - 1., 0.)*100.);
            w = clamp(w/12., 0., 1.);
            col *= 0.6+0.4*smoothstep(0., 1.0, w);
        }
    }
    
    
    vec2 tnf = boxIntersection(ro, rd, size, txx, n, n2);
    
    float t_min = max(0., tnf.x), t_max = min(t, tnf.y);
    float depth = max(0., t_max-t_min);
    
    if(depth > 0.)
    {
    	if(KEY_PRESSED(KEY_C))
        {
            int kk;
            float tt = marchMultiIso(ro, rd, t_min, t_max, iso_, kk);
            if(tt < t_max)
            {
                vec3 cur_col = color[kk];
                vec3 p = ro + rd*tt;
                vec3 nn = normalize(getNorm(p));

                if(dot(nn, rd) > 0.)
                {
                    cur_col = 0.4+0.6*cur_col;
                    nn *= -1.;
                }
                col = cur_col*(0.5+0.5*max(0.,dot(nn, LIGHT_DIR))) 
                    + vec3(pow(max(0.,dot(LIGHT_DIR, reflect(rd, nn))), 128.));
                t_max = tt;
            }
        }
        else
        {
            vec3 cur_col = vec3(1.0);
            
            float val = getVal(ro + rd*tnf.x);
            for(int kk = 0; kk<6; ++kk)
                if(val < iso_[kk])
                {
                    cur_col = color[kk];
                    break;
                }
            col = cur_col*(0.5+0.5*max(0., dot(n, LIGHT_DIR)));
            tnf.y = tnf.x + 0.001;
        }
    }
    
    
    // isolines
    float line_width = .2;
    if(KEY_PRESSED(KEY_I) && depth > 0.001)
    {
    	// front facing
        vec3 p = ro+rd*(tnf.x+0.01);
        float val = getVal(p);
        vec3 grad = getNorm(p);
        grad -= n*dot(grad,n);
        for(int k = 0; k<6; ++k)
        {
            float w = abs(val-iso_[k])/length(grad);
            col = mix(col, 
                      color[k]*.1, 
                      mix(1., 0., clamp((w-line_width*tnf.x),0.,1.)));
        }
        
    	// back facing
        if(tnf.y<t_max+0.01)
        {
            p = ro+rd*(tnf.y-0.01);
            val = getVal(p);
            vec3 grad = getNorm(p);
            grad -= n2*dot(grad,n2);
            for(int k = 0; k<6; ++k)
            {
                float w = abs(val-iso_[k])/length(grad);
                col = mix(col, color[k]*.1, mix(1., 0., clamp((w-line_width*tnf.y),0.,1.)));
            }
        }
    }
    
    
    
    return col;
}


mat3 setCamera( in vec3 ro, in vec3 ta, float cr )
{
	vec3 cw = normalize(ta-ro);
	vec3 cp = vec3(sin(cr), cos(cr),0.0);
	vec3 cu = normalize( cross(cw,cp) );
	vec3 cv = normalize( cross(cu,cw) );
    return mat3( cu, cv, cw );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (-iResolution.xy + 2.0*fragCoord.xy)/ iResolution.y;
        
    float phi = (iMouse.x-0.5)/iResolution.x * PI * 2.0;
    float psi = -((iMouse.y-0.5)/iResolution.y-0.5) * PI;
    
    
    vec3 ro = 5.0*vec3(cos(phi)*cos(psi), sin(psi), sin(phi)*cos(psi));
    if(iMouse.z < 0.5)
        ro = CAM_POS;
    vec3 ta = vec3(0., .5, .0);
    mat3 m = setCamera(ro, ta, 0.0);
	
    float zoom = 2.;
    //zoom = iMouse.y/iResolution.y * 5.;
    vec3 rd = m*normalize(vec3(p, zoom));
    
    // scene rendering
    vec3 col = render( ro, rd);
    
    // gamma correction
    col = sqrt(col);

    fragColor = vec4(col, 1.0);
    
    //fragColor = texture(iChannel0, fragCoord.xy/iResolution.xy);
}
