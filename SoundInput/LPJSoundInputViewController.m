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

/*
@property (nonatomic) float lastdbValue;
@property (nonatomic) int fftBufIndex;
@property (nonatomic) float *fftBuf;
@property (nonatomic) int samplesRemaining;
 */

// #define FFTLEN 256

@end

@implementation LPJSoundInputViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // _fftBuf = (float *)malloc(FFTLEN * sizeof(float));
    // self.lastdbValue = 0.0;
    
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
    
    self.FEV1 = 0; // Forced Expiratory Volume in 1 second (Hertz)
    self.PEF = 0; // Peak Expiratory Flow (Hertz/sec)
    self.FVC = 0; // Forced Vital Capacity (Hertz)
    self.ratio = 0; // FEV1 / FVC
    
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
                                    [NSNumber numberWithFloat:44100], AVSampleRateKey, nil];
    
    NSError *error = nil;
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    
    /*
    NSTimeInterval preferredBufferDuration = 0.0005;
    NSError *err;
    [audioSession setPreferredIOBufferDuration:preferredBufferDuration error:&err];
    NSLog(@"Err: %@", err);
    NSLog(@"Preferred IO Buffer Duration: %f. Actual duration: %f", [audioSession preferredIOBufferDuration], [audioSession IOBufferDuration]);
    
    //[audioSession setPreferredSampleRate:8000.0 error:nil];
    NSLog(@"Sample rate: %f", [audioSession sampleRate]);
    */
        
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:self.soundFileURL settings:recordSettings error:&error];
    
    if (error) {
        NSLog(@"Error: %@", [error localizedDescription]);
    } else {
        //[self.audioRecorder prepareToRecord];
    }
    
    self.microphone = [EZMicrophone microphoneWithDelegate:self startsImmediately:NO];
    
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
        
        /*
        // Decibel Calculation.
        float one       = 1.0;
        float meanVal   = 0.0;
        float tiny      = 0.1;
        vDSP_vsq(buffer[0], 1, buffer[0], 1, bufferSize);
        vDSP_meanv(buffer[0], 1, &meanVal, bufferSize);
        vDSP_vdbcon(&meanVal, 1, &one, &meanVal, 1, 1, 0);
        // Exponential moving average to dB level to only get continous sounds.
        float currentdb = 1.0 - (fabs(meanVal)/100);
        if (self.lastdbValue == INFINITY || self.lastdbValue == -INFINITY || isnan(self.lastdbValue)) {
            self.lastdbValue = 0.0;
        }
        float dbValue =   ((1.0 - tiny)*self.lastdbValue) + tiny*currentdb;
        self.lastdbValue = dbValue;
        NSLog(@"dbval:  %f",dbValue);
        */
        
        /*
        // Setup the FFT if it's not already setup
        int samplestoCopy = fmin(bufferSize, FFTLEN - _fftBufIndex);
        for ( size_t i = 0; i < samplestoCopy; i++ ) {
            _fftBuf[_fftBufIndex+i] = buffer[0][i];
            // NSLog(@"Buffer: %f", buffer[0][i]);
        }
        _fftBufIndex        += samplestoCopy;
        _samplesRemaining    -= samplestoCopy;
        if (_fftBufIndex == FFTLEN) {
            if( !_isFFTSetup ){
                [self createFFTWithBufferSize:FFTLEN withAudioData:_fftBuf];
                _isFFTSetup = YES;
            }
            [self updateFFTWithBufferSize:FFTLEN withAudioData:_fftBuf];
            _fftBufIndex        = 0;
            _samplesRemaining   = FFTLEN;
        }
         */
        
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
    /*[self.audioFile getWaveformDataWithCompletionBlock:^(float *waveformData, UInt32 length) {
        [self.audioPlot updateBuffer:waveformData withBufferSize:length];
    }];*/
}

// EZAudioFileDelegate
- (void)audioFile:(EZAudioFile *)audioFile readAudio:(float **)buffer withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.audioPlot updateBuffer:buffer[0] withBufferSize:bufferSize];
        
        // Setup the FFT if it's not already setup
        if (!_isFFTSetup){
            [self createFFTWithBufferSize:bufferSize withAudioData:buffer[0]];
            _isFFTSetup = YES;
        }
        
        // Get the FFT data
        // buffer[0] accesses the left channel is system is stereo
        [self updateFFTWithBufferSize:bufferSize withAudioData:buffer[0]];
        
        /*
        // Setup the FFT if it's not already setup
        int samplestoCopy = fmin(bufferSize, FFTLEN - _fftBufIndex);
        for ( size_t i = 0; i < samplestoCopy; i++ ) {
            _fftBuf[_fftBufIndex+i] = buffer[0][i];
        }
        _fftBufIndex        += samplestoCopy;
        _samplesRemaining    -= samplestoCopy;
        if (_fftBufIndex == FFTLEN) {
            if( !_isFFTSetup ){
                [self createFFTWithBufferSize:FFTLEN withAudioData:_fftBuf];
                _isFFTSetup = YES;
            }
            [self updateFFTWithBufferSize:FFTLEN withAudioData:_fftBuf];
            _fftBufIndex        = 0;
            _samplesRemaining   = FFTLEN;
        }
         */
    });
}


