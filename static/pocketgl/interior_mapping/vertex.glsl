varying vec2 v_uv;
varying vec3 v_position;
varying vec3 v_normal;
varying vec3 v_reflection;
varying vec4 v_lighting;

uniform float scale;

void main()
{
	v_uv = uv;
	v_uv.x = v_uv.x * 2.0;
	v_position = position * scale;
	v_normal = normal;
	
	vec3 worldPosition = (modelMatrix * vec4(position, 1.0)).xyz;
	vec3 worldNormal = (modelMatrix * vec4(normal, 1.0)).xyz;
	
	v_reflection = reflect(worldPosition - cameraPosition, worldNormal);

	float lightStrength = dot(normal, vec3(0.5, 0.33166, 0.8));
	v_lighting = clamp(lightStrength, 0.0, 1.0) * vec4(1.0, 1.0, 0.9, 1.0) + vec4(0.3, 0.3, 0.4, 1.0);

	gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}