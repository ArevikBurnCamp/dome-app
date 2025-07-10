#ifdef GL_ES
precision mediump float;
#endif

uniform vec2 u_resolution;
uniform float u_time;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.y * u.x;
}

void main() {
    vec2 st = gl_FragCoord.xy / u_resolution.xy;
    
    // Энергетическая решетка
    float grid = 0.0;
    grid += step(0.02, fract(st.x * 20.0));
    grid += step(0.02, fract(st.y * 20.0));
    grid = clamp(grid, 0.0, 1.0);

    // Потоки данных (вертикальные линии)
    float data_stream = 0.0;
    vec2 data_st = st;
    data_st.x += u_time * 0.2;
    float n = noise(data_st * vec2(10.0, 1.0));
    if (n > 0.8) {
        data_stream = 1.0;
    }

    // Глитчи (случайные прямоугольники)
    float glitch = 0.0;
    if (random(vec2(floor(u_time * 10.0), 0.0)) > 0.95) {
        vec2 glitch_st = st;
        glitch_st.x += random(vec2(u_time, 1.0)) * 0.2 - 0.1;
        if (glitch_st.x > 0.4 && glitch_st.x < 0.6) {
            glitch = 1.0;
        }
    }

    vec3 color = vec3(0.1, 0.2, 0.8) * grid; // Синяя решетка
    color += vec3(0.2, 0.8, 0.2) * data_stream; // Зеленые потоки
    color += vec3(1.0, 0.1, 0.1) * glitch; // Красные глитчи

    gl_FragColor = vec4(color, 1.0);
}
