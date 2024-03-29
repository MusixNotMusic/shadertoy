/*

EDIT: 	Reduced sample step count and introduced blue noise dithering as in 
		https://www.shadertoy.com/view/3dlfWs

EDIT 2:	Changed scattering and absorption to depend on wavelength for a coloured cloud. Added 
		extinction factor to light ray calculation.
        
EDIT 3: Better multiple scattering approximation based on 
        https://twitter.com/FewesW/status/1364617191652524032
        http://magnuswrenninge.com/wp-content/uploads/2010/03/Wrenninge-OzTheGreatAndVolumetric.pdf

EDIT 4: Simplified noise generation.

Volumetric cloud shader based on:

https://www.guerrilla-games.com/read/the-real-time-volumetric-cloudscapes-of-horizon-zero-dawn
https://www.guerrilla-games.com/read/nubis-realtime-volumetric-cloudscapes-in-a-nutshell
https://media.contentapi.ea.com/content/dam/eacom/frostbite/files/s2016-pbs-frostbite-sky-clouds-new.pdf
http://www.diva-portal.org/smash/get/diva2:1223894/FULLTEXT01.pdf

https://www.shadertoy.com/view/XlBSRz
https://www.shadertoy.com/view/4dSBDt

Buffer A: Perlin-Worley noise atlas
Buffer B: Camera and resolution change tracking
Buffer C: Cloud map heightfield of three hemispheres

We ray march a density field and calculate the attenuation of light that reaches the camera.
The cloud shape is defined by a cloud map in Buffer C. The base shape is carved using a 
Perlin-Worley noise which has both fluffy plumes and an interconnecting structure. The noise
is generated once in Buffer A based on the example listed at the top. The noise is stored in a 
texture atlas of tiles with halo cells that allow for interpolation. Data is stored in 
duplicate and offset using the red and green channels so that we can get the values above 
and below any 3D point using a single texture read.

The lighting theory is presented in the sources above. Light attenuation uses the Beer-Lambert
law, the phase function is a two-lobed Henyey-Greenstein function and we include the powder 
effect discussed in the original HZD presentation.

Taking fewer raymarching steps leads to better performance but also banding artefacts. We use 
blue noise to offset the initial sample position along the ray each frame. This dithering gets
rid of the banding and gives a more uniform look. As blue noise is only blue in space, not 
time, we follow the example by @demofox and add the golden ratio to the offset to get a low 
discrepancy sequence in time.

TODO:	Dynamic atlas size.

*/

//------- Uncomment for fewer ray marching steps and better performance
// #define FAST

#iChannel0 "file://./bufferA.glsl"
#iChannel1 "file://./bufferB.glsl"
#iChannel2 "file://./bufferC.glsl"
#iChannel3 "file://../../resource/vcnoise.png"

#include 'common.glsl'

#ifdef FAST
	#define STEPS_PRIMARY 16
#else
	#define STEPS_PRIMARY 32
#endif

#define STEPS_LIGHT 10

//------- Uncomment to display noise texture atlas
// #define NOISE_ATLAS

//------- Uncomment for coloured cloud
// #define COLOUR_SCATTERING

//------- Uncomment to move the sun
// #define ANIMATE_SUN

//------- Uncomment for coloured light
// #define COLOUR_LIGHT

//------- Offset the sample point by blue noise every frame to get rid of banding
#define DITHERING
const float goldenRatio = 1.61803398875;

// For size of AABB
#define CLOUD_EXTENT 100.0

const vec3 skyColour = 0.7 * vec3(0.09, 0.33, 0.81);

// Scattering and absorption coefficients
#ifdef COLOUR_SCATTERING
const vec3 sigmaS = vec3(0.5, 1.0, 1.0);
#else
const vec3 sigmaS = vec3(1);
#endif
const vec3 sigmaA = vec3(0.0);

// Extinction coefficient.
const vec3 sigmaE = max(sigmaS + sigmaA, vec3(1e-6));

