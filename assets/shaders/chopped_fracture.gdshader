shader_type canvas_item;

uniform float chop_progress : hint_range(0.0, 1.0) = 1.0;
uniform int chop_count : hint_range(1, 20) = 4;
uniform float fracture_seed = 0.0;
uniform float max_cut_slant : hint_range(0.0, 0.24) = 0.18;
uniform float piece_separation : hint_range(0.0, 0.08) = 0.045;

varying vec4 sprite_modulate;

void vertex() {
	sprite_modulate = COLOR;
}

float random_for_slice(float slice_index) {
	return fract(
		sin(slice_index * 91.73 + fracture_seed * 37.11 + 17.19)
		* 43758.5453
	);
}

float distance_to_segment(vec2 point, vec2 start, vec2 end) {
	vec2 segment = end - start;
	float position = clamp(
		dot(point - start, segment) / dot(segment, segment),
		0.0,
		1.0
	);
	return length(point - (start + segment * position));
}

void fragment() {
	const int maximum_cut_count = 20;
	const float cut_width = 0.01;
	const float branch_width = 0.004;

	float progress = clamp(chop_progress, 0.0, 1.0);
	float chop_count_float = float(chop_count);
	float piece_count = float(chop_count + 1);
	float effective_max_slant = min(
		max_cut_slant,
		0.7 / piece_count
	);
	float slice_index = 0.0;
	float nearest_boundary = 1.0;
	float distance_to_cut = 2.0;
	float cut_x = 0.2;
	float cut_slant = 0.0;
	float boundary_random = 0.0;

	for (int cut = 1; cut <= maximum_cut_count; cut++) {
		if (cut > chop_count) {
			break;
		}

		float boundary = float(cut);
		float random_angle = random_for_slice(boundary + 13.0);
		float boundary_slant = (random_angle * 2.0 - 1.0)
			* effective_max_slant;
		float boundary_x = boundary / piece_count
			+ boundary_slant * (UV.y - 0.5);
		slice_index += step(boundary_x, UV.x);

		vec2 boundary_start = vec2(
			boundary / piece_count - boundary_slant * 0.5,
			0.0
		);
		vec2 boundary_end = vec2(
			boundary / piece_count + boundary_slant * 0.5,
			1.0
		);
		float boundary_distance = distance_to_segment(
			UV,
			boundary_start,
			boundary_end
		);
		if (boundary_distance < distance_to_cut) {
			nearest_boundary = boundary;
			distance_to_cut = boundary_distance;
			cut_x = boundary / piece_count;
			cut_slant = boundary_slant;
			boundary_random = random_angle;
		}
	}

	float slice_random = random_for_slice(slice_index);
	float alternating_side = mod(slice_index, 2.0) * 2.0 - 1.0;
	float piece_cut_index = clamp(slice_index, 1.0, piece_count - 1.0);
	float piece_progress = step(
		piece_cut_index / chop_count_float,
		progress
	);
	float spread_direction = sign(slice_index - (piece_count - 1.0) * 0.5);
	vec2 piece_offset = vec2(
		spread_direction * piece_separation * 0.45,
		alternating_side
			* piece_separation
			* mix(0.75, 1.0, slice_random)
	) * piece_progress;
	vec2 source_uv = UV - piece_offset;

	float inside_source = step(0.0, source_uv.x)
		* step(source_uv.x, 1.0)
		* step(0.0, source_uv.y)
		* step(source_uv.y, 1.0);
	vec4 source = texture(TEXTURE, source_uv) * sprite_modulate;

	float cut_reveal = step(nearest_boundary / chop_count_float, progress)
		* step(0.5, nearest_boundary)
		* step(nearest_boundary, piece_count - 0.5);
	float antialias_width = max(fwidth(UV.x) * 1.5, 0.001);
	float straight_cut_mask = smoothstep(
		cut_width,
		cut_width + antialias_width,
		distance_to_cut
	);

	float branch_side = mod(nearest_boundary, 2.0) * 2.0 - 1.0;
	float upper_anchor = mix(0.24, 0.42, boundary_random);
	float lower_anchor = mix(0.58, 0.76, boundary_random);
	float upper_cut_x = cut_x + cut_slant * (upper_anchor - 0.5);
	float lower_cut_x = cut_x + cut_slant * (lower_anchor - 0.5);
	float upper_branch = distance_to_segment(
		UV,
		vec2(upper_cut_x, upper_anchor),
		vec2(upper_cut_x + branch_side * 0.065, upper_anchor - 0.055)
	);
	float lower_branch = distance_to_segment(
		UV,
		vec2(lower_cut_x, lower_anchor),
		vec2(lower_cut_x - branch_side * 0.055, lower_anchor + 0.07)
	);
	float branch_distance = min(upper_branch, lower_branch);
	float branch_mask = smoothstep(
		branch_width,
		branch_width + antialias_width,
		branch_distance
	);
	float fracture_mask = min(straight_cut_mask, branch_mask);
	float cut_mask = mix(
		1.0,
		fracture_mask,
		cut_reveal
	);
	float edge_shadow = mix(
		1.0,
		0.72,
		cut_reveal
			* (1.0 - smoothstep(
				cut_width,
				cut_width + 0.018,
				min(distance_to_cut, branch_distance)
			))
	);

	COLOR = vec4(source.rgb * edge_shadow, source.a * cut_mask * inside_source);
}
