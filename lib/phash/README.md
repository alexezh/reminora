# Phash Cross Correlation C++ Library

This directory contains both C# and C++ implementations of a perceptual hash cross-correlation library.

## Files

### C# Implementation (Original)
- `CrossCorrelation.cs` - Public API for cross-correlation and Hamming distance calculations
- `CrossCorrelation.Core.cs` - Core implementation with optimizations for different .NET targets

### C++ Implementation (Clone)
- `CrossCorrelation.hpp` - Header file with class declarations
- `CrossCorrelation.cpp` - Implementation file with all core algorithms
- `CMakeLists.txt` - Build configuration for CMake
- `test_main.cpp` - Example usage and test program
- `README.md` - This documentation file

## Functionality

The library provides two main features:

1. **Cross Correlation**: Computes similarity between two byte arrays representing image coefficients
2. **Hamming Distance**: Counts the number of differing bits between two hash values

## Building (C++)

```bash
mkdir build
cd build
cmake ..
make
```

This will create:
- `libphash_cross_correlation.a` - Static library
- `phash_test` - Test executable

## Usage (C++)

```cpp
#include "CrossCorrelation.hpp"
using namespace Shipwreck::Phash;

// Cross correlation between two byte arrays
std::vector<uint8_t> data1 = {1, 2, 3, 4, 5};
std::vector<uint8_t> data2 = {2, 3, 4, 5, 6};
float correlation = CrossCorrelation::GetCrossCorrelation(data1, data2);

// Hamming distance between two hashes
uint64_t hash1 = 0x123456789ABCDEF0ULL;
uint64_t hash2 = 0x123456789ABCDEF1ULL;
int distance = CrossCorrelation::GetHammingDistance(hash1, hash2);
```

## Optimizations

### C# Version Features:
- Vector intrinsics support (System.Numerics.Vector)
- x86 POPCNT instruction support
- Unsafe pointer operations for performance
- Span<T> support for modern .NET

### C++ Version Features:
- Hardware POPCNT instruction support on x86_64
- Template-based optimizations
- STL container compatibility
- CMake build system with optimization flags

## Algorithm Details

### Cross Correlation
1. Calculate mean values for both input arrays
2. Subtract means to create zero-mean arrays
3. Compute cross-correlation for all possible offsets
4. Return square root of maximum correlation value

### Hamming Distance
1. XOR the two input values
2. Count set bits using either:
   - Hardware POPCNT instruction (when available)
   - Optimized bit manipulation algorithm

## Performance Notes

- The C++ implementation includes hardware acceleration when available
- For large arrays, the algorithm complexity is O(n²) where n is array length
- Hamming distance is O(1) with hardware support, O(log n) without

## Compatibility

- **C# Version**: .NET Framework 4.0+, .NET Core 2.0+, .NET 5+
- **C++ Version**: C++17 compatible compilers (GCC 7+, Clang 5+, MSVC 2017+)