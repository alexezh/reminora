# Simple Makefile for Phash Cross Correlation C++ Library

CXX = g++
CXXFLAGS = -std=c++17 -O3 -Wall -Wextra
INCLUDES = -I.

# Check for x86_64 and add POPCNT support if available
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),x86_64)
    CXXFLAGS += -mpopcnt -D__POPCNT__
endif

# Object files
OBJS = CrossCorrelation.o
TARGET_LIB = libphash_cross_correlation.a
TARGET_TEST = phash_test

# Default target
all: $(TARGET_LIB) $(TARGET_TEST)

# Static library
$(TARGET_LIB): $(OBJS)
	ar rcs $@ $^

# Object files
%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

# Test executable
$(TARGET_TEST): test_main.o $(TARGET_LIB)
	$(CXX) $(CXXFLAGS) $^ -o $@

# Test execution
test: $(TARGET_TEST)
	./$(TARGET_TEST)

# Clean up
clean:
	rm -f *.o $(TARGET_LIB) $(TARGET_TEST)

# Install (basic)
install: $(TARGET_LIB)
	mkdir -p /usr/local/lib /usr/local/include/shipwreck/phash
	cp $(TARGET_LIB) /usr/local/lib/
	cp CrossCorrelation.hpp /usr/local/include/shipwreck/phash/

.PHONY: all test clean install