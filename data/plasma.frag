#ifdef GL_ES
precision mediump float;
#endif

uniform float time;
uniform vec2 resolution;
uniform float brightness;

uniform float waveProgress; // 0.0 to 1.0
uniform vec2 waveCenter;   // center of the wave in pixels
uniform bool isSunrise;    // true for sunrise, false for sunset

// 2D Random
float random (in vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))
                 * 43758.5453123);
}

// 2D Noise based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noise (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    // Smooth Interpolation

    // Cubic Hermine Curve.  Same as SmoothStep()
    vec2 u = f*f*(3.0-2.0*f);
    // u = smoothstep(0.,1.,f);

    // Mix 4 coorners percentages
    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

#define OCTAVES 6
float fbm (in vec2 st) {
    // Initial values
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;
    //
    // Loop of octaves
    for (int i = 0; i < OCTAVES; i++) {
        value += amplitude * noise(st);
        st *= 2.;
        amplitude *= .5;
    }
    return value;
}

void main() {
    vec2 st = gl_FragCoord.xy; // working in pixel coordinates
    
    // --- Plasma Calculation ---
    vec2 st_norm = st / resolution.xy;
    st_norm.x *= resolution.x / resolution.y;
    float plasma = fbm(st_norm * 3.0 + time * 0.1);
    vec3 plasmaColor = mix(vec3(0.8, 0.3, 0.1), vec3(1.0, 0.8, 0.2), plasma);

    // --- Wave Calculation ---
    float waveFactor = 1.0;
    if (waveProgress <= 1.0) {
        float dist = distance(st, waveCenter);
        float maxDist = length(resolution); // Maximum possible distance
        float waveFront = waveProgress * maxDist;
        float waveWidth = 0.2 * maxDist; // 20% of screen size as wave width

        if (isSunrise) {
            // --- Sunrise Wave ---
            // Creates a smooth band of light that moves across the screen
            waveFactor = smoothstep(waveFront - waveWidth, waveFront, dist) - smoothstep(waveFront, waveFront + waveWidth, dist);
            
            // Change color based on position in the wave
            float waveEdgeFactor = smoothstep(waveFront - waveWidth, waveFront, dist);
            vec3 sunriseColor = mix(vec3(1.0, 0.2, 0.0), vec3(1.0, 0.9, 0.5), waveEdgeFactor); // from red to yellow
            plasmaColor = mix(plasmaColor, sunriseColor, waveEdgeFactor);

        } else {
            // --- Sunset Wave ---
            // Creates a wave of darkness
            waveFactor = 1.0 - smoothstep(waveFront - waveWidth, waveFront, dist);
        }
    }

    // Final color calculation
    vec3 finalColor = plasmaColor * waveFactor * brightness;

    gl_FragColor = vec4(finalColor, 1.0);
}
