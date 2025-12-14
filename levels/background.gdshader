shader_type canvas_item;

uniform float world_split_y = 100.0;

uniform vec4 top_color    : source_color = vec4(0.976, 0.718, 0.518, 1.0); // #f9b784
uniform vec4 bottom_color : source_color = vec4(0.565, 0.325, 0.137, 1.0); // #905323

uniform mat4 canvas_transform;
uniform mat4 screen_transform;

void fragment() {
    // Screen position in pixels
    vec2 screen_pos = FRAGCOORD.xy;

    // Convert screen → canvas → world
    vec4 canvas_pos = inverse(screen_transform) * vec4(screen_pos, 0.0, 1.0);
    vec4 world_pos  = inverse(canvas_transform) * canvas_pos;

    if (world_pos.y < world_split_y) {
        COLOR = top_color;
    } else {
        COLOR = bottom_color;
    }
}
