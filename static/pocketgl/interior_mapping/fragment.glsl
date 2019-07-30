precision highp float;

varying vec2 v_uv;
varying vec3 v_position;
varying vec3 v_normal;
varying vec3 v_reflection;
varying vec4 v_lighting;

uniform float wallFrequencyX;
uniform float wallFrequencyZ;
uniform float ceilingFrequency;
uniform float scale;

uniform bool showOutside;
uniform bool showInterior;

uniform sampler2D diffuseTexture;
uniform sampler2D brickTexture;

uniform sampler2D floorCeilingTexture;
uniform sampler2D wallAtlasTexture;

uniform samplerCube tCube;

// https://www.shadertoy.com/view/ltB3zD
const float PHI = 1.61803398874989484820459 * 00000.1; // Golden Ratio   
const float PI  = 3.14159265358979323846264 * 00000.1; // PI
const float SQ2 = 1.41421356237309504880169 * 10000.0; // Square Root of Two

float gold_noise(in vec2 coordinate, in float seed)
{
    return fract(tan(distance(coordinate*(seed+PHI), vec2(PHI, PI)))*SQ2);
}

// http://www.proun-game.com/Oogst3D/CODING/InteriorMapping/InteriorMapping.pdf
vec4 calculate_interior(in vec3 position, in vec3 wallFrequencies, in vec3 camera)
{
	vec3 direction = position - camera;

	vec3 corner = floor(position * wallFrequencies);
	vec3 walls = (corner + step(vec3(0.0), direction)) / wallFrequencies;

	corner /= wallFrequencies;

	vec3 rayFractions = (walls - camera) / direction;

	float xVSz = step(rayFractions.x, rayFractions.z);
	float rayFraction_xVSz = mix(rayFractions.z, rayFractions.x, xVSz);

	// Ceiling or floor case
	if(rayFractions.y < rayFraction_xVSz)
	{
		vec2 intersection = (camera + rayFractions.y * direction).xz;

		intersection = (intersection - corner.xz) * wallFrequencies.xz;
		intersection.x += step(0.0, direction.y);
		intersection.x *= 0.5;

		return texture2D(floorCeilingTexture, intersection);
	}
	else
	{
		vec2 intersection;
		float noise;

		if(rayFractions.z < rayFractions.x)
		{
			intersection = (camera + rayFractions.z * direction).xy;
			intersection = (intersection - corner.xy) * wallFrequencies.xy;

			noise = floor(gold_noise(corner.xy, corner.z) * 4.0) / 4.0;
		}
		else
		{
			intersection = (camera + rayFractions.x * direction).zy;
			intersection = (intersection - corner.zy) * wallFrequencies.zy;

			noise = floor(gold_noise(corner.zy, corner.x) * 4.0) / 4.0;
		}

		vec2 atlasIndex;

		atlasIndex.x = floor(noise * 2.0) / 2.0;
		atlasIndex.y = (noise - atlasIndex.x) * 2.0;

		return texture2D(wallAtlasTexture, atlasIndex + intersection / 2.0);
	}
}

vec4 mix_interior_and_outside(vec4 interior)
{
	if(showOutside == false)
		return interior;

	vec4 brickColor = texture2D(brickTexture, v_uv * 15.0);
	vec4 diffuseColor = texture2D(diffuseTexture, v_uv);
	vec4 cubeColor = textureCube(tCube, v_reflection);

	return mix(brickColor * v_lighting, cubeColor + interior * diffuseColor, diffuseColor.a);
}

void main()
{
	vec3 camera = cameraPosition * scale;

	vec4 interior = vec4(1, 1, 1, 1);
	
	if(showInterior == true)
		interior = calculate_interior(v_position, vec3(wallFrequencyX, ceilingFrequency, wallFrequencyZ), camera);

	gl_FragColor = mix_interior_and_outside(interior);
}
