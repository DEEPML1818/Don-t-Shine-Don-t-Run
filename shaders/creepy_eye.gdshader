shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 sclera_color : source_color = vec4(0.75, 0.70, 0.65, 1.0);
uniform vec4 vein_color : source_color = vec4(0.55, 0.08, 0.06, 1.0);
uniform vec4 iris_color : source_color = vec4(1.0, 0.15, 0.02, 1.0);
uniform vec4 pupil_color : source_color = vec4(0.02, 0.0, 0.0, 1.0);

uniform float pupil_slit : hint_range(0.1, 1.0) = 0.35;
uniform float emission_boost : hint_range(0.0, 15.0) = 4.0;
uniform bool is_milky_cataract = false;

void fragment() {
    vec2 p = UV - vec2(0.5, 0.5);
    float dist = length(p);
    float angle = atan(p.y, p.x);
    
    vec3 col = sclera_color.rgb;
    
    if (is_milky_cataract) {
        // Blind, diseased, opaque milky eye
        col = mix(vec3(0.55, 0.58, 0.56), vec3(0.3, 0.35, 0.32), dist * 1.5);
        ALBEDO = col;
        ROUGHNESS = 0.35;
        SPECULAR = 0.7;
        EMISSION = vec3(0.05, 0.02, 0.01) * emission_boost * 0.2;
    } else {
        // Bloodshot veins in sclera
        float vein = sin(angle * 14.0 + dist * 20.0) * cos(dist * 35.0);
        if (dist > 0.22 && vein > 0.55) {
            col = mix(col, vein_color.rgb, 0.85);
        }
        
        // Iris ring
        float iris_radius = 0.22;
        if (dist < iris_radius) {
            float iris_detail = sin(angle * 32.0) * 0.2 + 0.8;
            col = iris_color.rgb * iris_detail;
            
            // Vertical slit pupil
            vec2 pupil_p = vec2(p.x / pupil_slit, p.y);
            if (length(pupil_p) < 0.09) {
                col = pupil_color.rgb;
            }
        }
        
        ALBEDO = col;
        ROUGHNESS = 0.05; // Glossy, wet eyeball
        SPECULAR = 0.95;
        
        // Glowing iris emission
        if (dist < iris_radius && length(vec2(p.x / pupil_slit, p.y)) >= 0.09) {
            EMISSION = iris_color.rgb * emission_boost;
        } else {
            EMISSION = vec3(0.0);
        }
    }
}
