//
//  SVGKitUtilities.h
//  reminora
//
//  Created by Claude on 8/4/25.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SVGKitUtilities : NSObject

// Utility to configure SVGKit with consistent settings
+ (void)configureDefaultSettings;

// Get consistent PPI value for SVG rendering
+ (CGFloat)defaultPixelsPerInch;

// Install method swizzling to override SVGKit PPI calculation
+ (void)installPixelsPerInchOverride;

@end