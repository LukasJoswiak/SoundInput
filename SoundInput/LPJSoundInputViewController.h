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
#import <Dropbox/Dropbox.h>

@interface LPJSoundInputViewController : UIViewController <AVAudioRecorderDelegate, AVAudioPlayerDelegate, EZMicrophoneDelegate, EZAudioFileDelegate, EZOutputDataSource>

@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@property (nonatomic, strong) EZAudioFile *audioFile;

@property (nonatomic, weak) IBOutlet UIWebView *webView;

@property (nonatomic, weak) IBOutlet UIButton *recordPauseButton;
@property (nonatomic, weak) IBOutlet UIButton *stopButton;
@property (nonatomic, weak) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIButton *startTestButton;
@property (weak, nonatomic) IBOutlet UIButton *stopTestButton;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UIButton *playRecordingButton;

@property (nonatomic) BOOL isRecording;

@property (nonatomic, strong) EZMicrophone *microphone;
@property (nonatomic, weak) IBOutlet EZAudioPlot *audioPlot;

@property (nonatomic, strong) NSMutableArray *bufferData;
@property (nonatomic, strong) NSMutableString *maxData;
@property (nonatomic, strong) NSMutableDictionary *magValues;
@property (nonatomic, strong) NSMutableArray *maxDataArray;

@property (nonatomic) float FEV1;
@property (nonatomic) float PEF;
@property (nonatomic) float FVC;
@property (nonatomic) float ratio;

- (void)saveMaxData;
- (NSMutableArray *)movingAverage:(NSArray *)array times:(int)iterations;
- (void)openFilePathWithFileURL:(NSURL *)url;

- (void)saveFFTData:(float *)data withBufferSize:(int)bufferSize;

@end
