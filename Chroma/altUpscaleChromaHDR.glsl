//!HOOK CHROMA
//!BIND HOOKED
//!WIDTH LUMA.w
//!HEIGHT LUMA.h
//!WHEN LUMA.w LUMA.h * CHROMA.w CHROMA.h * >
//!DESC jinc upscale chroma

////////////////////////////////////////////////////////////////////////
// KERNEL FUNCTIONS LIST
//
#define GINSENG 1
#define COSINE 2
#define GARAMOND 3
#define BLACKMAN 4
#define GNW 5
#define SAID 6
#define FSR 7
#define BCSPLINE 8
//
////////////////////////////////////////////////////////////////////////
// USER CONFIGURABLE, (upsample)
//
#define K GINSENG //kernel function, see "KERNEL FUNCTIONS LIST"
#define R 2.0 //kernel radius, (0.0, 10.0+]
#define B 1.0 //kernel blur, 1.0 means no effect, (0.0, 1.5+]
#define AR 1.0 //antiringing strenght, [0.0, 1.0]
//
//kernel function parameters
#define P1 0.0 //COSINE: n, GARAMOND: n, BLACKMAN: a, GNW: s, SAID: chi, FSR: b, BCSPLINE: B
#define P2 0.0 //GARAMOND: m, BLACKMAN: n, GNW: n, SAID: eta, FSR: c, BCSPLINE: C
//
////////////////////////////////////////////////////////////////////////

#define M_PI 3.14159265358979323846
#define M_PI_2 1.57079632679489661923
#define M_PI_4 0.785398163397448309616
#define M_2_PI 0.636619772367581343076
#define EPSILON 1.192093e-7

#define J1(x) ((x) < 2.293115733230086 ? ((x) / 2.0) - ((x) * (x) * (x) / 16.0) + ((x) * (x) * (x) * (x) * (x) / 384.0) - ((x) * (x) * (x) * (x) * (x) * (x) * (x) / 18432.0) : sqrt(M_2_PI / (x)) * (1.0 + 3.0 / 16.0 / ((x) * (x)) - 99.0 / 512.0 / ((x) * (x) * (x) * (x))) * cos((x) - 3.0 * M_PI_4 + 3.0 / 8.0 / (x) - 21.0 / 128.0 / ((x) * (x) * (x))))

#define jinc(x) ((x) < EPSILON ? M_PI_2 : J1(M_PI / B * (x)) * B / (x))

#if K == GINSENG
    #define k(x) (jinc(x) * ((x) < EPSILON ? M_PI : sin(M_PI / R * (x)) * R / (x)))
#elif K == COSINE
    #define k(x) (jinc(x) * pow(cos(M_PI_2 / R * (x)), P1))
#elif K == GARAMOND
    #define k(x) (jinc(x) * pow(1.0 - pow((x) / R, P1), P2))
#elif K == BLACKMAN
    #define k(x) (jinc(x) * pow((1.0 - P1) / 2.0 + 0.5 * cos(M_PI / R * (x)) + P1 / 2.0 * cos(2.0 * M_PI / R * (x)), P2))
#elif K == GNW
    #define k(x) (jinc(x) * exp(-pow((x) / P1, P2)))
#elif K == SAID
    #define k(x) (jinc(x) * cosh(sqrt(2.0 * P2) * M_PI * P1 / (2.0 - P2) * (x)) * exp(-M_PI * M_PI * P1 * P1 / ((2.0 - P2) * (2.0 - P2)) * (x) * (x)))
#elif K == FSR
    #undef R
    #define R 2.0
    #define k(x) ((1.0 / (2.0 * P1 - P1 * P1) * (P1 / (P2 * P2) * (x) * (x) - 1.0) * (P1 / (P2 * P2) * (x) * (x) - 1.0) - (1.0 / (2.0 * P1 - P1 * P1) - 1.0)) * (0.25 * (x) * (x) - 1.0) * (0.25 * (x) * (x) - 1.0))
#elif K == BCSPLINE
    #undef R
    #define R 2.0
    #define k(x) ((x) < 1.0 ? (12.0 - 9.0 * P1 - 6.0 * P2) * (x) * (x) * (x) + (-18.0 + 12.0 * P1 + 6.0 * P2) * (x) * (x) + (6.0 - 2.0 * P1) : (-P1 - 6.0 * P2) * (x) * (x) * (x) + (6.0 * P1 + 30.0 * P2) * (x) * (x) + (-12.0 * P1 - 48.0 * P2) * (x) + (8.0 * P1 + 24.0 * P2))
#endif

#define get_weight(x) ((x) < R ? k(x) : 0.0)

vec4 hook() {
    vec2 fcoord = fract(HOOKED_pos * input_size - 0.5);
    vec2 base = HOOKED_pos - fcoord * HOOKED_pt;
    vec4 color;
    vec4 csum = vec4(0.0);
    float weight;
    float wsum = 0.0;
    vec4 low = vec4(1e9);
    vec4 high = vec4(-1e9);
    for (float y = 1.0 - ceil(R); y <= ceil(R); ++y) {
        for (float x = 1.0 - ceil(R); x <= ceil(R); ++x) {
            weight = get_weight(length(vec2(x, y) - fcoord));
            color = textureLod(HOOKED_raw, base + HOOKED_pt * vec2(x, y), 0.0) * HOOKED_mul;
            csum += color * weight;
            wsum += weight;
            if (AR > 0.0 && y >= 0.0 && y <= 1.0 && x >= 0.0 && x <= 1.0) {
                low = min(low, color);
                high = max(high, color);
            }
        }
    }
    csum /= wsum;
    if (AR > 0.0)
        csum = mix(csum, clamp(csum, low, high), AR);
    return csum;
}
