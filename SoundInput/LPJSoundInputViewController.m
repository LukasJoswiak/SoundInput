//
//  LPJSoundInputViewController.m
//  SoundInput
//
//  Created by Lukas Joswiak on 7/29/14.
//  Copyright (c) 2014 Lukas Joswiak. All rights reserved.
//

#import "LPJSoundInputViewController.h"
#import "LPJTimer.h"
#import "LPJSoundAnalysis.h"

@interface LPJSoundInputViewController () {
    COMPLEX_SPLIT _A;
    FFTSetup      _FFTSetup;
    BOOL          _isFFTSetup;
    vDSP_Length   _log2n;
}

@property (nonatomic, strong) NSString *dataPath;
@property (nonatomic) BOOL isPhone;
@property (nonatomic) int counter;
@property (nonatomic, strong) NSString *soundFilePath;
@property (nonatomic, strong) NSURL *soundFileURL;
@property (nonatomic) BOOL eof;

@property (nonatomic, strong) LPJTimer *timer;

@property (nonatomic, strong) DBAccount *account;
@property (nonatomic, strong) DBFilesystem *filesystem;

@property (nonatomic, strong) LPJSoundAnalysis *soundAnalysis;

@end

@implementation LPJSoundInputViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.soundAnalysis = [[LPJSoundAnalysis alloc] init];
    
    self.timer = [[LPJTimer alloc] init];
    self.timeLabel.text = @"";

    self.counter = 0;
    
    self.isRecording = NO;
    self.stopTestButton.enabled = NO;
    
    self.bufferData = [[NSMutableArray alloc] init];
    self.maxData = [[NSMutableString alloc] init];
    self.magValues = [[NSMutableDictionary alloc] init];
    self.maxDataArray = [[NSMutableArray alloc] init];
    
    [self.webView loadRequest:[[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://lukasjoswiak.com/dropbox/"]]];
    
#if TARGET_IPHONE_SIMULATOR
    self.dataPath = @"/Users/lukasjoswiak/Dropbox/Apps/RealTimeGraph/data.csv";
    self.isPhone = NO;
#else
    self.dataPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingString:@"/data.csv"];
    self.isPhone = YES;
#endif
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.dataPath]) {
        NSLog(@"Creating file");
        [[NSFileManager defaultManager] createFileAtPath:self.dataPath contents:nil attributes:nil];
    }

    [self.stopButton setEnabled:NO];
    [self.playButton setEnabled:NO];
    
    NSArray *dirPaths;
    NSString *docsDir;
    
    dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    docsDir = dirPaths[0];
    
    self.soundFilePath = [docsDir stringByAppendingString:@"/sound.caf"];
    
    self.soundFileURL = [NSURL fileURLWithPath:self.soundFilePath];
    
    NSDictionary *recordSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:AVAudioQualityMedium], AVEncoderAudioQualityKey,
                                    [NSNumber numberWithInt:16], AVEncoderBitRateKey,
                                    [NSNumber numberWithInt:2], AVNumberOfChannelsKey,
                                    [NSNumber numberWithFloat:44100.0], AVSampleRateKey, nil];
    
    NSError *error = nil;
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:self.soundFileURL settings:recordSettings error:&error];
    
    if (error) {
        NSLog(@"Error: %@", [error localizedDescription]);
    } else {
        //[self.audioRecorder prepareToRecord];
    }
    
    self.microphone = [EZMicrophone microphoneWithDelegate:self startsImmediately:YES];
    
    self.audioPlot.backgroundColor = [UIColor colorWithRed:0.4 green:0.349 blue:0.7 alpha:1];
    self.audioPlot.plotType = EZPlotTypeBuffer;
    self.audioPlot.shouldFill = YES;
    self.audioPlot.shouldMirror = YES;

    [self openFilePathWithFileURL:self.soundFileURL];
}

// Called when microphone is receiving audio
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
        if (!_isFFTSetup){
            [self createFFTWithBufferSize:bufferSize withAudioData:buffer[0]];
            _isFFTSetup = YES;
        }
        
        // Get the FFT data
        // buffer[0] accesses the left channel is system is stereo
        [self updateFFTWithBufferSize:bufferSize withAudioData:buffer[0]];
    });
}

