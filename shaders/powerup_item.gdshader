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
uniform bool fire_effect = false;
uniform float fire_speed : hint_range(0.5, 3.0) = 1.5;

// Lightning properties
uniform bool lightning_effect = false;
uniform float lightning_intensity : hint_range(0.0, 1.0) = 0.7;
uniform float lightning_speed : hint_range(0.5, 5.0) = 3.0;
uniform vec4 lightning_color : source_color = vec4(1.0, 1.0, 0.8, 1.0);

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

     // Fire effect for color bomb
    if (fire_effect) {
        // Simple flickering fire effect
        float fire_noise = random(UV + time * fire_speed * 0.1);

        // Create upward flame movement - simpler approach
        float flame_y = 1.0 - UV.y; // Bottom = 1.0, top = 0.0
        float flame_flicker = sin(UV.x * 10.0 + time * fire_speed * 3.0) * 0.3 + 0.7;

        // Flame intensity stronger at bottom, weaker at top
        float flame_intensity = flame_y * flame_flicker * fire_noise;
        flame_intensity = smoothstep(0.2, 0.8, flame_intensity);

        // Fire colors: orange-red base with yellow highlights
        vec3 fire_tint = vec3(1.0, 0.4 + flame_intensity * 0.6, 0.1);

        // Apply fire effect while preserving base color
        final_color.rgb = mix(final_color.rgb, final_color.rgb * fire_tint, flame_intensity * 0.5);

        // Add brightness
        final_color.rgb += final_color.rgb * flame_intensity * 0.3;

        // Fire particles - floating embers
        vec2 particle_uv = UV * 8.0; // Create grid for particles
        vec2 particle_id = floor(particle_uv);
        vec2 particle_pos = fract(particle_uv);

        // Each particle has unique movement
        float particle_time = time * fire_speed + random(particle_id) * 6.28;
        vec2 particle_offset = vec2(
            sin(particle_time * 0.8) * 0.3,
            -fract(particle_time * 0.2) // Particles rise upward
        );

        // Particle position with movement
        vec2 final_particle_pos = particle_pos + particle_offset;
        float particle_dist = distance(final_particle_pos, vec2(0.5));

        // Create particle if it's within bounds and close to center
        if (final_particle_pos.x >= 0.0 && final_particle_pos.x <= 1.0 &&
            final_particle_pos.y >= 0.0 && final_particle_pos.y <= 1.0) {

            float particle = smoothstep(0.3, 0.1, particle_dist);

            // Particles fade as they rise
            float particle_life = 1.0 - fract(particle_time * 0.2);
            particle *= particle_life;

            // Add particle glow
            if (particle > 0.0) {
                vec3 ember_color = vec3(1.0, 0.6, 0.2) * base_color.rgb;
                final_color.rgb += ember_color * particle * 0.4;
            }
        }
    }

    // Lightning effect - electric arcs (replaces star effect)
    if (lightning_effect) {
        // Create multiple lightning paths
        float lightning = 0.0;

        // Main diagonal lightning bolt - thicker and more visible
        float bolt1 = abs(UV.y - (UV.x + sin(time * lightning_speed * 0.5 + UV.x * 8.0) * 0.1)); // Reduced from lightning_speed to lightning_speed * 0.5
        bolt1 = smoothstep(0.06, 0.0, bolt1); // Increased from 0.02 to 0.06

        // Secondary horizontal arc - thicker
        float bolt2 = abs(UV.x - (0.5 + sin(time * lightning_speed * 0.6 + UV.y * 12.0) * 0.3)); // Reduced from lightning_speed * 1.3 to lightning_speed * 0.6
        bolt2 = smoothstep(0.08, 0.0, bolt2); // Increased from 0.03 to 0.08

        // Flickering intensity - slower flicker
        float flicker = sin(time * lightning_speed * 1.0) * 0.3 + 0.7; // Reduced from lightning_speed * 2.0 to lightning_speed * 1.0
        lightning = max(bolt1, bolt2 * 0.8) * flicker; // Increased bolt2 weight from 0.6 to 0.8

        // Add electric glow - more intense
        final_color.rgb = mix(final_color.rgb, lightning_color.rgb * base_color.rgb, lightning * lightning_intensity);

        // Add brightness spikes - more visible
        final_color.rgb += vec3(lightning * 0.5); // Increased from 0.3 to 0.5
    }

    // Fish effect - wavy distortion
    if (fish_effect) {
        vec2 wave_uv = UV;
        wave_uv.x += sin(UV.y * wave_frequency + time * 3.0) * wave_strength * 0.1;
        wave_uv.y += cos(UV.x * wave_frequency + time * 2.5) * wave_strength * 0.05;

        vec4 wave_texture = texture(TEXTURE, wave_uv);
        final_color = wave_texture * base_color;

        // Add aqua-like shimmer effect while preserving base color
        float shimmer = sin(time * 3.0 + UV.x * 10.0) * 0.5 + 0.5;
        final_color.rgb = mix(final_color.rgb, final_color.rgb * vec3(0.8, 1.0, 1.2), shimmer * 0.2);
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
        //final_color.rgb = mix(shattered_color.rgb, vec3(1.0, 1.0, 0.0), alpha_fade * 0.5);
		  final_color.rgb = shattered_color.rgb;

        // The final alpha is based on the fade and overall removal progress
        final_color.a = (1.0 - removal_progress) * alpha_fade;
    }

    COLOR = final_color;
}