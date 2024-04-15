#define rand(uv)    fract(1e5*sin(mat2(17.1,191.7,-31.1,241.7)*uv))

#define PI 3.14159265359

#define radius 4.0

#define loop(i,x) for(int i = 0; i < x; i++)

#define range(i,a,b) for(int i = a; i <= b; i++)

#define dif 0.75

vec2 grid = vec2(radius * 4.0);


float G(vec2 x)
{
    return exp(-dot(x,x));
}

vec3 hash32(vec2 p)
{
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy+p3.yzz)*p3.zyx);
}


float sdBox( in vec2 p, in vec2 b )
{
    vec2 d = abs(p)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}


float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}

float sdArrow( in vec2 p, in vec2 a, in vec2 b )
{
    float sdl = sdSegment(p,a,b);
    vec2 delta = normalize(b-a);
    sdl = min(sdl, sdSegment(p,b,b-delta*0.05 + 0.05*delta.yx*vec2(-1,1)));
    sdl = min(sdl, sdSegment(p,b,b-delta*0.05 - 0.05*delta.yx*vec2(-1,1)));
    return sdl;
}
