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
uniform float tile_size = 20.0; // Size of each tile/stripe in world units
uniform int pattern = 0; // 0=checkers, 1=hatched, 2=hstripe

// Visual parameters
uniform vec4 color_a : source_color = vec4(0.2, 0.6, 1.0, 1.0); // Primary color
uniform vec4 color_b : source_color = vec4(0.1, 0.3, 0.6, 1.0); // Secondary color
uniform vec4 base_color : source_color = vec4(0.05, 0.2, 0.4, 1.0); // Base ground color (for hatched)
uniform float band_width = 0.4; // Width of bands as fraction of tile_size (for hatched)

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
    
    vec4 final_color;
    
    if (pattern == 0) {
        // CHECKERBOARD pattern
        float tile_x = floor(world_x / tile_size);
        float tile_z = floor(world_z / tile_size);
        float checker = mod(tile_x + tile_z, 2.0);
        final_color = (checker < 0.5) ? color_a : color_b;
        
    } else if (pattern == 1) {
        // HATCHED pattern (like Space Harrier)
        float tile_x = mod(world_x, tile_size);
        float tile_z = mod(world_z, tile_size);
        
        // Normalize to 0-1 within tile
        float norm_x = abs(tile_x) / tile_size;
        float norm_z = abs(tile_z) / tile_size;
        
        // Check if we're in a horizontal or vertical band
        bool in_h_band = norm_z < band_width;
        bool in_v_band = norm_x < band_width;
        
        if (in_h_band && in_v_band) {
            // Intersection - use primary color
            final_color = color_a;
        } else if (in_h_band) {
            // Horizontal band - use primary color
            final_color = color_a;
        } else if (in_v_band) {
            // Vertical band - use secondary color
            final_color = color_b;
        } else {
            // Base ground
            final_color = base_color;
        }
        
    } else if (pattern == 2) {
        // HORIZONTAL STRIPES
        float tile_z = floor(world_z / tile_size);
        float stripe = mod(tile_z, 2.0);
        final_color = (stripe < 0.5) ? color_a : color_b;
        
    } else {
        // Fallback to checkerboard
        float tile_x = floor(world_x / tile_size);
        float tile_z = floor(world_z / tile_size);
        float checker = mod(tile_x + tile_z, 2.0);
        final_color = (checker < 0.5) ? color_a : color_b;
    }
    
    COLOR = final_color;
}
