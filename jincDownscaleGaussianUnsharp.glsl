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
//!SAVE PASS2
//!WHEN OUTPUT.w OUTPUT.h * MAIN.w MAIN.h * <
//!DESC jinc downscale pass2

////////////////////////////////////////////////////////////////////////
// USER CONFIGURABLE, PASS 2 (blur in y axis)
//
// CAUTION! probably should use the same settings for "USER CONFIGURABLE, PASS 3" below
//
#define S 1.0 //blur spread or amount, (0.0, 10+]
#define R 3.0 //kernel radius (integer as float, e.g. 3.0), (0.0, 10+]; probably should set it to ceil(3 * S)
//
////////////////////////////////////////////////////////////////////////

#define get_weight(x) (exp(-x * x / (2.0 * S * S)))

vec4 hook() {
    float weight;
    vec4 csum = textureLod(PASS1_raw, PASS1_pos, 0.0) * PASS1_mul;
    float wsum = 1.0;
    for(float i = 1.0; i <= R; ++i) {
        weight = get_weight(i);
        csum += (textureLod(PASS1_raw, PASS1_pos + PASS1_pt * vec2(0.0, -i), 0.0) + textureLod(PASS1_raw, PASS1_pos + PASS1_pt * vec2(0.0, i), 0.0)) * PASS1_mul * weight;
        wsum += 2.0 * weight;
    }
    return csum / wsum;
}

//!HOOK MAIN
//!BIND PASS2
//!SAVE PASS3
//!WHEN OUTPUT.w OUTPUT.h * MAIN.w MAIN.h * <
//!DESC jinc downscale pass3

////////////////////////////////////////////////////////////////////////
// USER CONFIGURABLE, PASS 3 (blur in x axis)
//
// CAUTION! probably should use the same settings for "USER CONFIGURABLE, PASS 2" above
//
#define S 1.0 //blur spread or amount, (0.0, 10+]
#define R 3.0 //kernel radius (integer as float, e.g. 3.0), (0.0, 10+]; probably should set it to ceil(3 * S)
//
////////////////////////////////////////////////////////////////////////

#define get_weight(x) (exp(-x * x / (2.0 * S * S)))

vec4 hook() {
    float weight;
    vec4 csum = textureLod(PASS2_raw, PASS2_pos, 0.0) * PASS2_mul;
    float wsum = 1.0;
    for(float i = 1.0; i <= R; ++i) {
        weight = get_weight(i);
        csum += (textureLod(PASS2_raw, PASS2_pos + PASS2_pt * vec2(-i, 0.0), 0.0) + textureLod(PASS2_raw, PASS2_pos + PASS2_pt * vec2(i, 0.0), 0.0)) * PASS2_mul * weight;
        wsum += 2.0 * weight;
    }
    return csum / wsum;
}

//!HOOK MAIN
//!BIND PASS3
//!SAVE PASS4
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!WHEN OUTPUT.w OUTPUT.h * MAIN.w MAIN.h * <
//!DESC jinc downscale pass4

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
// USER CONFIGURABLE, PASS 4 (downsample)
//
#define K GINSENG //kernel function, see "KERNEL FUNCTIONS LIST"
#define R 2.0 //kernel radius, (0.0, 10.0+]
#define B 1.0 //kernel blur, 1.0 means no effect, (0.0, 1.5+]
#define AA 1.0 //antialiasing amount, reduces aliasing, but increases ringing, (0.0, 1.0+]
//
//kernel function parameters
#define P1 0.0 //COSINE: n, BLACKMAN: a, GARAMOND: n, GNW: s, SAID: chi, FSR: b, BCSPLINE: B
#define P2 0.0 //GARAMOND: m, BLACKMAN: n, GNW: n, SAID: eta, FSR: c, BCSPLINE: C
//
////////////////////////////////////////////////////////////////////////

#define M_PI 3.14159265358979323846
#define M_PI_2 1.57079632679489661923
#define M_PI_4 0.785398163397448309616
#define EPSILON 1.192093e-7

#define J1(x) (x < 3.5 ? (x * (72362614232.0 + x * x * (-7895059235.0 + x * x * (242396853.1 + x * x * (-2972611.439 + x * x * 15704.48260))))) / (144725228442.0 + x * x * (2300535178.0 + x * x * (18583304.74 + x * x * (99447.43394 + x * x * (376.9991397 + x * x))))) : sqrt(2.0 / (M_PI * x)) * (1.0 + 3.0 / (16.0 * x * x) - 99.0 / (512.0 * x * x * x * x)) * cos(x - 3.0 * M_PI_4 + 3.0 / (8.0 * x) - 21.0 / (128.0 * x * x * x)))

#define jinc(x) (x < EPSILON ? M_PI_2 : J1(M_PI / B * x) * B / x)

#if K == GINSENG
    #define k(x) (jinc(x) * (x < EPSILON ? M_PI : sin(M_PI / R * x) * R / x))
#elif K == COSINE
    #define k(x) (jinc(x) * pow(cos(M_PI_2 / R * x), P1))
#elif K == GARAMOND
    #define k(x) (jinc(x) * pow(1.0 - pow(x / R, P1), P2))
#elif K == BLACKMAN
    #define k(x) (jinc(x) * pow((1.0 - P1) / 2.0 + 0.5 * cos(M_PI / R * x) + P1 / 2.0 * cos(2.0 * M_PI / R * x), P2))
