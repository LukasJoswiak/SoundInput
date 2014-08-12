//
//  LPJSoundInputViewController.h
//  SoundInput
//
//  Created by Lukas Joswiak on 7/29/14.
//  Copyright (c) 2014 Lukas Joswiak. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <GLKit/GLKit.h>
#import <Accelerate/Accelerate.h>
#import "EZAudio.h"

@interface LPJSoundInputViewController : UIViewController <AVAudioRecorderDelegate, AVAudioPlayerDelegate, EZMicrophoneDelegate>

@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@property (nonatomic, weak) IBOutlet UIButton *recordPauseButton;
@property (nonatomic, weak) IBOutlet UIButton *stopButton;
@property (nonatomic, weak) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIButton *startTestButton;
@property (weak, nonatomic) IBOutlet UIButton *stopTestButton;

@property (nonatomic) BOOL isRecording;

@property (nonatomic, strong) EZMicrophone *microphone;
@property (nonatomic, weak) IBOutlet EZAudioPlot *audioPlot;

@property (nonatomic, strong) NSMutableArray *bufferData;
@property (nonatomic, strong) NSMutableString *maxData;
@property (nonatomic, strong) NSMutableDictionary *magValues;


- (void)printBuffer;
- (void)saveMaxData;

@end
