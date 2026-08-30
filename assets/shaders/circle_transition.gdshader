shader_type canvas_item;
render_mode unshaded;

uniform vec2 center_uv = vec2(0.5);
uniform float radius_progress : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec2 pixel_delta = (SCREEN_UV - center_uv) / SCREEN_PIXEL_SIZE;
    float distance_from_center = length(pixel_delta);
    vec2 furthest_delta_pixels = max(center_uv, vec2(1.0) - center_uv) / SCREEN_PIXEL_SIZE;
    float radius_pixels = (length(furthest_delta_pixels) + 4.0) * radius_progress - 2.0;
    float alpha = smoothstep(
        radius_pixels - 1.5,
        radius_pixels + 1.5,
        distance_from_center
    );
    COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
