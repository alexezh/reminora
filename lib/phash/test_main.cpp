#include "CrossCorrelation.hpp"
#include <iostream>
#include <vector>
#include <random>

using namespace Shipwreck::Phash;

int main() {
    std::cout << "Phash Cross Correlation C++ Library Test\n";
    std::cout << "=========================================\n\n";

    // Test 1: Cross Correlation
    std::cout << "Test 1: Cross Correlation\n";
    std::vector<uint8_t> data1 = {1, 2, 3, 4, 5, 6, 7, 8};
    std::vector<uint8_t> data2 = {2, 3, 4, 5, 6, 7, 8, 9};
    
    float correlation = CrossCorrelation::GetCrossCorrelation(data1, data2);
    std::cout << "Correlation between similar sequences: " << correlation << "\n\n";

    // Test 2: Hamming Distance
    std::cout << "Test 2: Hamming Distance\n";
    uint64_t hash1 = 0b1010101010101010ULL;
    uint64_t hash2 = 0b1010101010101011ULL;
    
    int distance = CrossCorrelation::GetHammingDistance(hash1, hash2);
    std::cout << "Hamming distance between 0x" << std::hex << hash1 
              << " and 0x" << hash2 << std::dec << ": " << distance << "\n";

    // Test 3: Identical sequences
    std::cout << "\nTest 3: Identical sequences\n";
    correlation = CrossCorrelation::GetCrossCorrelation(data1, data1);
    std::cout << "Correlation between identical sequences: " << correlation << "\n";

    distance = CrossCorrelation::GetHammingDistance(hash1, hash1);
    std::cout << "Hamming distance between identical hashes: " << distance << "\n";

    // Test 4: Random data performance test
    std::cout << "\nTest 4: Performance test with random data\n";
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, 255);

    std::vector<uint8_t> large_data1(1000);
    std::vector<uint8_t> large_data2(1000);
    
    for (size_t i = 0; i < 1000; ++i) {
        large_data1[i] = dis(gen);
        large_data2[i] = dis(gen);
    }

    correlation = CrossCorrelation::GetCrossCorrelation(large_data1, large_data2);
    std::cout << "Correlation between 1000-element random sequences: " << correlation << "\n";

    std::cout << "\nAll tests completed successfully!\n";
    return 0;
}