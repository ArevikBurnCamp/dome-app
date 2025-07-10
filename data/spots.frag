#ifdef GL_ES
precision mediump float;
#endif

uniform vec2 resolution;
uniform float time;

// Данные о пятнах
uniform int spots_count;
const int MAX_SPOTS = 50; // Должно совпадать с Processing
uniform vec2 spots_positions[MAX_SPOTS];
uniform float spots_sizes[MAX_SPOTS];
uniform float spots_ages[MAX_SPOTS];
uniform float spots_lifetimes[MAX_SPOTS];

void main() {
    vec2 st = gl_FragCoord.xy;
    vec4 final_color = vec4(0.0);

    if (spots_count > 0) {
        for (int i = 0; i < spots_count; i++) {
            if (i >= MAX_SPOTS) break;

            vec2 pos = spots_positions[i];
            float size = spots_sizes[i];
            float age = spots_ages[i];
            float lifetime = spots_lifetimes[i];

            float dist = distance(st, pos);

            if (dist < size) {
                // 1. Интенсивность в зависимости от расстояния до центра (плавный край)
                float intensity = 1.0 - smoothstep(0.0, size, dist);

                // 2. Модификатор жизненного цикла (плавное появление и исчезновение)
                float life_factor = 0.0;
                float fade_in_duration = 0.1 * lifetime; // 10% времени на появление
                float fade_out_duration = 0.2 * lifetime; // 20% времени на исчезновение

                if (age < fade_in_duration) {
                    life_factor = smoothstep(0.0, fade_in_duration, age);
                } else if (age > lifetime - fade_out_duration) {
                    life_factor = 1.0 - smoothstep(lifetime - fade_out_duration, lifetime, age);
                } else {
                    life_factor = 1.0;
                }
                
                // 3. Базовый цвет пятна
                vec3 spot_color = vec3(0.6, 0.15, 0.0); // Темно-оранжевый

                // 4. Комбинируем все вместе
                float alpha = intensity * life_factor;
                vec4 current_spot_color = vec4(spot_color, alpha);

                // 5. Смешиваем с результатом (простое сложение, т.к. фон прозрачный)
                final_color += current_spot_color;
            }
        }
    }

    gl_FragColor = final_color;
}