#elif K == GNW
    #define k(x) (jinc(x) * exp(-pow(x / P1, P2)))
#elif K == SAID
    #define k(x) (jinc(x) * cosh(sqrt(2.0 * P2) * M_PI * P1 / (2.0 - P2) * x) * exp(-M_PI * M_PI * P1 * P1 / ((2.0 - P2) * (2.0 - P2)) * x * x))
#elif K == FSR
    #undef R
    #define R 2.0
    #define k(x) ((1.0 / (2.0 * P1 - P1 * P1) * (P1 / (P2 * P2) * x * x - 1.0) * (P1 / (P2 * P2) * x * x - 1.0) - (1.0 / (2.0 * P1 - P1 * P1) - 1.0)) * (0.25 * x * x - 1.0) * (0.25 * x * x - 1.0))
#elif K == BCSPLINE
    #undef R
    #define R 2.0
    #define k(x) (x < 1.0 ? (12.0 - 9.0 * P1 - 6.0 * P2) * x * x * x + (-18.0 + 12.0 * P1 + 6.0 * P2) * x * x + (6.0 - 2.0 * P1) : (-P1 - 6.0 * P2) * x * x * x + (6.0 * P1 + 30.0 * P2) * x * x + (-12.0 * P1 - 48.0 * P2) * x + (8.0 * P1 + 24.0 * P2))
#endif

#define get_weight(x) (x < R ? k(x) : 0.0)

#define SCALE (max(input_size.y / target_size.y, input_size.x / target_size.x) * AA)

vec4 hook() {
    vec2 fcoord = fract(PASS3_pos * input_size - 0.5);
    vec2 base = PASS3_pos - fcoord * PASS3_pt;
    vec4 csum = vec4(0.0);
    float weight;
    float wsum = 0.0;
    for (float y = 1.0 - ceil(R * SCALE); y <= ceil(R * SCALE); ++y) {
        for (float x = 1.0 - ceil(R * SCALE); x <= ceil(R * SCALE); ++x) {
            weight = get_weight(length(vec2(x, y) - fcoord) / SCALE);
            csum += textureLod(PASS3_raw, base + PASS3_pt * vec2(x, y), 0.0) * PASS3_mul * weight;
            wsum += weight;
        }
    }
    return csum / wsum;
}

//!HOOK MAIN
//!BIND PASS4
//!SAVE PASS5
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!WHEN OUTPUT.w OUTPUT.h * MAIN.w MAIN.h * <
//!DESC jinc downscale pass5

////////////////////////////////////////////////////////////////////////
// USER CONFIGURABLE, PASS 5 (blur in y axis)
//
// CAUTION! probably should use the same settings for "USER CONFIGURABLE, PASS 6" below
//
#define S 1.0 //blur spread or amount, (0.0, 10+]
#define R 3.0 //kernel radius (integer as float, e.g. 3.0), (0.0, 10+]; probably should set it to ceil(3 * S)
//
////////////////////////////////////////////////////////////////////////

#define get_weight(x) (exp(-x * x / (2.0 * S * S)))

vec4 hook() {
    float weight;
    vec4 csum = textureLod(PASS4_raw, PASS4_pos, 0.0) * PASS4_mul;
    float wsum = 1.0;
    for(float i = 1.0; i <= R; ++i) {
        weight = get_weight(i);
        csum += (textureLod(PASS4_raw, PASS4_pos + PASS4_pt * vec2(0.0, -i), 0.0) + textureLod(PASS4_raw, PASS4_pos + PASS4_pt * vec2(0.0, i), 0.0)) * PASS4_mul * weight;
        wsum += 2.0 * weight;
    }
    return csum / wsum;
}

//!HOOK MAIN
//!BIND PASS4
//!BIND PASS5
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!WHEN OUTPUT.w OUTPUT.h * MAIN.w MAIN.h * <
//!DESC jinc downscale pass6

////////////////////////////////////////////////////////////////////////
// USER CONFIGURABLE, PASS 6 (blur in x axis and apply unsharp mask)
//
// CAUTION! probably should use the same settings for "USER CONFIGURABLE, PASS 5" above
//
#define S 1.0 //blur spread or amount, (0.0, 10+]
#define R 3.0 //kernel radius (integer as float, e.g. 3.0), (0.0, 10+]; probably should set it to ceil(3 * S)
//
//sharpnes
#define A 0.5 //amount of sharpening [0.0, 10+]
//
////////////////////////////////////////////////////////////////////////

#define get_weight(x) (exp(-x * x / (2.0 * S * S)))

vec4 hook() {
    float weight;
    vec4 csum = textureLod(PASS5_raw, PASS5_pos, 0.0) * PASS5_mul;
    float wsum = 1.0;
    for(float i = 1.0; i <= R; ++i) {
        weight = get_weight(i);
        csum += (textureLod(PASS5_raw, PASS5_pos + PASS5_pt * vec2(-i, 0.0), 0.0) + textureLod(PASS5_raw, PASS5_pos + PASS5_pt * vec2(i, 0.0), 0.0)) * PASS5_mul * weight;
        wsum += 2.0 * weight;
    }
    vec4 original = textureLod(PASS4_raw, PASS4_pos, 0.0) * PASS4_mul;
    return delinearize(original + (original - csum / wsum) * A);
}