// EZOutputDataSource
- (void)output:(EZOutput *)output shouldFillAudioBufferList:(AudioBufferList *)audioBufferList withNumberOfFrames:(UInt32)frames
{
    if (self.audioFile) {
        UInt32 bufferSize;
        [self.audioFile readFrames:frames audioBufferList:audioBufferList bufferSize:&bufferSize eof:&_eof];
        
        if (_eof) {
            [self.playRecordingButton sendActionsForControlEvents:UIControlEventTouchUpInside];
            [self.audioFile seekToFrame:0];
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
    self.microphone.microphoneOn = YES;
    [self.timer startTimer];
    [self.audioRecorder prepareToRecord];
    
    if (!self.audioRecorder.recording) {
        [self.audioRecorder record];
    }
    
    self.startTestButton.enabled = NO;
    self.stopTestButton.enabled = YES;
    self.isRecording = YES;
    
    // Run test for 3 seconds to test number of loops
    // [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(stopTestTapped:) userInfo:nil repeats:NO];
}

- (IBAction)stopTestTapped:(id)sender
{
    self.microphone.microphoneOn = NO;
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
        [self.timer stopTimer];
        
        self.timeLabel.text = [NSString stringWithFormat:@"%f sec", [self.timer timeElapsedInSeconds]];
        
        [self saveMaxData];
    } else {
        [sender setTitle:@"Stop Recording" forState:UIControlStateNormal];
        [EZOutput sharedOutput].outputDataSource = self;
        [[EZOutput sharedOutput] startPlayback];
        [self.timer startTimer];
    }
}

- (NSMutableArray *)movingAverage:(NSArray *)array times:(int)iterations
{
    NSUInteger count = 0;
    NSMutableArray *temp = [NSMutableArray array];
    for (int j = 0; j < [array count]; j++) {
        float sum = 0;
        for (int i = 0; i < iterations; i++) {
            if ([array count] > count + i) {
                sum += [array[count + i] floatValue];
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
    float intervalLengthInSeconds = [self.timer timeElapsedInSeconds] / [self.maxDataArray count];
    int oneSecondCount = 1 / intervalLengthInSeconds;
    NSLog(@"There were %d intervals\nEach interval is %f seconds.\n1 second took %d intervals.", [self.maxDataArray count], intervalLengthInSeconds, oneSecondCount);
    
    int iterations = 15;
    
    // Take moving average twice for smooth curve
    self.maxDataArray = [self movingAverage:self.maxDataArray times:iterations];
    // self.maxDataArray = [self movingAverage:self.maxDataArray times:5];
    
    NSUInteger count = 0;
    
    // Find the maximum value in the dataset
    float max = 0;
    int maxIndex = 0;
    for (NSNumber *f in self.maxDataArray) {
        if ([f floatValue] > max) {
            max = [f floatValue];
            maxIndex = (float)count;
        }
        count++;
    }
    
    // Get index where slope stops increasing left of max
    NSArray *left = [self.soundAnalysis leftBoundWithGraph:self.maxDataArray max:max maxIndex:maxIndex];
    int leftBound = [left[0] floatValue];
    float leftValue = [left[1] floatValue];
    float leftMinSlope = [left[2] floatValue]; // slope of first two data points, used to calculate slope of line to connect to zero Hz
    
    NSLog(@"One second count: %d, left bound: %d", oneSecondCount, leftBound);
    oneSecondCount += leftBound; // Interval after one second has passed
    
    // Get index where slope stops decreasing right of max
    NSArray *right = [self.soundAnalysis rightBoundWithGraph:self.maxDataArray max:max maxIndex:maxIndex left:leftValue];
    int rightBound = [right[0] floatValue];
    // int rightBound = (int)[self.maxDataArray count];
    float rightMinSlope = [right[1] floatValue];
    
    NSLog(@"Right min slope: %f", rightMinSlope);
    
    NSLog(@"There are %d intervals\nTotal length: %f seconds", rightBound - leftBound, intervalLengthInSeconds * (rightBound - leftBound));
    
    NSLog(@"\nLeft Bound: %d\nRight Bound: %d", leftBound, rightBound);
    
    // Get average noise level before test begins
    count = 0;
    float sum = 0;
    for (NSNumber *f in self.maxDataArray) {
        if (count < leftBound) {
            sum += [f floatValue];
            count++;
        } else {
            break;
        }
    }
    
    float average = sum / count;
    
    //NSLog(@"Average Hz before test begins: %f Hz", average);
    
    // Reset FVC
    self.FVC = 0;
    
    // *** Writes to string with moving average of all values using x iterations defined above
    // *** Use roller on bottom left of graph to test different moving averages. Change iterations above when happy and uncomment this to permanently change moving average.
    
    BOOL straightLine = NO;
    count = 0;
    sum = 0;
    float maxFlow = 0;
    //[self.maxData setString:@""];
    NSMutableString *averagedData = [[NSMutableString alloc] init];
    NSMutableString *timeVolumeData = [[NSMutableString alloc] init];
    NSMutableString *volumeFlowData =[[NSMutableString alloc] init];
    for (NSNumber *f in self.maxDataArray) {
        if (count >= leftBound && count <= rightBound) {
            float floatValueAppend = [f floatValue];
            
            if (count > maxIndex && floatValueAppend < average) {
                straightLine = YES;
            }
            
            if (straightLine) {
                //floatValueAppend = average;
            }
            
            [averagedData appendString:[NSString stringWithFormat:@"%lu,%.2f\n", (unsigned long)count, floatValueAppend]];
            
            /*** Time vs Flow (what?? wrong var name) ***/
            //[timeVolumeData appendString:[NSString stringWithFormat:@"%d,%.2f\n", count, [f floatValue]]];
            
            /*** Time vs Volume ***/
            sum += floatValueAppend; // Volume
            [timeVolumeData appendString:[NSString stringWithFormat:@"%lu,%.2f\n", (unsigned long)count, sum]];
            
            if (count == oneSecondCount) {
                self.FEV1 = sum;
            }
            
            /*** Volume vs Flow ***/
            [volumeFlowData appendString:[NSString stringWithFormat:@"%.2f,%.2f\n", sum, floatValueAppend]];
            
            if (floatValueAppend > maxFlow) {
                maxFlow = floatValueAppend;
            }
            
            self.FVC += floatValueAppend;
        }
        
        count++;
    }
    
    float increase = 1;
    int pos = leftBound;
    float leftPoint = [self.maxDataArray[leftBound] floatValue];
    NSLog(@"Left bound: %d\nLeft point: %f", leftBound, leftPoint);
    for (float i = leftPoint; i >= 0; i -= leftMinSlope) {
        NSLog(@"I: %f\nPos: %d", i, pos);
        [averagedData insertString:[NSString stringWithFormat:@"%d,%.6f\n", pos, i * increase] atIndex:0];
        leftBound = pos;
        pos--;
        increase += 0.02; // slightly concave down instead of linear
    }
    NSLog(@"New left bound: %d", leftBound);
    
    increase = 1;
    pos = rightBound;
    float rightPoint = [self.maxDataArray[rightBound] floatValue];
    NSLog(@"Right point: %f\nRight min slope: %f", rightPoint, rightMinSlope);
    for (float i = rightPoint; i >= 0; i -= rightMinSlope) {
        NSLog(@"I: %f\nPos: %d", i, pos);
        [averagedData appendString:[NSString stringWithFormat:@"%d,%.6f\n", pos, i * increase]];
        rightBound = pos;
        pos++;
        increase -= 0.01; // slightly concave up instead of linear
    }
    
    // ** End rewrite
    
    self.PEF = maxFlow;
    self.ratio = self.FEV1 / self.FVC;
    
    //NSLog(@"One second; interval %d", oneSecondCount);
    //NSLog(@"FEV1: %f Hz\nPEF: %f Hz\nFVC: %f Hz\nFEV1 / FVC: %f", self.FEV1, self.PEF, self.FVC, self.ratio);
    
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:self.dataPath];
    [handle truncateFileAtOffset:0];
    
    if (self.isPhone) {
        if (!self.account) {
            self.account = [[DBAccountManager sharedManager] linkedAccount];
            
            self.filesystem = [[DBFilesystem alloc] initWithAccount:self.account];
            [DBFilesystem setSharedFilesystem:self.filesystem];
        }
        
        DBPath *path = [[DBPath root] childPath:@"data.csv"];
        DBFileInfo *info = [[DBFilesystem sharedFilesystem] fileInfoForPath:path error:nil];
        
        DBPath *timeVolumePath = [[DBPath root] childPath:@"timeVolume.csv"]; // time volume data
        DBFileInfo *timeVolumeInfo = [[DBFilesystem sharedFilesystem] fileInfoForPath:timeVolumePath error:nil];
        
        DBPath *volumeFlowPath = [[DBPath root] childPath:@"volumeFlow.csv"]; // flow volume data
        DBFileInfo *volumeFlowInfo = [[DBFilesystem sharedFilesystem] fileInfoForPath:volumeFlowPath error:nil];
        
        DBPath *soundPath = [[DBPath root] childPath:@"sound.caf"];
        DBFileInfo *soundInfo = [[DBFilesystem sharedFilesystem] fileInfoForPath:soundPath error:nil];
        
        if (!info) {
            DBFile *file = [[DBFilesystem sharedFilesystem] createFile:path error:nil];
            [file writeString:averagedData error:nil];
        } else {
            DBFile *file = [[DBFilesystem sharedFilesystem] openFile:path error:nil];
            [file writeString:averagedData error:nil];
        }
        
        if (!timeVolumeInfo) {
            DBFile *timeVolumeFile = [[DBFilesystem sharedFilesystem] createFile:timeVolumePath error:nil];
            [timeVolumeFile writeString:timeVolumeData error:nil];
        } else {
            DBFile *timeVolumeFile = [[DBFilesystem sharedFilesystem] openFile:timeVolumePath error:nil];
            [timeVolumeFile writeString:timeVolumeData error:nil];
        }
        
        if (!volumeFlowInfo) {
            DBFile *volumeFlowFile = [[DBFilesystem sharedFilesystem] createFile:volumeFlowPath error:nil];
            [volumeFlowFile writeString:volumeFlowData error:nil];
        } else {
            DBFile *volumeFlowFile = [[DBFilesystem sharedFilesystem] openFile:volumeFlowPath error:nil];
            [volumeFlowFile writeString:volumeFlowData error:nil];
        }
        
        if (!soundInfo) {
            DBFile *soundFile = [[DBFilesystem sharedFilesystem] createFile:soundPath error:nil];
            [soundFile writeData:[NSData dataWithContentsOfURL:self.soundFileURL] error:nil];
        } else {
            DBFile *soundFile = [[DBFilesystem sharedFilesystem] openFile:soundPath error:nil];
            [soundFile writeData:[NSData dataWithContentsOfURL:self.soundFileURL] error:nil];
        }
    } else {
        [handle writeData:[averagedData dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [handle closeFile];
    
    self.counter = 0;
    [self.maxData setString:@""];
    [self.maxDataArray removeAllObjects];
}

#pragma mark - FFT
-(void)createFFTWithBufferSize:(float)bufferSize withAudioData:(float*)data
{
    NSLog(@"Received buffer size: %f", bufferSize);
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
    //NSLog(@"Buffer size: %f", bufferSize);
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
    
    //[self saveFFTData:amp withBufferSize:nOver2];
    
    for (int i=0; i<nOver2; i++) {
        // Calculate the magnitude
        float mag = _A.realp[i]*_A.realp[i]+_A.imagp[i]*_A.imagp[i];
        // Bind the value to be less than 1.0 to fit in the graph
        amp[i] = [EZAudio MAP:mag leftMin:0.0 leftMax:maxMag rightMin:0.0 rightMax:1.0];
    }
     
    //[self.maxData appendString:[NSString stringWithFormat:@"%.6f,", *amp]];
    //self.maxData = [NSString stringWithFormat:@"%.6f", *amp];
    
    /*
    for (int i = 0; i < sizeof(amp); i++) {
        [self.maxData appendString:[NSString stringWithFormat:@"%d,%f\n", self.counter, amp[i]]];
        [self.maxDataArray addObject:[NSNumber numberWithFloat:amp[i]]];
        self.counter++;
    }
     */
    
    // Update the frequency domain plot if microphone is active device, otherwise plot update is handled in audioFile:readAudio:withBufferSize:withNumberOfChannels: (for playback of recorded audio)
    //if (self.isRecording || [[EZOutput sharedOutput] isPlaying]) {
        [self.audioPlot updateBuffer:amp withBufferSize:nOver2];
    //}
    
    //[self saveFFTData:amp withBufferSize:nOver2];
}

int abc = 0;

- (void)saveFFTData:(float *)data withBufferSize:(int)bufferSize
{
    NSLog(@"New loop: %d", abc);
    abc++;
    for (int i = 0; i < bufferSize; i++) {
        //NSLog(@"I: %d, Data: %f", i, data[i]);
        data[i] = i == 0 ? 0 : data[i];
        [self.maxData appendString:[NSString stringWithFormat:@"%d,%f\n", self.counter, data[i]]];
        [self.maxDataArray addObject:[NSNumber numberWithFloat:data[i]]];
        self.counter++;
    }
}

@end
