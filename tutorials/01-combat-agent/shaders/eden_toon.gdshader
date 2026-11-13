shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;
uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec3 shadow_tint : source_color = vec3(0.52, 0.49, 0.66);
uniform float fill_strength = 0.24;
uniform float rim_strength = 0.065;
void fragment() {
    ALBEDO = texture(base_texture, UV).rgb * base_color.rgb;
    ROUGHNESS = 0.85;
    float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 4.0);
    EMISSION = ALBEDO * shadow_tint * fill_strength + ALBEDO * vec3(0.72, 0.79, 1.0) * rim * rim_strength;
}
void light() {
    float ndl = dot(NORMAL, LIGHT);
    float middle = smoothstep(-0.10, 0.08, ndl);
    float bright = smoothstep(0.48, 0.64, ndl);
    vec3 shade = mix(shadow_tint * 0.24, vec3(0.66, 0.65, 0.71), middle);
    shade = mix(shade, vec3(0.94, 0.88, 0.80), bright);
    DIFFUSE_LIGHT += shade * LIGHT_COLOR * ATTENUATION / 3.14159265;
}
