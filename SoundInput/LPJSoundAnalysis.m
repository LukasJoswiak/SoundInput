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
    float leftBound = 0;
    float leftValue = 0;
    float latestValue = max;
    for (int i = index - 1; i > 0; i--) {
        if ([array[i] floatValue] < latestValue) {
            latestValue = [array[i] floatValue];
        } else {
            leftBound = i;
            leftValue = [array[i] floatValue];
            break;
        }
    }
    return @[[NSNumber numberWithInt:leftBound], [NSNumber numberWithFloat:leftValue]];
}

- (int)rightBoundWithGraph:(NSMutableArray *)array max:(float)max maxIndex:(int)index left:(float)leftValue
{
    for (int i = index + 1; i < 9999999; i++) {
        if ([array[i] floatValue] < leftValue) {
            return i;
        }
    }
    return 0;
}

@end
