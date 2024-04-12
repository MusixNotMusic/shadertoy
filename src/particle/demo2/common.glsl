#define rand(uv)    fract(1e5*sin(mat2(17.1,191.7,-31.1,241.7)*uv))

#define PI 3.14159265359

#define radius 4.0


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