const float power = 200.0;
const float densityMultiplier = 0.5;

const float shapeSize = 0.4;
const float detailSize = 0.8;

const float shapeStrength = 0.6;
const float detailStrength = 0.35;

const float cloudStart = 0.0;
const float cloudEnd = CLOUD_EXTENT;

const vec3 minCorner = vec3(-CLOUD_EXTENT, cloudStart, -CLOUD_EXTENT);
const vec3 maxCorner = vec3(CLOUD_EXTENT, cloudEnd, CLOUD_EXTENT);

// float remap(float x, float low1, float high1, float low2, float high2){
// 	return low2 + (x - low1) * (high2 - low2) / (high1 - low1);
// }

vec3 rayDirection(float fieldOfView, vec2 fragCoord) {
    vec2 xy = fragCoord - iResolution.xy / 2.0;
    float z = (0.5 * iResolution.y) / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

// https://www.geertarien.com/blog/2017/07/30/breakdown-of-the-lookAt-function-in-OpenGL/
mat3 lookAt(vec3 camera, vec3 targetDir, vec3 up){
  vec3 zaxis = normalize(targetDir);    
  vec3 xaxis = normalize(cross(zaxis, up));
  vec3 yaxis = cross(xaxis, zaxis);

  return mat3(xaxis, yaxis, -zaxis);
}

// Darken sky when looking up.
vec3 getSkyColour(vec3 rayDir){
    return mix(skyColour, 0.5 * skyColour, 0.5+0.5*rayDir.y);
}

// Return the near and far intersections of an infinite ray and a sphere. 
// Assumes sphere at origin. No intersection if result.x > result.y
vec2 sphereIntersections(vec3 start, vec3 dir, float radius){
	float a = dot(dir, dir);
	float b = 2.0 * dot(dir, start);
    float c = dot(start, start) - (radius * radius);
	float d = (b*b) - 4.0*a*c;
	if (d < 0.0){
        return vec2(1e5, -1e5);
	}
	return vec2((-b - sqrt(d))/(2.0*a), (-b + sqrt(d))/(2.0*a));
}

// https://gist.github.com/DomNomNom/46bb1ce47f68d255fd5d
// Compute the near and far intersections using the slab method.
// No intersection if tNear > tFar.
vec2 intersectAABB(vec3 rayOrigin, vec3 rayDir, vec3 boxMin, vec3 boxMax) {
    vec3 tMin = (boxMin - rayOrigin) / rayDir;
    vec3 tMax = (boxMax - rayOrigin) / rayDir;
    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    return vec2(tNear, tFar);
}

bool insideAABB(vec3 p){
    float eps = 1e-4;
	return  (p.x > minCorner.x-eps) && (p.y > minCorner.y-eps) && (p.z > minCorner.z-eps) && 
			(p.x < maxCorner.x+eps) && (p.y < maxCorner.y+eps) && (p.z < maxCorner.z+eps);
}

bool getCloudIntersection(vec3 org, vec3 dir, out float distToStart, out float totalDistance){
	vec2 intersections = intersectAABB(org, dir, minCorner, maxCorner);
	
    if(insideAABB(org)){
        intersections.x = 1e-4;
    }
    
    distToStart = intersections.x;
    totalDistance = intersections.y - intersections.x;
    return intersections.x > 0.0 && (intersections.x < intersections.y);
}


float getPerlinWorleyNoise(vec3 pos){
    // The cloud shape texture is an atlas of 6*6 tiles (36). 
    // Each tile is 32*32 with a 1 pixel wide boundary.
    // Per tile:		32 + 2 = 34.
    // Atlas width:	6 * 34 = 204.
    // The rest of the texture is black.
    // The 3D texture the atlas represents has dimensions 32 * 32 * 36.
    // The green channel is the data of the red channel shifted by one tile.
    // (tex.g is the data one level above tex.r). 
    // To get the necessary data only requires a single texture fetch.
    const float dataWidth = 204.0;
    const float tileRows = 6.0;
    const vec3 atlasDimensions = vec3(32.0, 32.0, 36.0);

    // Change from Y being height to Z being height.
    vec3 p = pos.xzy;

    // Pixel coordinates of point in the 3D data.
    vec3 coord = vec3(mod(p, atlasDimensions));
    float f = fract(coord.z);  
    float level = floor(coord.z);
    float tileY = floor(level/tileRows); 
    float tileX = level - tileY * tileRows;

    // The data coordinates are offset by the x and y tile, the two boundary cells 
    // between each tile pair and the initial boundary cell on the first row/column.
    vec2 offset = atlasDimensions.x * vec2(tileX, tileY) + 2.0 * vec2(tileX, tileY) + 1.0;
    vec2 pixel = coord.xy + offset;
    // vec2 data = texture(iChannel0, mod(pixel, dataWidth)/iChannelResolution[0].xy).xy;
    vec2 data = texture(iChannel0, mod(pixel, dataWidth)/iResolution.xy).xy;
    return mix(data.x, data.y, f);
}

// Read cloud map.
float getCloudMap(vec3 p){
    vec2 uv = 0.5 + 0.5 * (p.xz/(1.8 * CLOUD_EXTENT));
    return texture(iChannel2, uv).x;
}

float clouds(vec3 p, out float cloudHeight, bool sampleNoise){
    if(!insideAABB(p)){
    	return 0.0;
    }

    cloudHeight = clamp((p.y - cloudStart)/(cloudEnd-cloudStart), 0.0, 1.0);
    float cloud = getCloudMap(p);

    // If there are no clouds, exit early.
    if(cloud <= 0.0){
      return 0.0;
    }

    // Sample texture which determines how high clouds reach.
    float height = pow(cloud, 0.75);
    
    // Round the bottom and top of the clouds. From "Real-time rendering of volumetric clouds". 
    cloud *= clamp(remap(cloudHeight, 0.0, 0.25 * (1.0-cloud), 0.0, 1.0), 0.0, 1.0)
           * clamp(remap(cloudHeight, 0.75 * height, height, 1.0, 0.0), 0.0, 1.0);

    // Animate main shape.
    p += vec3(2.0 * iTime, 0.0, iTime);
    
    // Get main shape noise
    float shape = getPerlinWorleyNoise(shapeSize * p);

    // Carve away density from cloud based on noise.
    cloud = clamp(remap(cloud, shapeStrength * (shape), 1.0, 0.0, 1.0), 0.0, 1.0);

    // Early exit from empty space
    if(cloud <= 0.0){
      return 0.0;    
    }
    
    // Animate details.
    p += vec3(3.0 * iTime, -3.0 * iTime, iTime);
    
    // Get detail shape noise
    float detail = getPerlinWorleyNoise(detailSize * p);
    
	// Carve away detail based on the noise
	cloud = clamp(remap(cloud, detailStrength * (detail), 1.0, 0.0, 1.0), 0.0, 1.0);
    return densityMultiplier * cloud;
}

float HenyeyGreenstein(float g, float costh){
	return (1.0 / (4.0 * 3.1415))  * ((1.0 - g * g) / pow(1.0 + g*g - 2.0*g*costh, 1.5));
}

// https://twitter.com/FewesW/status/1364629939568451587/photo/1
vec3 multipleOctaves(float extinction, float mu, float stepL){

    vec3 luminance = vec3(0);
    const float octaves = 4.0;
    
    // Attenuation
    float a = 1.0;
    // Contribution
    float b = 1.0;
    // Phase attenuation   


    
    float c = 1.0;
    
    float phase;
    
    for(float i = 0.0; i < octaves; i++){
        // Two-lobed HG
        phase = mix(HenyeyGreenstein(-0.1 * c, mu), HenyeyGreenstein(0.3 * c, mu), 0.7);
        luminance += b * phase * exp(-stepL * extinction * sigmaE * a);
        // Lower is brighter
        a *= 0.2;
        // Higher is brighter
        b *= 0.5;
        c *= 0.5;
    }
    return luminance;
}

// Get the amount of light that reaches a sample point.
vec3 lightRay(vec3 org, vec3 p, float phaseFunction, float mu, vec3 sunDirection){

	float lightRayDistance = CLOUD_EXTENT*0.75;
    float distToStart = 0.0;
    
    getCloudIntersection(p, sunDirection, distToStart, lightRayDistance);
        
    float stepL = lightRayDistance/float(STEPS_LIGHT);

	float lightRayDensity = 0.0;
    
    float cloudHeight = 0.0;

	// Collect total density along light ray.
	for(int j = 0; j < STEPS_LIGHT; j++){
	
		bool sampleDetail = true;
		if(lightRayDensity > 0.3){
			sampleDetail = false;
		}
        
		lightRayDensity += clouds(p + sunDirection * float(j) * stepL, 
                                  cloudHeight, sampleDetail);
	}
    
	vec3 beersLaw = multipleOctaves(lightRayDensity, mu, stepL);
	
    // Return product of Beer's law and powder effect depending on the 
    // view direction angle with the light direction.
	return mix(beersLaw * 2.0 * (1.0 - (exp( -stepL * lightRayDensity * 2.0 * sigmaE))), 
               beersLaw, 
               0.5 + 0.5 * mu);
}

// Get the colour along the main view ray.
vec3 mainRay(vec3 org, vec3 dir, vec3 sunDirection, 
             out vec3 totalTransmittance, float mu, vec3 sunLightColour, float offset){
    
	// Variable to track transmittance along view ray. 
    // Assume clear sky and attenuate light when encountering clouds.
	totalTransmittance = vec3(1.0);

	// Default to black.
	vec3 colour = vec3(0.0);
    
    // The distance at which to start ray marching.
    float distToStart = 0.0;
    
    // The length of the intersection.
    float totalDistance = 0.0;

    // Determine if ray intersects bounding volume.
	// Set ray parameters in the cloud layer.
	bool renderClouds = getCloudIntersection(org, dir, distToStart, totalDistance);

	if(!renderClouds){
		return colour;
    }

	// Sampling step size.
    float stepS = totalDistance / float(STEPS_PRIMARY); 
    
    // Offset the starting point by blue noise.
    distToStart += stepS * offset;
    
    // Track distance to sample point.
    float dist = distToStart;

    // Initialise sampling point.
    vec3 p = org + dist * dir;
    
    // Combine backward and forward scattering to have details in all directions.
	float phaseFunction = mix(HenyeyGreenstein(-0.3, mu), HenyeyGreenstein(0.3, mu), 0.7);
    
    vec3 sunLight = sunLightColour * power;

	for(int i = 0; i < STEPS_PRIMARY; i++){

        // Normalised height for shaping and ambient lighting weighting.
        float cloudHeight;

        // Get density and cloud height at sample point
        float density = clouds(p, cloudHeight, true);

        vec3 sampleSigmaS = sigmaS * density;
        vec3 sampleSigmaE = sigmaE * density;

        // If there is a cloud at the sample point.
        if(density > 0.0 ){

            //Constant lighting factor based on the height of the sample point.
            vec3 ambient = sunLightColour * mix((0.2), (0.8), cloudHeight);

            // Amount of sunlight that reaches the sample point through the cloud 
            // is the combination of ambient light and attenuated direct light.
            vec3 luminance = 0.1 * ambient +
               	sunLight * phaseFunction * lightRay(org, p, phaseFunction, mu, sunDirection);

            // Scale light contribution by density of the cloud.
            luminance *= sampleSigmaS;

            // Beer-Lambert.
            vec3 transmittance = exp(-sampleSigmaE * stepS);

            // Better energy conserving integration
            // "From Physically based sky, atmosphere and cloud rendering in Frostbite" 5.6
            // by Sebastian Hillaire.
            colour += 
                totalTransmittance * (luminance - luminance * transmittance) / sampleSigmaE; 

            // Attenuate the amount of light that reaches the camera.
            totalTransmittance *= transmittance;  

            // If ray combined transmittance is close to 0, nothing beyond this sample 
            // point is visible, so break early.
            if(length(totalTransmittance) <= 0.001){
                totalTransmittance = vec3(0.0);
                break;
            }
        }

        dist += stepS;

		// Step along ray.
		p = org + dir * dist;
	}

	return colour;
}

float getGlow(float dist, float radius, float intensity){
    dist = max(dist, 1e-6);
	return pow(radius/dist, intensity);	
}

// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
vec3 ACESFilm(vec3 x){
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    
    // Get the default direction of the ray (along the negative Z direction)
    vec3 rayDir = rayDirection(55.0, fragCoord);
   
    //----------------- Define a camera -----------------
    
    vec3 cameraPos = texelFetch(iChannel1, ivec2(0.5, 1.5), 0).xyz;
	
    vec3 targetDir = -cameraPos + vec3(-10.0, cloudStart + 0.5 * (cloudEnd-cloudStart), -5.0);
    
    vec3 up = vec3(0.0, 1.0, 0.0);
    
    // Get the view matrix from the camera orientation
    mat3 viewMatrix = lookAt(cameraPos, targetDir, up);
    
    // Transform the ray to point in the correct direction
    rayDir = normalize(viewMatrix * rayDir);
    
    //---------------------------------------------------

    #ifdef COLOUR_LIGHT
		vec3 sunLightColour = 0.5 + 0.5 * cos(iTime+vec3(0,2,4));
	#else
		vec3 sunLightColour = vec3(1.0);
	#endif
    
    // azimuth
	float sunLocation = 1.0;
	// 0: horizon, 1: zenith
	float sunHeight = 0.6;
    
	#ifdef ANIMATE_SUN
    	sunLocation = iTime * 0.3;
	#endif
    
    vec3 sunDirection = normalize(vec3(cos(sunLocation), sunHeight, sin(sunLocation)));
    
    vec3 background = getSkyColour(rayDir);

    float mu = 0.5+0.5*dot(rayDir, sunDirection);
    background += sunLightColour * getGlow(1.0-mu, 0.00015, 0.9);
   
	vec3 totalTransmittance = vec3(1.0);
    
    float offset = 0.0;
    
    #ifdef DITHERING
    // Sometimes the blue noise texture is not immediately loaded into iChannel3
    // leading to jitters.
    // if(iChannelResolution[3].xy == vec2(1024)){
    if(vec2(1024).xy == vec2(1024)){
        // From https://blog.demofox.org/2020/05/10/ray-marching-fog-with-blue-noise/
        // Get blue noise for the fragment.
        float blueNoise = texture(iChannel3, fragCoord / 1024.0).r;

    	// Blue noise texture is blue in space but animating it leads to white noise in time.
        // Adding golden ratio to a number yields a low discrepancy sequence (apparently),
    	// making the offset of each pixel more blue in time (use fract() for modulo 1).
        // https://blog.demofox.org/2017/10/31/animating-noise-for-integration-over-time/
        offset = fract(blueNoise + float(iFrame%32) * goldenRatio);
    }
    #endif

    float exposure = 0.5;
    vec3 colour = exposure * mainRay(cameraPos, rayDir, sunDirection, 
                                     totalTransmittance, dot(rayDir, sunDirection), sunLightColour, offset); 

    colour += background * totalTransmittance;
   
    // Tonemapping
    colour = ACESFilm(colour);

    // Gamma correction 1.0/2.2 = 0.4545...
    colour = pow(colour, vec3(0.4545));
    
    #ifdef NOISE_ATLAS
    colour = texture(iChannel0, 0.3 * fragCoord.xy/iResolution.xy).rgb;
    #endif
    
    // Output to screen
    fragColor = vec4(colour, 1.0);
}