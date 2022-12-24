shader_type canvas_item;

uniform sampler2D transition_texture;
uniform float transition_amount;

void fragment() {
	vec4 col = texture(TEXTURE,UV);
	vec4 t = texture(transition_texture,UV);
	float threshold = (t.r+t.g+t.b) / 3.0;
	if (threshold <= transition_amount) {
		discard;
	}
}
