#include "CrossCorrelation.hpp"
#include <numeric>
#include <cassert>

namespace Shipwreck {
namespace Phash {

// Public interface methods
float CrossCorrelation::GetCrossCorrelation(const std::vector<uint8_t>& coefficients1, 
                                           const std::vector<uint8_t>& coefficients2) {
    return GetCrossCorrelationCore(coefficients1, coefficients2, 
                                  std::min(coefficients1.size(), coefficients2.size()));
}

int CrossCorrelation::GetHammingDistance(int64_t x, int64_t y) {
    return GetHammingDistance(static_cast<uint64_t>(x ^ y));
}

int CrossCorrelation::GetHammingDistance(uint64_t x, uint64_t y) {
    return GetHammingDistance(x ^ y);
}

int CrossCorrelation::GetHammingDistance(int64_t v) {
    return GetHammingDistanceCore(static_cast<uint64_t>(v));
}

int CrossCorrelation::GetHammingDistance(uint64_t v) {
    return GetHammingDistanceCore(v);
}

// Internal core methods
float CrossCorrelation::GetCrossCorrelationCore(const std::vector<uint8_t>& x, 
                                               const std::vector<uint8_t>& y, int length) {
    assert(length <= static_cast<int>(x.size()));
    assert(length <= static_cast<int>(y.size()));
    
    int sumX = 0;
    int sumY = 0;
    for (int i = 0; i < length; i++) {
        sumX += x[i];
        sumY += y[i];
    }

    float meanX = sumX / static_cast<float>(length);
    float meanY = sumY / static_cast<float>(length);

    std::vector<float> fx(length);
    std::vector<float> fy(length);

    for (int i = 0; i < length; i++) {
        fx[i] = x[i] - meanX;
        fy[i] = y[i] - meanY;
    }

    return GetCrossCorrelationCore(fx, fy);
}

float CrossCorrelation::GetCrossCorrelationCore(const uint8_t* x, const uint8_t* y, int length) {
    int sumX = 0;
    int sumY = 0;
    for (int i = 0; i < length; i++) {
        sumX += x[i];
        sumY += y[i];
    }

    float meanX = sumX / static_cast<float>(length);
    float meanY = sumY / static_cast<float>(length);

    std::vector<float> fx(length);
    std::vector<float> fy(length);

    for (int i = 0; i < length; i++) {
        fx[i] = x[i] - meanX;
        fy[i] = y[i] - meanY;
    }

    return GetCrossCorrelationCore(fx, fy);
}

float CrossCorrelation::GetCrossCorrelationCore(const std::vector<float>& x, 
                                               const std::vector<float>& y) {
    float max = 0.0f;
    for (size_t d = 0; d < x.size(); d++) {
        float v = GetCrossCorrelationForOffset(x, y, static_cast<int>(d));
        max = std::max(max, v);
    }

    return std::sqrt(max);
}

float CrossCorrelation::GetCrossCorrelationForOffset(const std::vector<float>& x, 
                                                    const std::vector<float>& y, int offset) {
    float num = 0.0f;
    float denx = 0.0f;
    float deny = 0.0f;

    for (int j = 0; j < 2; j++) {
        int th = j == 0 ? static_cast<int>(x.size()) - offset : static_cast<int>(x.size());
        int i = j == 0 ? 0 : static_cast<int>(x.size()) - offset;
        int yo = offset - j * static_cast<int>(x.size());

        for (; i < th; i++) {
            float dx = x[i];
            float dy = y[i + yo];
            num += dx * dy;
            denx += dx * dx;
            deny += dy * dy;
        }
    }

    return (num < 0 || denx == 0 || deny == 0) ? 0 : (num * num / (denx * deny));
}

int CrossCorrelation::GetHammingDistanceCore(uint64_t v) {
#ifdef __x86_64__
    // Use hardware population count if available
    #ifdef __POPCNT__
    return static_cast<int>(__builtin_popcountll(v));
    #endif
#endif

    // Software implementation (Brian Kernighan's method optimized)
    v = v - ((v >> 1) & 0x5555555555555555ULL);
    v = (v & 0x3333333333333333ULL) + ((v >> 2) & 0x3333333333333333ULL);
    return static_cast<int>((((v + (v >> 4)) & 0xF0F0F0F0F0F0F0FULL) * 0x101010101010101ULL) >> 56);
}

} // namespace Phash
} // namespace Shipwreck