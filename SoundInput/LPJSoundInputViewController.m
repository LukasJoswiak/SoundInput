//
//  LPJSoundInputViewController.m
//  SoundInput
//
//  Created by Lukas Joswiak on 7/29/14.
//  Copyright (c) 2014 Lukas Joswiak. All rights reserved.
//

#import "LPJSoundInputViewController.h"

@interface LPJSoundInputViewController () {
    COMPLEX_SPLIT _A;
    FFTSetup      _FFTSetup;
    BOOL          _isFFTSetup;
    vDSP_Length   _log2n;
}

@property (nonatomic, strong) NSString *dataPath;

@end

@implementation LPJSoundInputViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.isRecording = NO;
    self.stopTestButton.enabled = NO;
    
    self.bufferData = [[NSMutableArray alloc] init];
    self.maxData = [[NSMutableString alloc] init];
    self.magValues = [[NSMutableDictionary alloc] init];
    
#if TARGET_IPHONE_SIMULATOR
    self.dataPath = @"/Users/lukasjoswiak/Dropbox/public/data.csv";
#else
    self.dataPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingString:@"/data.csv"];
#endif
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.dataPath]) {
        NSLog(@"Creating file");
        [[NSFileManager defaultManager] createFileAtPath:self.dataPath contents:nil attributes:nil];
    }
    
    // Clear file
    [@" " writeToFile:self.dataPath atomically:NO encoding:NSUTF8StringEncoding error:nil];

    [self.stopButton setEnabled:NO];
    [self.playButton setEnabled:NO];
    
    NSArray *dirPaths;
    NSString *docsDir;
    
    dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    docsDir = dirPaths[0];
    
    NSString *soundFilePath = [docsDir stringByAppendingString:@"/sound.caf"];
        
    NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
    
    NSDictionary *recordSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:AVAudioQualityMedium], AVEncoderAudioQualityKey,
                                    [NSNumber numberWithInt:16], AVEncoderBitRateKey,
                                    [NSNumber numberWithInt:2], AVNumberOfChannelsKey,
                                    [NSNumber numberWithFloat:44100.0], AVSampleRateKey, nil];
    
    NSError *error = nil;
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:soundFileURL settings:recordSettings error:&error];
    
    if (error) {
        NSLog(@"Error: %@", [error localizedDescription]);
    } else {
        [self.audioRecorder prepareToRecord];
    }
    
    self.microphone = [EZMicrophone microphoneWithDelegate:self startsImmediately:YES];
    //[self.microphone startFetchingAudio];
    
    self.audioPlot.backgroundColor = [UIColor colorWithRed:0.4 green:0.349 blue:0.7 alpha:1];
    self.audioPlot.plotType = EZPlotTypeBuffer;
    self.audioPlot.shouldFill = YES;
    self.audioPlot.shouldMirror = YES;
}

- (void)microphone:(EZMicrophone *)microphone hasAudioReceived:(float **)buffer withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels
{
    /*
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.audioPlot updateBuffer:buffer[0] withBufferSize:bufferSize];
    });
     */
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Update time domain plot
        /* [self.audioPlotTime updateBuffer:buffer[0]
                          withBufferSize:bufferSize]; */
        
        // Setup the FFT if it's not already setup
        if ( !_isFFTSetup ){
            [self createFFTWithBufferSize:bufferSize withAudioData:buffer[0]];
            _isFFTSetup = YES;
        }
        
        // Get the FFT data
        // buffer[0] accesses the left channel is system is stereo
        [self updateFFTWithBufferSize:bufferSize withAudioData:buffer[0]];
        
        /*
        if ([self.bufferData count] < 7) {
            [self.bufferData addObject:[NSString stringWithFormat:@"%.6f", *buffer[0]]];
        } else {
            [self printBuffer];
        }
         */
    });
}

- (void)printBuffer
{
    /*
    float max = [[self.bufferData valueForKeyPath:@"@max.floatValue"] floatValue];
    [self.maxData appendString:[NSString stringWithFormat:@"%.6f,", max]];
    //NSLog(@"%.6f", max);
    [self.bufferData removeAllObjects];
     */
}

- (IBAction)recordPauseTapped:(id)sender
{
    if (!self.audioRecorder.recording) {
        [self.playButton setEnabled:NO];
        [self.stopButton setEnabled:YES];
        [self.audioRecorder record];
    }
}

- (IBAction)stopTapped:(id)sender
{
    [self.stopButton setEnabled:NO];
    [self.playButton setEnabled:YES];
    [self.recordPauseButton setEnabled:YES];
    
    if (self.audioRecorder.recording) {
        [self.audioRecorder stop];
    } else if (self.audioPlayer.playing) {
        [self.audioPlayer stop];
    }
}

- (IBAction)playTapped:(id)sender
{
    if (!self.audioRecorder.recording) {
        [self.stopButton setEnabled:YES];
        [self.recordPauseButton setEnabled:NO];
        
        NSError *error;
        
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:self.audioRecorder.url error:&error];
        
        self.audioPlayer.delegate = self;
        
        if (error) {
            NSLog(@"Error: %@", [error localizedDescription]);
        } else {
            [self.audioPlayer setVolume:1.0];
            [self.audioPlayer play];
        }
    }
}

