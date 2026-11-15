shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 cloth_color : source_color = vec4(0.28, 0.26, 0.23, 1.0);
uniform vec4 stain_color : source_color = vec4(0.12, 0.05, 0.04, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.92;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 p = UV * 12.0;
    float n = hash(floor(p));
    
    // Weave and grime variation
    vec3 col = mix(cloth_color.rgb, stain_color.rgb, n * 0.45 + COLOR.r * 0.65);
    
    ALBEDO = col;
    ROUGHNESS = roughness;
    SPECULAR = 0.15;
}
