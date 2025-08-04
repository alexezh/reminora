//
//  SVGKitUtilities.m
//  reminora
//
//  Created by Claude on 8/4/25.
//

#import "SVGKitUtilities.h"
#import <objc/runtime.h>

static CGFloat defaultPPI = 326.0f; // Consistent PPI for SVG rendering

// Custom implementation to return consistent PPI
static float customPixelsPerInchForCurrentDevice(id self, SEL _cmd) {
    NSLog(@"🎨 SVGKit: Using custom PPI: %.1f", defaultPPI);
    return (float)defaultPPI;
}

@implementation SVGKitUtilities

+ (void)load {
    // Automatically install the PPI override when the class loads
    [self installPixelsPerInchOverride];
}

+ (void)configureDefaultSettings {
    // This utility can be extended to configure SVGKit settings
    NSLog(@"SVGKit configured with default PPI: %.1f", defaultPPI);
}

+ (CGFloat)defaultPixelsPerInch {
    return defaultPPI;
}

+ (void)installPixelsPerInchOverride {
    // Find the SVGLength class at runtime
    Class svgLengthClass = NSClassFromString(@"SVGLength");
    if (svgLengthClass) {
        // Get the original method
        Method originalMethod = class_getClassMethod(svgLengthClass, @selector(pixelsPerInchForCurrentDevice));
        
        if (originalMethod) {
            // Replace the implementation with our custom one
            method_setImplementation(originalMethod, (IMP)customPixelsPerInchForCurrentDevice);
            NSLog(@"🎨 SVGKit: Successfully installed custom pixelsPerInchForCurrentDevice override");
        } else {
            NSLog(@"⚠️ SVGKit: Could not find pixelsPerInchForCurrentDevice method to override");
        }
    } else {
        NSLog(@"⚠️ SVGKit: Could not find SVGLength class for PPI override");
    }
}

@end