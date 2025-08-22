// MAIN POWERUP SHADER - Save this as "powerup_item.gdshader"
shader_type canvas_item;

// Base properties
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float time_scale : hint_range(0.1, 5.0) = 1.0;

// Bomb properties
uniform bool is_bomb  = false;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.3;
uniform float pulse_speed : hint_range(0.5, 5.0) = 2.0;

// Striped properties
uniform bool stripe_horizontal = false;
uniform bool stripe_vertical = false;
uniform vec4 stripe_color : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float stripe_width : hint_range(0.1, 0.5) = 0.2;
uniform float stripe_speed : hint_range(0.5, 3.0) = 1.5;

// Wrapped candy properties
uniform bool is_wrapped  = false;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Color bomb properties
uniform bool rainbow_effect = false;
uniform float rainbow_speed : hint_range(0.5, 3.0) = 1.5;

// Star properties
uniform bool star_effect = false;
uniform float sparkle_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float sparkle_frequency : hint_range(1.0, 10.0) = 4.0;

// Fish properties
uniform bool fish_effect = false;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.3;
uniform float wave_frequency : hint_range(0.5, 5.0) = 2.0;

// NEW! Removal effect
uniform float removal_progress : hint_range(0.0, 1.0) = 0.0;
uniform float shatter_speed : hint_range(0.1, 10.0) = 3.0;
uniform float shatter_size : hint_range(1.0, 50.0) = 1.0; // Changed default for larger chunks

// Utility functions
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec4 final_color = tex_color * base_color;

    float time = TIME * time_scale;
    vec2 center = vec2(0.5, 0.5);
    float dist_from_center = distance(UV, center);

    // Bomb effect - pulsing glow
    if (is_bomb) {
        float pulse = sin(time * pulse_speed) * 0.5 + 0.5;
        float glow = pulse * pulse_strength;

        // Add orange/red glow around edges
        float edge_glow = smoothstep(0.3, 0.7, dist_from_center) * glow;
        final_color.rgb = mix(final_color.rgb, vec3(1.0, 0.5, 0.0), edge_glow);

        // Add pulsing brightness
        final_color.rgb += vec3(glow * 0.3);
    }

    // Striped effects
    if (stripe_horizontal || stripe_vertical) {
        float stripe_pos;
        if (stripe_horizontal) {
            stripe_pos = UV.y + sin(time * stripe_speed) * 0.1;
        } else {
            stripe_pos = UV.x + sin(time * stripe_speed) * 0.1;
        }

        float stripe_pattern = sin(stripe_pos * 3.14159 / stripe_width) * 0.5 + 0.5;
        stripe_pattern = step(0.5, stripe_pattern);

        final_color = mix(final_color, stripe_color, stripe_pattern * 0.6);
    }

    // Wrapped candy effect - border glow
    if (is_wrapped) {
        float border_dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
        float border_glow = smoothstep(0.0, 0.2, border_dist);
        border_glow = 1.0 - border_glow;

        float pulse = sin(time * pulse_speed * 0.8) * 0.3 + 0.7;
        border_glow *= pulse * glow_strength;

        final_color.rgb = mix(glow_color.rgb, final_color.rgb, 1.0 - border_glow);
    }

    // Rainbow effect for color bomb
    if (rainbow_effect) {
        float hue = fract(time * rainbow_speed * 0.1 + UV.x + UV.y);
        vec3 rainbow = hsv2rgb(vec3(hue, 0.8, 1.0));

        float pulse = sin(time * pulse_speed) * 0.3 + 0.7;
        final_color.rgb = mix(final_color.rgb, rainbow, 0.4 * pulse);
    }

    // Star effect - sparkles
    if (star_effect) {
        vec2 sparkle_uv = UV * sparkle_frequency;
        float sparkle = random(floor(sparkle_uv) + sin(time * 2.0));
        sparkle *= random(floor(sparkle_uv * 1.3) + cos(time * 1.7));

        if (sparkle > 0.85) {
            float sparkle_brightness = smoothstep(0.85, 1.0, sparkle) * sparkle_intensity;
            final_color.rgb += vec3(1.0, 1.0, 0.8) * sparkle_brightness;
        }

        // Add golden tint
        final_color.rgb = mix(final_color.rgb, vec3(1.0, 0.9, 0.3), 0.2);
    }

    // Fish effect - wavy distortion
    if (fish_effect) {
        vec2 wave_uv = UV;
        wave_uv.x += sin(UV.y * wave_frequency + time * 3.0) * wave_strength * 0.1;
        wave_uv.y += cos(UV.x * wave_frequency + time * 2.5) * wave_strength * 0.05;

        vec4 wave_color = texture(TEXTURE, wave_uv) * base_color;
        final_color = mix(final_color, wave_color, 0.7);

        // Add cyan tint
        final_color.rgb = mix(final_color.rgb, vec3(0.3, 0.8, 1.0), 0.15);
    }

    // Shatter removal effect
    if (removal_progress > 0.0) {
        // Create a unique random vector for each "piece"
        vec2 random_dir = vec2(
            random(floor(UV * shatter_size + 1.0)),
            random(floor(UV * shatter_size - 1.0))
        ) * 2.0 - 1.0;

        // Displace the current pixel based on the random direction and removal progress
        vec2 new_uv = UV + random_dir * removal_progress * shatter_speed;

        // Set the alpha based on distance from center to fade out pieces that fly away
        float alpha_fade = 1.0 - smoothstep(0.0, 1.0, distance(UV, new_uv));

        // Sample the original texture at the new position
        vec4 shattered_color = texture(TEXTURE, new_uv) * base_color;

        // The final color is the shattered color mixed with a yellow glow
        final_color.rgb = mix(shattered_color.rgb, vec3(1.0, 1.0, 0.0), alpha_fade * 0.5);

        // The final alpha is based on the fade and overall removal progress
        final_color.a = (1.0 - removal_progress) * alpha_fade;
    }

    COLOR = final_color;
}
