shader_type canvas_item;

// Godot 4 requires explicit screen texture uniform
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.15;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float aberration : hint_range(0.0, 0.01) = 0.002;
uniform float noise_strength : hint_range(0.0, 0.3) = 0.05;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 off = vec2(aberration, 0.0);
    vec3 base = texture(SCREEN_TEXTURE, uv).rgb;
    vec3 col;
    col.r = texture(SCREEN_TEXTURE, uv + off).r;
    col.g = base.g;
    col.b = texture(SCREEN_TEXTURE, uv - off).b;

    vec2 viewport_size = 1.0 / SCREEN_PIXEL_SIZE;
    float scan = 0.5 + 0.5 * sin(uv.y * viewport_size.y * 3.1415926);
    col *= 1.0 - scanline_strength * scan;

    vec2 d = (uv - 0.5) * 1.3;
    float vig = 1.0 - vignette_strength * smoothstep(0.35, 0.75, dot(d, d));
    col *= vig;

    float n = fract(sin(dot(uv * TIME, vec2(12.9898,78.233))) * 43758.5453);
    col += (n - 0.5) * noise_strength;

    COLOR = vec4(col, 1.0);
}
