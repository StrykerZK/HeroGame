shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

// Uniforms let us control the effect from a script or AnimationPlayer
uniform vec4 aura_color: source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform sampler2D noise_texture_1;
uniform sampler2D noise_texture_2;
uniform float fresnel_power = 2.0;
uniform float flicker_speed = 10.0;
uniform float scroll_speed = 0.5;

// This varying will correctly pass the world position to the fragment shader.
varying vec3 world_pos_varying;


void vertex() {
    // This pushes the vertices out along their normals, creating a "breathing" effect
    VERTEX += NORMAL * 0.05 * (1.0 - fresnel_power / 5.0);

    // =========================================================================
    // THE FIX: Use MODEL_MATRIX (for Godot 4) instead of the old WORLD_MATRIX.
    // This correctly transforms the vertex from local space to world space.
    // =========================================================================
    world_pos_varying = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // Fresnel effect: Makes the edges of the character glow more brightly
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);

    // Receive the correctly calculated world position from the vertex shader
    vec3 world_pos = world_pos_varying;
    
    // Use world coordinates for UVs so the noise texture scrolls upwards in world space.
    vec2 uv1 = world_pos.xy * 0.5 + vec2(0.0, TIME * scroll_speed);
    vec2 uv2 = world_pos.xy * 0.8 + vec2(TIME * scroll_speed * 0.5, 0.0);
    float noise1 = texture(noise_texture_1, uv1).r;
    float noise2 = texture(noise_texture_2, uv2).r;

    // Combine the noise patterns
    float combined_noise = noise1 * noise2;

    // Add a simple, fast flicker to the whole effect
    float flicker = texture(noise_texture_1, vec2(TIME * flicker_speed, 0.0)).r;

    // The final alpha is a combination of the soft fresnel edge and the hard,
    // flickering noise pattern inside.
    ALPHA = fresnel * combined_noise * flicker;
    ALPHA = clamp(ALPHA * 2.0, 0.0, 1.0); // Boost and clamp the alpha

    // The final color is our aura color, with emission driven by the alpha
    ALBEDO = aura_color.rgb;
    EMISSION = aura_color.rgb * ALPHA;
}