- (void)openFilePathWithFileURL:(NSURL *)url
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.soundFilePath]) {
        self.playRecordingButton.enabled = NO;
        return;
    }
    
    // Stop playback
    [[EZOutput sharedOutput] stopPlayback];
    
    self.audioFile = [EZAudioFile audioFileWithURL:url];
    self.audioFile.audioFileDelegate = self;
    self.eof = NO;
    
    // Set the client format from the EZAudioFile on the output
    [[EZOutput sharedOutput] setAudioStreamBasicDescription:self.audioFile.clientFormat];
    
    // Plot the whole waveform
    self.audioPlot.plotType = EZPlotTypeBuffer;
    self.audioPlot.shouldFill = YES;
    self.audioPlot.shouldMirror = YES;
    NSLog(@"Seconds: %.2f", self.audioFile.totalDuration);
    [self.audioFile getWaveformDataWithCompletionBlock:^(float *waveformData, UInt32 length) {
        [self.audioPlot updateBuffer:waveformData withBufferSize:length];
    }];
}

// EZAudioFileDelegate
- (void)audioFile:(EZAudioFile *)audioFile readAudio:(float **)buffer withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.audioPlot updateBuffer:buffer[0] withBufferSize:bufferSize];
    });
}


// EZOutputDataSource
- (void)output:(EZOutput *)output shouldFillAudioBufferList:(AudioBufferList *)audioBufferList withNumberOfFrames:(UInt32)frames
{
    if (self.audioFile) {
        UInt32 bufferSize;
        [self.audioFile readFrames:frames audioBufferList:audioBufferList bufferSize:&bufferSize eof:&_eof];
        
        if (_eof) {
            [[EZOutput sharedOutput] stopPlayback];
            [self.playRecordingButton setTitle:@"Play Recording" forState:UIControlStateNormal];
            [self.audioFile seekToFrame:0];
            
            [self saveMaxData];
        }
    }
}

- (IBAction)didPressLink:(id)sender
{
    [[DBAccountManager sharedManager] linkFromController:self];
}

