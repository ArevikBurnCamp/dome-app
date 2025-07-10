#ifdef GL_ES
precision mediump float;
#endif

uniform vec2 u_resolution;
uniform float u_time;
uniform sampler2D u_baseTexture; // Текстура плазмы/основного эффекта
uniform sampler2D u_glitchTexture; // Текстура глитча
uniform float u_scanline_pos; // Позиция сканирующей линии (0.0 - 1.0)
uniform float u_scanline_width; // Ширина сканирующей линии

void main() {
    vec2 st = gl_FragCoord.xy / u_resolution.xy;
    
    // Смешивание текстур на основе позиции сканирующей линии (вертикальной)
    float mix_factor = smoothstep(u_scanline_pos - u_scanline_width, u_scanline_pos + u_scanline_width, st.x);
    
    vec3 base_color = texture2D(u_baseTexture, st).rgb;
    vec3 glitch_color = texture2D(u_glitchTexture, st).rgb;
    
    vec3 mixed_color = mix(base_color, glitch_color, mix_factor);
    
    // Добавляем горизонтальные скан-линии
    float scanlines = sin(st.y * u_resolution.y * 0.5) * 0.1;
    mixed_color -= scanlines;
    
    // Добавляем саму сканирующую линию (вертикальную)
    float line = smoothstep(u_scanline_pos - 0.005, u_scanline_pos, st.x) - smoothstep(u_scanline_pos, u_scanline_pos + 0.005, st.x);
    mixed_color += vec3(0.5, 1.0, 1.0) * line * 2.0; // Яркая голубая линия

    gl_FragColor = vec4(mixed_color, 1.0);
}
