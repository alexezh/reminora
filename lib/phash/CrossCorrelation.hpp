#pragma once

#include <vector>
#include <cmath>
#include <algorithm>
#include <cstdint>

#ifdef __x86_64__
#include <immintrin.h>
#include <popcntintrin.h>
#endif

namespace Shipwreck {
namespace Phash {

class CrossCorrelation {
public:
    // Public interface methods
    static float GetCrossCorrelation(const std::vector<uint8_t>& coefficients1, 
                                   const std::vector<uint8_t>& coefficients2);
    
    static int GetHammingDistance(int64_t x, int64_t y);
    static int GetHammingDistance(uint64_t x, uint64_t y);
    static int GetHammingDistance(int64_t v);
    static int GetHammingDistance(uint64_t v);

private:
    // Internal core methods
    static float GetCrossCorrelationCore(const uint8_t* x, const uint8_t* y, int length);
    static float GetCrossCorrelationCore(const std::vector<uint8_t>& x, 
                                       const std::vector<uint8_t>& y, int length);
    static float GetCrossCorrelationCore(const std::vector<float>& x, 
                                       const std::vector<float>& y);
    static float GetCrossCorrelationForOffset(const std::vector<float>& x, 
                                            const std::vector<float>& y, int offset);
    static int GetHammingDistanceCore(uint64_t v);
};

} // namespace Phash
} // namespace Shipwreck