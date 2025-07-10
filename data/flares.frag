#ifdef GL_ES
precision mediump float;
#endif

varying vec2 v_texcoord;
uniform vec2 resolution;

// --- Константы для массивов (должны совпадать с Processing) ---
const int MAX_FLARES = 20;
const int MAX_LOOPS = 10;

// --- Uniforms для вспышек ---
uniform int flares_count;
uniform vec4 flares_data[MAX_FLARES];  // x, y, dir.x, dir.y
uniform vec2 flares_props[MAX_FLARES]; // age, lifetime

// --- Uniforms для петель ---
uniform int loops_count;
uniform vec4 loops_points[MAX_LOOPS]; // p1.x, p1.y, p2.x, p2.y
uniform vec2 loops_props[MAX_LOOPS];  // age, lifetime

// --- Параметры внешнего вида ---
const float FLARE_THICKNESS = 3.0;
const float LOOP_THICKNESS = 4.0;
const vec3 FLARE_COLOR = vec3(1.0, 0.9, 0.6);
const vec3 LOOP_COLOR = vec3(1.0, 0.7, 0.3);
const float FLARE_SPEED = 350.0;

// ================== SDF ФУНКЦИИ ==================

// SDF для отрезка (a, b)
float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// SDF для параболы y = k*x^2
float sdParabola(vec2 pos, float k) {
    pos.x = abs(pos.x);
    float ik = 1.0 / k;
    float p = ik * (pos.y - 0.25 * ik) / 3.0;
    float q = 0.25 * ik * ik * (1.0 - pos.y * ik);
    float h = q - p * p;
    float r = sqrt(abs(h));
    float x = (h > 0.0) ? p + r : sqrt(pos.x * pos.x + (pos.y - 0.5 * ik) * (pos.y - 0.5 * ik));
    return (pos.x > x) ? length(pos - vec2(x, k * x * x)) : abs(pos.x - sqrt(pos.y / k));
}


// ================== ФУНКЦИИ РЕНДЕРИНГА ==================

// --- Рендеринг одной вспышки ---
vec3 renderFlare(vec2 uv, int i) {
    float age = flares_props[i].x;
    float lifetime = flares_props[i].y;
    
    // Прогресс жизни вспышки
    float progress = age / lifetime;
    
    // Начальная и конечная точки луча
    vec2 p1 = flares_data[i].xy;
    vec2 dir = flares_data[i].zw;
    vec2 p2 = p1 + dir * FLARE_SPEED * age;
    
    // Вычисляем расстояние до отрезка
    float d = sdSegment(uv, p1, p2);
    
    // Плавное затухание по краям линии
    float line = smoothstep(FLARE_THICKNESS, 0.0, d);
    
    // Яркость вспышки: появляется и исчезает
    float brightness = sin(progress * 3.14159); // Плавное появление и затухание
    
    return FLARE_COLOR * line * brightness;
}

// --- Рендеринг одной петли ---
vec3 renderLoop(vec2 uv, int i) {
    float age = loops_props[i].x;
    float lifetime = loops_props[i].y;
    
    vec2 p1 = loops_points[i].xy;
    vec2 p2 = loops_points[i].zw;

    // Преобразование координат, чтобы дуга была "вертикальной"
    vec2 center = (p1 + p2) * 0.5;
    vec2 dir = normalize(p2 - p1);
    float len = length(p2 - p1);
    
    mat2 rot = mat2(dir.x, dir.y, -dir.y, dir.x);
    vec2 local_uv = rot * (uv - center);

    // Рисуем только если мы в области дуги
    if (abs(local_uv.x) > len / 2.0) return vec3(0.0);

    // Высота дуги (зависит от длины)
    float h = len * 0.4; 
    
    // Коэффициент параболы
    float k = 4.0 * h / (len * len);

    // Смещаем y, чтобы основание было на 0
    local_uv.y += h;

    // Вычисляем расстояние до параболы
    float d = sdParabola(local_uv, k);
    
    // Плавное затухание
    float line = smoothstep(LOOP_THICKNESS, 0.0, d);

    // Яркость петли: плавно появляется и долго висит
    float fadeIn = smoothstep(0.0, 0.2, age / lifetime);
    float fadeOut = smoothstep(1.0, 0.8, age / lifetime);
    float brightness = fadeIn * fadeOut;

    return LOOP_COLOR * line * brightness;
}


void main() {
    vec2 uv = v_texcoord * resolution;
    vec3 finalColor = vec3(0.0);

    // --- Проход по всем вспышкам ---
    for (int i = 0; i < MAX_FLARES; i++) {
        if (i >= flares_count) break;
        finalColor += renderFlare(uv, i);
    }

    // --- Проход по всем петлям ---
    for (int i = 0; i < MAX_LOOPS; i++) {
        if (i >= loops_count) break;
        finalColor += renderLoop(uv, i);
    }

    gl_FragColor = vec4(finalColor, clamp(length(finalColor), 0.0, 1.0));
}
