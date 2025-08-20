shader_type canvas_item;

uniform vec4 base_color : source_color;
uniform float pulse_speed = 2.0;
uniform float pulse_strength = 0.1;

void fragment() {
    // Read the color from the sprite's texture.
    vec4 texture_color = texture(TEXTURE, UV);

    // Calculate the pulse value.
    float pulse = sin(TIME * pulse_speed);

    // Apply the pulse to the base color.
    vec3 brightened_color = base_color.rgb + vec3(pulse) * pulse_strength;

    // Combine the brightened color with the texture color.
    // The texture_color.a ensures transparency is preserved.
    COLOR = vec4(brightened_color, base_color.a) * texture_color;
}