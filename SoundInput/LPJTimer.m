//
//  LPJTimer.m
//  SoundInput
//
//  Created by Lukas Joswiak on 8/19/14.
//  Copyright (c) 2014 Lukas Joswiak. All rights reserved.
//

#import "LPJTimer.h"

@implementation LPJTimer

- (instancetype)init {
    self = [super init];
    
    if (self) {
        start = nil;
        end = nil;
    }
    
    return self;
}

- (void)startTimer
{
    start = [NSDate date];
}

- (void)stopTimer
{
    end = [NSDate date];
}

- (double)timeElapsedInSeconds
{
    return [end timeIntervalSinceDate:start];
}

- (double)timeElapsedInMilliseconds
{
    return [self timeElapsedInSeconds] * 1000.0f;
}

@end
