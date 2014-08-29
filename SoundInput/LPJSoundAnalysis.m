//
//  LPJSoundAnalysis.m
//  SoundInput
//
//  Created by Lukas Joswiak on 8/19/14.
//  Copyright (c) 2014 Lukas Joswiak. All rights reserved.
//

#import "LPJSoundAnalysis.h"

@implementation LPJSoundAnalysis

// Get index where slope stops increasing left of max
- (NSArray *)leftBoundWithGraph:(NSMutableArray *)array max:(float)max maxIndex:(int)index
{
    float leftMinSlope = 20;
    
    float leftBound = 0;
    float leftValue = 0;
    float latestValue = max;
    for (int i = index - 1; i > 0; i--) {
        if ([array[i] floatValue] < latestValue - leftMinSlope || index - i < 5) {
            latestValue = [array[i] floatValue];
        } else {
            leftBound = i;
            leftValue = [array[i] floatValue];
            
            leftMinSlope = [array[i + 2] floatValue] - [array[i + 1] floatValue];
            
            // Calculate average of first 5 data points to extrapolate data to 0
            for (int j = i; j < i + 10; j++) {
                if ([array[j + 1] floatValue] - [array[j] floatValue] > leftMinSlope) {
                    leftBound = j;
                    NSLog(@"Left bound from j: %d", j);
                    break;
                }
            }
            break;
        }
    }
    return @[[NSNumber numberWithInt:leftBound], [NSNumber numberWithFloat:leftValue], [NSNumber numberWithFloat:leftMinSlope]];
}

- (NSArray *)rightBoundWithGraph:(NSMutableArray *)array max:(float)max maxIndex:(int)index left:(float)leftValue
{
    float rightMinSlope = 10;
    for (int i = index + 1; i < 9999999; i++) {
        if ([array[i] floatValue] - [array[i + 1] floatValue] < rightMinSlope) {
            rightMinSlope = ([array[i] floatValue] - [array[i + 1] floatValue]) * -1;
            return @[[NSNumber numberWithInt:i], [NSNumber numberWithFloat:rightMinSlope]];
        }
    }
    return @[@0, @0];
}

@end
