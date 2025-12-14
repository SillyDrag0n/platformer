shader_type canvas_item;

uniform float world_split_y = 100.0;

uniform vec4 top_color    : source_color = vec4(0.976, 0.718, 0.518, 1.0); // #f9b784
uniform vec4 bottom_color : source_color = vec4(0.565, 0.325, 0.137, 1.0); // #905323

void fragment() {
    // TRUE world position for Node2D
    float world_y = WORLD_POSITION.y;

    if (world_y < world_split_y) {
        COLOR = top_color;
    } else {
        COLOR = bottom_color;
    }
}
