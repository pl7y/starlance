shader_type canvas_item;

// Camera parameters
uniform float focal = 320.0;
uniform vec2 screen_center = vec2(640.0, 360.0);
uniform float horizon_y = 468.0;
uniform vec3 camera_world_pos = vec3(0.0, 50.0, 0.0);
uniform float bank_offset = 0.0; // bank * bank_pixels

// Grid parameters
uniform float half_width = 18.0;
uniform float near_z = 2.0;
uniform float far_z = 120.0;
uniform float lanes = 9.0;
uniform float depth_lines = 28.0;

// Visual parameters
uniform vec4 lane_color : source_color = vec4(1.0, 1.0, 1.0, 0.35);
uniform vec4 depth_color : source_color = vec4(1.0, 1.0, 1.0, 0.25);
uniform float line_width = 3.0; // in pixels

void fragment() {
    vec2 screen_pos = FRAGCOORD.xy;
    
    // Don't draw above horizon
    if (screen_pos.y <= horizon_y) {
        discard;
    }
    
    // Inverse projection to find world position on ground plane (y=0)
    float depth = camera_world_pos.y * focal / (screen_pos.y - horizon_y);
    
    // Check depth bounds early
    if (depth < near_z || depth > far_z) {
        discard;
    }
    
    // Calculate world X and Z
    float world_x = (screen_pos.x - screen_center.x - bank_offset) * depth / focal + camera_world_pos.x;
    float world_z = camera_world_pos.z - depth;
    
    // Check if we're within horizontal bounds
    if (abs(world_x) > half_width) {
        discard;
    }
    
    vec4 final_color = vec4(0.0);
    float scale = focal / depth;
    float world_pixel_size = 1.0 / scale; // How many world units per screen pixel
    
    // Draw lane lines (vertical lines at constant X)
    int num_lanes = int(lanes);
    for (int i = 0; i < 20; i++) {
        if (i >= num_lanes) break;
        
        float t = (num_lanes > 1) ? float(i) / float(num_lanes - 1) : 0.5;
        float lane_x = mix(-half_width, half_width, t);
        
        float dist_to_lane = abs(world_x - lane_x);
        float threshold = world_pixel_size * line_width;
        
        if (dist_to_lane < threshold) {
            float alpha = 1.0 - smoothstep(0.0, threshold, dist_to_lane);
            final_color = mix(final_color, lane_color, alpha * lane_color.a);
        }
    }
    
    // Draw depth lines (horizontal lines at constant Z)
    int num_depth = int(depth_lines);
    for (int j = 0; j < 40; j++) {
        if (j >= num_depth) break;
        
        float u = float(j) / float(num_depth - 1);
        float line_depth = mix(near_z, far_z, u * u); // quadratic spacing
        float line_world_z = camera_world_pos.z - line_depth;
        
        float dist_to_depth_line = abs(world_z - line_world_z);
        float threshold = world_pixel_size * line_width;
        
        if (dist_to_depth_line < threshold) {
            float alpha = 1.0 - smoothstep(0.0, threshold, dist_to_depth_line);
            final_color = mix(final_color, depth_color, alpha * depth_color.a);
        }
    }
    
    COLOR = final_color;
}
