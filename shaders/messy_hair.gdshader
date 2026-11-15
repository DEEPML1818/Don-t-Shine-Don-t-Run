shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 hair_color : source_color = vec4(0.06, 0.05, 0.045, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.18, 0.16, 0.14, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.55;

void fragment() {
    float strand = sin(UV.x * 28.0) * 0.5 + 0.5;
    vec3 col = mix(hair_color.rgb, sheen_color.rgb, strand * 0.4);
    
    // Add grime / blood tint from vertex color
    col = mix(col, vec3(0.22, 0.04, 0.03), COLOR.r * 0.7);
    
    ALBEDO = col;
    ROUGHNESS = roughness;
    SPECULAR = 0.4;
}