- (IBAction)saveDataTapped:(id)sender
{
    [self saveMaxData];
}

- (IBAction)startTestTapped:(id)sender
{
    self.startTestButton.enabled = NO;
    self.stopTestButton.enabled = YES;
    self.isRecording = YES;
}

- (IBAction)stopTestTapped:(id)sender
{
    self.startTestButton.enabled = YES;
    self.stopTestButton.enabled = NO;
    self.isRecording = NO;
    
    [self saveMaxData];
}

- (void)saveMaxData
{
    NSLog(@"Max data: %@", self.maxData);
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:self.dataPath];
    [handle seekToEndOfFile];
    [handle writeData:[self.maxData dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    NSLog(@"Audio player did finish playing");
    [self.recordPauseButton setEnabled:YES];
    [self.stopButton setEnabled:NO];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    NSLog(@"Decode error occurred");
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    NSLog(@"Finished recording");
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error
{
    NSLog(@"Encode error occurred");
}

#pragma mark - FFT

-(void)createFFTWithBufferSize:(float)bufferSize withAudioData:(float*)data
{
    // Setup the length
    _log2n = log2f(bufferSize);
    
    // Calculate the weights array. This is a one-off operation.
    _FFTSetup = vDSP_create_fftsetup(_log2n, FFT_RADIX2);
    
    // For an FFT, numSamples must be a power of 2, i.e. is always even
    int nOver2 = bufferSize / 2;
    
    // Populate *window with the values for a hamming window function
    float *window = (float *)malloc(sizeof(float)*bufferSize);
    vDSP_hamm_window(window, bufferSize, 0);
    // Window the samples
    vDSP_vmul(data, 1, window, 1, data, 1, bufferSize);
    free(window);
    
    // Define complex buffer
    _A.realp = (float *) malloc(nOver2*sizeof(float));
    _A.imagp = (float *) malloc(nOver2*sizeof(float));
}

-(void)updateFFTWithBufferSize:(float)bufferSize withAudioData:(float*)data
{
    // For an FFT, numSamples must be a power of 2, i.e. is always even
    int nOver2 = bufferSize / 2;
    
    // Pack samples:
    // C(re) -> A[n], C(im) -> A[n+1]
    vDSP_ctoz((COMPLEX*)data, 2, &_A, 1, nOver2);
    
    // Perform a forward FFT using fftSetup and A
    // Results are returned in A
    vDSP_fft_zrip(_FFTSetup, &_A, 1, _log2n, FFT_FORWARD);
    
    // Convert COMPLEX_SPLIT A result to magnitudes
    float amp[nOver2];
    float maxMag = 0;
    float maxFreq = 0;
    
    // Clear data from maxData
    //self.maxData = [[NSMutableString alloc] init];
    [self.magValues removeAllObjects];
    
    for(int i=0; i<nOver2; i++) {
        // Calculate the magnitude
        float mag = _A.realp[i]*_A.realp[i]+_A.imagp[i]*_A.imagp[i];
        //maxMag = mag > maxMag ? mag : maxMag;
        
        if (mag > maxMag) {
            //NSLog(@"Max freq: %d", i);
            maxMag = mag;
            maxFreq = i;
        }
        
        //[self.maxData appendString:[NSString stringWithFormat:@"%.6f,", maxMag]];
        //[self.maxData setString:[NSString stringWithFormat:@"%.6f", maxMag]];
        //[self.magValues setValue:[NSString stringWithFormat:@"%.6f", maxMag] forKeyPath:[NSString stringWithFormat:@"%d", i]];
        //[self.maxData appendString:[NSString stringWithFormat:@"%.6f,", mag]];
        
        //NSLog(@"%.6f", mag);
        //if (maxMag > 100) {
        //    [self.maxData appendString:[NSString stringWithFormat:@"%d,", i]];
        //}
    }
    
    if (self.isRecording) {
        NSLog(@"Max freq: %f", maxFreq);
        [self.maxData appendString:[NSString stringWithFormat:@"%.2f,", maxFreq * (22050 / 256)]];
    }
        
    for(int i=0; i<nOver2; i++) {
        // Calculate the magnitude
        float mag = _A.realp[i]*_A.realp[i]+_A.imagp[i]*_A.imagp[i];
        // Bind the value to be less than 1.0 to fit in the graph
        amp[i] = [EZAudio MAP:mag leftMin:0.0 leftMax:maxMag rightMin:0.0 rightMax:1.0];
        
    }
    
    //[self.maxData appendString:[NSString stringWithFormat:@"%.6f,", *amp]];
    //self.maxData = [NSString stringWithFormat:@"%.6f", *amp];
    
    // Update the frequency domain plot
    [self.audioPlot updateBuffer:amp
                      withBufferSize:nOver2];
}

@end
