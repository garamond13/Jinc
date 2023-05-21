//!HOOK MAIN
//!BIND HOOKED
//!SAVE PASS1
//!WHEN OUTPUT.w OUTPUT.h * MAIN.w MAIN.h * <
//!DESC jinc downscale pass1

vec4 hook() {
    return linearize(textureLod(HOOKED_raw, HOOKED_pos, 0.0) * HOOKED_mul);
}

//!HOOK MAIN
//!BIND PASS1
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!WHEN OUTPUT.w OUTPUT.h * MAIN.w MAIN.h * <
//!DESC jinc downscale pass2

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
// USER CONFIGURABLE, PASS 2 (downsample)
//
#define K GINSENG //kernel function, see "KERNEL FUNCTIONS LIST"
#define R 2.0 //kernel radius, (0.0, 10.0+]
#define B 1.0 //kernel blur, 1.0 means no effect, (0.0, 1.5+]
#define AA 1.0 //antialiasing amount, reduces aliasing, but increases ringing, (0.0, 1.0+]
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

#define J1(x) ((x) < 2.2931157332 ? ((x) / 2.0) - ((x) * (x) * (x) / 16.0) + ((x) * (x) * (x) * (x) * (x) / 384.0) - ((x) * (x) * (x) * (x) * (x) * (x) * (x) / 18432.0) : sqrt(M_2_PI / (x)) * (1.0 + 0.1875 / ((x) * (x)) - 0.193359375 / ((x) * (x) * (x) * (x))) * cos((x) - 3.0 * M_PI_4 + 0.375 / (x) - 0.1640625 / ((x) * (x) * (x))))

#define jinc(x) ((x) < EPSILON ? M_PI_2 / B : J1(M_PI / B * (x)) / (x))

#if K == GINSENG
    #define k(x) (jinc(x) * ((x) < EPSILON ? M_PI / R : sin(M_PI / R * (x)) / (x)))
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

#define SCALE (max(input_size.y / target_size.y, input_size.x / target_size.x) * AA)

vec4 hook() {
    vec2 fcoord = fract(PASS1_pos * input_size - 0.5);
    vec2 base = PASS1_pos - fcoord * PASS1_pt;
    vec4 csum = vec4(0.0);
    float weight;
    float wsum = 0.0;
    for (float y = 1.0 - ceil(R * SCALE); y <= ceil(R * SCALE); ++y) {
        for (float x = 1.0 - ceil(R * SCALE); x <= ceil(R * SCALE); ++x) {
            weight = get_weight(length(vec2(x, y) - fcoord) / SCALE);
            csum += textureLod(PASS1_raw, base + PASS1_pt * vec2(x, y), 0.0) * PASS1_mul * weight;
            wsum += weight;
        }
    }
    return delinearize(csum / wsum);
}