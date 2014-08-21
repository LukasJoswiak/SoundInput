//
//  LPJTimer.h
//  SoundInput
//
//  Created by Lukas Joswiak on 8/19/14.
//  Copyright (c) 2014 Lukas Joswiak. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LPJTimer : NSObject
{
    NSDate *start;
    NSDate *end;
}

- (void)startTimer;
- (void)stopTimer;
- (double)timeElapsedInSeconds;
- (double)timeElapsedInMilliseconds;

@end
