shader_type canvas_item;

// Camera parameters
uniform float focal = 320.0;
uniform vec2 screen_center = vec2(640.0, 360.0);
uniform float horizon_y = 468.0;
uniform vec3 camera_world_pos = vec3(0.0, 50.0, 0.0);
uniform float bank_offset = 0.0; // bank * bank_pixels

// Grid parameters
uniform float near_z = 5.0;
uniform float far_z = 2000.0;
uniform float tile_size = 20.0; // Size of each checkerboard tile in world units

// Visual parameters
uniform vec4 color_a : source_color = vec4(0.2, 0.6, 1.0, 1.0); // Light blue
uniform vec4 color_b : source_color = vec4(0.1, 0.3, 0.6, 1.0); // Dark blue

void fragment() {
    vec2 screen_pos = FRAGCOORD.xy;
    
    // Don't draw above horizon
    if (screen_pos.y <= horizon_y) {
        discard;
    }
    
    // Inverse projection to find world position on ground plane (y=0)
    float depth = camera_world_pos.y * focal / (screen_pos.y - horizon_y);
    
    // Check depth bounds
    if (depth < near_z || depth > far_z) {
        discard;
    }
    
    // Calculate world X and Z
    float world_x = (screen_pos.x - screen_center.x - bank_offset) * depth / focal + camera_world_pos.x;
    float world_z = camera_world_pos.z - depth;
    
    // Create checkerboard pattern with crisp edges
    float tile_x = floor(world_x / tile_size);
    float tile_z = floor(world_z / tile_size);
    
    // Checkerboard: alternate colors based on tile coordinates
    float checker = mod(tile_x + tile_z, 2.0);
    
    // Crisp selection between colors (no smoothing)
    COLOR = (checker < 0.5) ? color_a : color_b;
}
