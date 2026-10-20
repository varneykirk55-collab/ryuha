// Fighter sprite shader: player-coloured outline (silhouette readability),
// hit flash / charge glow, and palette tint for mirror matches.
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float outline_px = 3.0;

// In fragment(), COLOR already includes the texture, so keep the plain
// modulate colour from the vertex stage.
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 c = tex * v_modulate;
	c.rgb *= tint.rgb;
	c.rgb = mix(c.rgb, flash_color.rgb, flash_amount);
	if (outline_color.a > 0.0 && tex.a < 0.6) {
		vec2 px = TEXTURE_PIXEL_SIZE * outline_px;
		float a = 0.0;
		a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV + px * 0.7071).a);
		a = max(a, texture(TEXTURE, UV - px * 0.7071).a);
		a = max(a, texture(TEXTURE, UV + vec2(px.x, -px.y) * 0.7071).a);
		a = max(a, texture(TEXTURE, UV + vec2(-px.x, px.y) * 0.7071).a);
		if (a > 0.5) {
			vec4 o = vec4(outline_color.rgb, outline_color.a * v_modulate.a);
			c = mix(o, c, tex.a);
		}
	}
	COLOR = c;
}