- (IBAction)reloadTapped:(id)sender
{
    [self.webView reload];
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

- (IBAction)startTestTapped:(id)sender
{
    [self.timer startTimer];
    
    if (!self.audioRecorder.recording) {
        [self.audioRecorder record];
    }
    
    self.startTestButton.enabled = NO;
    self.stopTestButton.enabled = YES;
    self.isRecording = YES;
}

- (IBAction)stopTestTapped:(id)sender
{
    self.startTestButton.enabled = YES;
    self.stopTestButton.enabled = NO;
    self.isRecording = NO;
    [self.timer stopTimer];
    [self.audioRecorder stop];
    
    self.timeLabel.text = [NSString stringWithFormat:@"%f sec", [self.timer timeElapsedInSeconds]];
    
    [self saveMaxData];
}

- (IBAction)toggleRecordingTapped:(id)sender
{
    if ([[EZOutput sharedOutput] isPlaying]) {
        [sender setTitle:@"Play Recording" forState:UIControlStateNormal];
        [EZOutput sharedOutput].outputDataSource = nil;
        [[EZOutput sharedOutput] stopPlayback];
        
        [self saveMaxData];
    } else {
        [sender setTitle:@"Stop Recording" forState:UIControlStateNormal];
        [EZOutput sharedOutput].outputDataSource = self;
        [[EZOutput sharedOutput] startPlayback];
    }
}

- (NSMutableArray *)movingAverage:(int)iterations
{
    NSUInteger count = 0;
    NSMutableArray *temp = [NSMutableArray array];
    for (int j = 0; j < [self.maxDataArray count]; j++) {
        float sum = 0;
        for (int i = 0; i < iterations; i++) {
            if ([self.maxDataArray count] > count + i) {
                sum += [self.maxDataArray[count + i] floatValue];
            }
        }
        float average = sum / iterations;
        [temp addObject:[NSNumber numberWithFloat:average]];
        
        count++;
    }
    
    return temp;
}

- (void)saveMaxData
{
    int iterations = 15;
    
    // Take moving average twice for smooth curve
    self.maxDataArray = [self movingAverage:iterations];
    //self.maxDataArray = [self movingAverage:5];
    
    NSUInteger count = 0;
    
    float max = 0;
    int maxIndex = 0;
    for (NSNumber *f in self.maxDataArray) {
        if ([f floatValue] > max) {
            max = [f floatValue];
            maxIndex = count;
        }
        count++;
    }
    
    // Get index where slope stops increasing left of max
    NSArray *left = [self.soundAnalysis leftBoundWithGraph:self.maxDataArray max:max maxIndex:maxIndex];
    int leftBound = [left[0] floatValue];
    float leftValue = [left[1] floatValue];
    
    // Get index where slope stops decreasing right of max
    int rightBound = [self.soundAnalysis rightBoundWithGraph:self.maxDataArray max:max maxIndex:maxIndex left:leftValue];
    
    // *** Writes to string with moving average of all values using x iterations defined above
    // *** Use roller on bottom left of graph to test different moving averages. Change iterations above when happy and uncomment this to permanently change moving average.
    
    count = 0;
    // float sum = 0;
    //[self.maxData setString:@""];
    NSMutableString *timeVolumeData = [[NSMutableString alloc] init];
    for (NSNumber *f in self.maxDataArray) {
        if (count >= leftBound && count <= rightBound) {
            /*** Time vs Flow ***/
            [timeVolumeData appendString:[NSString stringWithFormat:@"%d,%.2f\n", count, [f floatValue]]];
            
            /*** Time vs Volume ***/
            // sum += [f floatValue];
            // [self.maxData appendString:[NSString stringWithFormat:@"%d,%.2f\n", count, sum]];
        }
        
        count++;
    }
    
    // ** End rewrite
    
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:self.dataPath];
    //[handle seekToEndOfFile];
    [handle truncateFileAtOffset:0];
    
    if (self.isPhone) {
        if (!self.account) {
            self.account = [[DBAccountManager sharedManager] linkedAccount];
            
            self.filesystem = [[DBFilesystem alloc] initWithAccount:self.account];
            [DBFilesystem setSharedFilesystem:self.filesystem];
        }
        
        DBPath *path = [[DBPath root] childPath:@"data.csv"];
        DBFileInfo *info = [[DBFilesystem sharedFilesystem] fileInfoForPath:path error:nil];
        
        DBPath *path2 = [[DBPath root] childPath:@"data2.csv"]; // time volume data
        DBFileInfo *info2 = [[DBFilesystem sharedFilesystem] fileInfoForPath:path2 error:nil];
        
        DBPath *soundPath = [[DBPath root] childPath:@"sound.caf"];
        DBFileInfo *soundInfo = [[DBFilesystem sharedFilesystem] fileInfoForPath:soundPath error:nil];
        
        NSLog(@"Writing to Dropbox. Info: %@, info2: %@", info, info2);
        if (!info) {
            DBFile *file = [[DBFilesystem sharedFilesystem] createFile:path error:nil];
            [file writeString:self.maxData error:nil];
        } else {
            DBFile *file = [[DBFilesystem sharedFilesystem] openFile:path error:nil];
            [file writeString:self.maxData error:nil];
        }
        
        if (!info2) {
            DBFile *file2 = [[DBFilesystem sharedFilesystem] createFile:path2 error:nil];
            [file2 writeString:timeVolumeData error:nil];
        } else {
            DBFile *file2 = [[DBFilesystem sharedFilesystem] openFile:path2 error:nil];
            [file2 writeString:timeVolumeData error:nil];
        }
        
        if (!soundInfo) {
            DBFile *soundFile = [[DBFilesystem sharedFilesystem] createFile:soundPath error:nil];
            [soundFile writeData:[NSData dataWithContentsOfURL:self.soundFileURL] error:nil];
        } else {
            DBFile *soundFile = [[DBFilesystem sharedFilesystem] openFile:soundPath error:nil];
            [soundFile writeData:[NSData dataWithContentsOfURL:self.soundFileURL] error:nil];
        }
    } else {
        [handle writeData:[self.maxData dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [handle closeFile];
    
    self.counter = 0;
    [self.maxData setString:@""];
    [self.maxDataArray removeAllObjects];
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
    
    if (self.isRecording || [[EZOutput sharedOutput] isPlaying]) {
        //NSLog(@"Max freq: %f", maxFreq);
        float hertz = maxFreq * (22050 / 256);
        [self.maxData appendString:[NSString stringWithFormat:@"%d,%.2f\n", self.counter, hertz]];
        [self.maxDataArray addObject:[NSNumber numberWithFloat:hertz]];
        self.counter++;
    }
        
    for(int i=0; i<nOver2; i++) {
        // Calculate the magnitude
        float mag = _A.realp[i]*_A.realp[i]+_A.imagp[i]*_A.imagp[i];
        // Bind the value to be less than 1.0 to fit in the graph
        amp[i] = [EZAudio MAP:mag leftMin:0.0 leftMax:maxMag rightMin:0.0 rightMax:1.0];
        
    }
    
    //[self.maxData appendString:[NSString stringWithFormat:@"%.6f,", *amp]];
    //self.maxData = [NSString stringWithFormat:@"%.6f", *amp];
    
    // Update the frequency domain plot if microphone is active device, otherwise plot update is handled in audioFile:readAudio:withBufferSize:withNumberOfChannels: (for playback of recorded audio)
    if (self.isRecording) {
        [self.audioPlot updateBuffer:amp withBufferSize:nOver2];
    }
}

@end
