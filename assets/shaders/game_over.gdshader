shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 focus_uv = vec2(0.5);
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 scene_color = texture(screen_texture, SCREEN_UV);
    float grayscale = dot(scene_color.rgb, vec3(0.299, 0.587, 0.114));
    float beam_progress = clamp(SCREEN_UV.y / max(focus_uv.y, 0.001), 0.0, 1.0);
    float beam_half_width = mix(0.035, 0.19, beam_progress);
    float beam_distance = abs(SCREEN_UV.x - focus_uv.x);
    float beam = 1.0 - smoothstep(beam_half_width * 0.45, beam_half_width, beam_distance);
    beam *= 1.0 - smoothstep(focus_uv.y + 0.12, focus_uv.y + 0.24, SCREEN_UV.y);

    vec3 monochrome = vec3(grayscale);
    vec3 game_over_color = monochrome * mix(0.16, 1.0, beam * 0.78);
    COLOR = vec4(mix(scene_color.rgb, game_over_color, progress), 1.0);
}