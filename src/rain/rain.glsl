#iChannel0 "file://D:/_workspace/shadertoy/resource/cloud/normal.png"
#iChannel1 "file://D:/_workspace/shadertoy/resource/cloud/opacity.jpg"
#iChannel2 "file://D:/_workspace/shadertoy/resource/cloud/roughness.jpg"
#iChannel3 "file://D:/_workspace/shadertoy/resource/cloud/normal.png"

#define HASHSCALE1 .1031
#define HASHSCALE3 vec3(.1031, .1030, .0973)
#define ITERATIONS 1
#define MAX_RADIUS 1

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * HASHSCALE1);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}


vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.xx + p3.yz) * p3.zy);

}
vec3 hash33(vec3 p3)
{
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy + p3.yxx)*p3.zyx);

}

vec3 hash32(vec2 p)
{
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy+p3.yzz)*p3.zyx);
}

float map(float value, float min1, float max1, float min2, float max2) {
    return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

vec4 cubic(float v) {
    vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 s = n * n * n;
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return vec4(x, y, z, w);
}

// https://stackoverflow.com/questions/13501081/efficient-bicubic-filtering-code-in-glsl
vec4 textureBicubic(sampler2D t, vec2 texCoords, vec2 textureSize) {
    vec2 invTexSize = 1.0 / textureSize;
    texCoords = texCoords * textureSize - 0.5;

    vec2 fxy = fract(texCoords);
    texCoords -= fxy;
    vec4 xcubic = cubic(fxy.x);
    vec4 ycubic = cubic(fxy.y);

    vec4 c = texCoords.xxyy + vec2(-0.5, 1.5).xyxy;

    vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
    vec4 offset = c + vec4(xcubic.yw, ycubic.yw) / s;

    offset *= invTexSize.xxyy;

    vec4 sample0 = texture2D(t, offset.xz);
    vec4 sample1 = texture2D(t, offset.yz);
    vec4 sample2 = texture2D(t, offset.xw);
    vec4 sample3 = texture2D(t, offset.yw);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

// With original size argument
vec4 packedTexture2DLOD(sampler2D tex, vec2 uv, int level, vec2 originalPixelSize) {
    float floatLevel = float(level);
    vec2 atlasSize;
    atlasSize.x = floor(originalPixelSize.x * 1.5);
    atlasSize.y = originalPixelSize.y;

    // we stop making mip maps when one dimension == 1

    float maxLevel = min(floor(log2(originalPixelSize.x)), floor(log2(originalPixelSize.y)));
    floatLevel = min(floatLevel, maxLevel);

    // use inverse pow of 2 to simulate right bit shift operator

    vec2 currentPixelDimensions = floor(originalPixelSize / pow(2.0, floatLevel));
    vec2 pixelOffset = vec2(floatLevel > 0.0 ? originalPixelSize.x : 0.0, floatLevel > 0.0 ? currentPixelDimensions.y : 0.0);

    // "minPixel / atlasSize" samples the top left piece of the first pixel
    // "maxPixel / atlasSize" samples the bottom right piece of the last pixel
    vec2 minPixel = pixelOffset;
    vec2 maxPixel = pixelOffset + currentPixelDimensions;
    vec2 samplePoint = mix(minPixel, maxPixel, uv);
    samplePoint /= atlasSize;
    vec2 halfPixelSize = 1.0 / (2.0 * atlasSize);
    samplePoint = min(samplePoint, maxPixel / atlasSize - halfPixelSize);
    samplePoint = max(samplePoint, minPixel / atlasSize + halfPixelSize);
    return textureBicubic(tex, samplePoint, originalPixelSize);
}

vec4 packedTexture2DLOD(sampler2D tex, vec2 uv, float level, vec2 originalPixelSize) {
    float ratio = mod(level, 1.0);
    int minLevel = int(floor(level));
    int maxLevel = int(ceil(level));
    vec4 minValue = packedTexture2DLOD(tex, uv, minLevel, originalPixelSize);
    vec4 maxValue = packedTexture2DLOD(tex, uv, maxLevel, originalPixelSize);
    return mix(minValue, maxValue, ratio);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uTexScale = vec2(1.38,4.07);
    float uRainCount = 7000.0;
    float uDistortionAmount = .4065;
    float uBlurStrength = .3;
    vec2 uMipmapTextureSize = vec2(0.0, 0.0);
    vec2 reflectionUv = fragCoord.xy / iResolution.xy - 0.5;

    vec2 position = fragCoord.xy;
    vec2 uv = fragCoord.xy * uTexScale;

    float floorOpacity = texture2D(iChannel1, uv).r;
    vec3 floorNormal = texture2D(iChannel0, uv).rgb * 2. - 1.;
    floorNormal = normalize(floorNormal);
    float roughness = texture2D(iChannel2, uv).r;

    vec2 rippleUv = 75. * uv * uTexScale;

    vec2 p0 = floor(rippleUv);

    float rainStrength = map(uRainCount, 0., 10000., 3., 0.5);
    if(rainStrength == 3.) {
        rainStrength = 50.;
    }

    vec2 circles = vec2(0.);
    for(int j = -MAX_RADIUS; j <= MAX_RADIUS; ++j) {
        for(int i = -MAX_RADIUS; i <= MAX_RADIUS; ++i) {
            vec2 pi = p0 + vec2(i, j);
            vec2 hsh = pi;
            vec2 p = pi + hash22(hsh);

            float t = fract(0.8 * iTime + hash12(hsh));
            vec2 v = p - rippleUv;
            float d = length(v) - (float(MAX_RADIUS) + 1.) * t + (rainStrength * 0.1 * t);

            float h = 1e-3;
            float d1 = d - h;
            float d2 = d + h;
            float p1 = sin(31. * d1) * smoothstep(-0.6, -0.3, d1) * smoothstep(0., -0.3, d1);
            float p2 = sin(31. * d2) * smoothstep(-0.6, -0.3, d2) * smoothstep(0., -0.3, d2);
            circles += 0.5 * normalize(v) * ((p2 - p1) / (2. * h) * pow(1. - t, rainStrength));
        }
    }

    circles /= float((MAX_RADIUS * 2 + 1) * (MAX_RADIUS * 2 + 1));

    float intensity = 0.05 * floorOpacity;
    vec3 n = vec3(circles, sqrt(1. - dot(circles, circles)));

    vec3 color = packedTexture2DLOD(iChannel1, reflectionUv + floorNormal.xy * uDistortionAmount - intensity * n.xy, roughness * uBlurStrength, uMipmapTextureSize).rgb;

    fragColor = vec4(n, 1.0);

    // vec3 a = vec3(0.0), b = a;
    // for (int t = 0; t < ITERATIONS; t++)
    // {
    //     float v = float(t+1)*.132;
    //     vec3 pos = vec3(position, iTime*.3) + iTime * 500. + 50.0;
    //     a += hash33(pos);
    // }
    // fragColor = vec4(a, 1.0);
}

// float rain(vec3 p) {

//   p.y -= time*4.0;
//   p.xy *= 60.0;
  
//   p.y += rnd(floor(p.x))*80.0;
  
//   return clamp(1.0-length(vec2(cos(p.x * PI), sin(p.y*0.1) - 1.7)), 0.0, 1.0);
// }

// #define RAIN_STEPS 50

// void mainImage( out vec4 fragColor, in vec2 fragCoord )
// {
//     vec3 col = vec3(0.0);
//     vec3 r = normalize(vec3(-uv,0.7));

//     float at = 0.0;
//     vec3 raining = vec3(0.0);
//     int steps = RAIN_STEPS;
//     float stepsize = 30.0 / float(steps);
//     vec3 raystep = r * stepsize / r.z;
//     //vec3 raypos = s + raystep;
//     for(int i=0; i<steps; ++i) {
//         vec3 raypos = s + raystep * (float(i)+1.0);
//         float tot = length(raypos-s);

//         if(tot>dd) break;
//         float fog2 = 1.0-pow(clamp(tot/40.0,0.0,1.0),0.5);

        
//         vec3 ldir = getlightdir(raypos);
//         float l2dist = lighting(raypos);
//         float curlight = 1.0/pow(l2dist,2.0);

//         vec3 rainpos = raypos;
//         rainpos.xy *= rot(sin(float(i)*0.2)*0.01 + sin(time)*0.009);
//         rainpos.xy += rnd(float(i))*vec2(7.52,13.84);
//         raining += rain(rainpos) * fog2 * (lightning*0.5 + pow(curlight,2.0));

//         at += 0.04*curlight * fog2;
//     }
//     col += at;
//     col += raining;


//     col = pow(col, vec3(0.4545));

//     fragColor = vec4(col, 1);
// }