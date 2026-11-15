shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

// --- Horror Rotting Flesh & Messy Human Skin Shader ---
// Features: Mottled corpse pallor, vein networks, dried & fresh gore streaks,
// subcutaneous reddish rim scatter (translucent thin skin), wetness on wounds/teeth,
// and pulsating emission for eyes/throat.

uniform vec4 skin_color : source_color = vec4(0.38, 0.40, 0.36, 1.0);
uniform vec4 bruise_color : source_color = vec4(0.22, 0.13, 0.18, 1.0);
uniform vec4 gore_color : source_color = vec4(0.36, 0.05, 0.04, 1.0);
uniform vec4 rim_color : source_color = vec4(0.65, 0.12, 0.08, 1.0);

uniform float roughness_skin : hint_range(0.0, 1.0) = 0.82;
uniform float wetness_intensity : hint_range(0.0, 1.0) = 0.75;
uniform float rim_power : hint_range(0.5, 8.0) = 3.2;

uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 10.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 0.0;

// High-speed pseudo-random and noise functions
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.05;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 uv = UV * 6.0;
    
    // Multi-octave skin noise: mottling, veins, and necrotic patches
    float n1 = fbm(uv);
    float n2 = fbm(uv * 2.5 + vec2(4.2, 1.7));
    float veins = smoothstep(0.48, 0.52, abs(n2 - 0.5));
    
    // Vertex color modulates gore/tissue (R = blood/gore, G = bone/teeth, B = wetness)
    vec4 vcol = COLOR;
    
    // Blend skin base with bruises and necrotic decay
    vec3 col = mix(skin_color.rgb, bruise_color.rgb, smoothstep(0.35, 0.7, n1));
    col = mix(col, bruise_color.rgb * 0.6, (1.0 - veins) * 0.4);
    
    // Apply gore / blood staining from vertex colors
    float gore_mask = clamp(vcol.r * 1.4 + (1.0 - n1) * vcol.r * 0.5, 0.0, 1.0);
    col = mix(col, gore_color.rgb, gore_mask);
    
    // Bone / teeth whitening if vcol.g is set
    vec3 bone_col = vec3(0.82, 0.78, 0.68) * mix(0.7, 1.0, n1);
    col = mix(col, bone_col, vcol.g);
    
    // Subsurface scattering rim approximation (creepy translucent thin skin)
    float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
    col += rim_color.rgb * fresnel * 0.45;
    
    ALBEDO = col;
    
    // Roughness: high for dead dry skin, very low (wet/glistening) for gore and teeth
    float is_wet = clamp(vcol.b + vcol.r * 0.8 + vcol.g * 0.3, 0.0, 1.0);
    ROUGHNESS = mix(roughness_skin, 0.12, is_wet * wetness_intensity);
    SPECULAR = mix(0.2, 0.85, is_wet);
    
    // Pulsating emission for eyes and mouth
    float pulse = 1.0;
    if (pulse_speed > 0.0) {
        pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
    }
    EMISSION = emission_color.rgb * emission_energy * pulse;
}
