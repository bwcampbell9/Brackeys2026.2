shader_type canvas_item;

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 charred_color = mix(vec3(0.04, 0.025, 0.015), vec3(0.3, 0.13, 0.035), luminance);
    COLOR = vec4(charred_color, source.a) * COLOR;
}