//
//  LPJSoundAnalysis.h
//  SoundInput
//
//  Created by Lukas Joswiak on 8/19/14.
//  Copyright (c) 2014 Lukas Joswiak. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LPJSoundAnalysis : NSObject

- (NSArray *)leftBoundWithGraph:(NSMutableArray *)array max:(float)max maxIndex:(int)index;
- (int)rightBoundWithGraph:(NSMutableArray *)array max:(float)max maxIndex:(int)index left:(float)leftValue;

@end
