shader_type canvas_item;

uniform float horizon_ratio = 0.35;     // 0..1 (screen height)
uniform float focal_px = 320.0;         // projection focal length in pixels

uniform float cam_z = 0.0;              // scroll forward (world units)
uniform float cam_x = 0.0;              // sideways shift (world units)
uniform float curve_strength = 0.0;     // sideways bend strength
uniform float curve_freq = 0.12;        // curve frequency

uniform float near_z = 6.0;
uniform float far_z = 220.0;

uniform float grid_spacing_x = 4.0;
uniform float grid_spacing_z = 6.0;
uniform float line_thickness = 1.25;

uniform vec4 sky_color = vec4(0.06, 0.08, 0.12, 1.0);
uniform vec4 ground_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform vec4 line_color = vec4(0.35, 0.85, 1.0, 1.0);

uniform float fog_strength = 1.0;
uniform float fog_power = 1.6;

void fragment() {
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 pix = SCREEN_UV * screen_size;

    float horizon_y = screen_size.y * horizon_ratio;

    // Mask for "ground area" (below horizon)
    float is_ground = step(horizon_y + 1.0, pix.y);

    // --- SKY COLOR (with subtle gradient) ---
    float sky_t = clamp(pix.y / max(horizon_y, 1.0), 0.0, 1.0);
    vec3 sky = mix(sky_color.rgb * 1.15, sky_color.rgb, sky_t);

    // Default to sky
    vec3 col = sky;

    // --- GROUND COMPUTATION (only meaningful when is_ground == 1) ---
    float dy = max(pix.y - horizon_y, 1.0);      // avoid div-by-zero
    float z = near_z + (focal_px / dy);

    // Clamp z for stability (still fade to fog at far)
    float z_clamped = min(z, far_z);

    // Invert projection: screen x -> world x at distance z
    float dx = pix.x - (screen_size.x * 0.5);
    float x = (dx * z_clamped) / focal_px;

    // Camera shift + curve
    float curve = sin((cam_z + z_clamped) * curve_freq) * curve_strength;
    x += cam_x + curve;

    float wz = cam_z + z_clamped;

    // Grid lines
    float fx = abs(fract(x / grid_spacing_x) - 0.5);
    float fz = abs(fract(wz / grid_spacing_z) - 0.5);

    float ax = fwidth(x / grid_spacing_x);
    float az = fwidth(wz / grid_spacing_z);

    float lx = smoothstep(0.5, 0.5 - (line_thickness * 0.01 + ax), fx);
    float lz = smoothstep(0.5, 0.5 - (line_thickness * 0.01 + az), fz);
    float grid = max(lx, lz);

    // Fog by distance
    float fog_t = clamp((z_clamped - near_z) / max(far_z - near_z, 0.001), 0.0, 1.0);
    float fog = pow(fog_t, fog_power) * fog_strength;

    // Motion bands
    float band = step(0.5, fract((wz) * 0.06));
    vec3 ground = mix(ground_color.rgb * 1.15, ground_color.rgb, band);

    // Mix lines into ground
    vec3 ground_with_lines = mix(ground, line_color.rgb, grid);

    // Fog ground toward sky
    vec3 ground_final = mix(ground_with_lines, sky_color.rgb, fog);

    // If above horizon -> sky, else -> ground
    col = mix(col, ground_final, is_ground);

    COLOR = vec4(col, 1.0);
}
