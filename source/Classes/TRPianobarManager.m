//
//  TRPianobarManager.m
//  Transistor
//
//  Created by Zach Waugh on 2/13/11.
//  Copyright 2011 Giant Comet. All rights reserved.
//

#import "TRPianobarManager.h"

static TRPianobarManager *sharedPianobarManager = nil;

@interface TRPianobarManager ()

- (void)parseEventInfo:(NSString *)info;
- (void)processOutput:(NSString *)output;
- (void)handleSongStartEvent:(NSNotification *)notification;

@end


@implementation TRPianobarManager

@synthesize currentArtist, currentSong, currentAlbum, currentTime, currentArtworkURL;

- (id)init
{
  if ((self = [super init]))
  {
    // Notification data available from stdout
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outputAvailable:) name:NSFileHandleReadCompletionNotification object:nil];
    
    // Notification for data from TransistorHelper via pianobar event_command
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSongStartEvent:) name:@"TransistorSongStartEventNotification" object:nil];	
    
    // Info about current song
    currentArtist = @"";
    currentSong = @"";
    currentAlbum = @"";
    currentTime = @"";
    
    // Basic plumbing for communicating with the pianobar process
    outputPipe = [[NSPipe pipe] retain];
    inputPipe = [[NSPipe pipe] retain];
    readHandle = [outputPipe fileHandleForReading];
    writeHandle = [inputPipe fileHandleForWriting];
    
    pianobar = [[NSTask alloc] init];
    
    // TODO: make path customizable
    [pianobar setLaunchPath:@"/usr/local/bin/pianobar"];
    [pianobar setStandardOutput:outputPipe];
    [pianobar setStandardInput:inputPipe];
    [pianobar setStandardError:outputPipe];
    
    // get data asynchronously and notify when available
    [readHandle readInBackgroundAndNotify];
    
    [pianobar launch];
  }
  
  return self;
}


// Quit pianobar process
- (void)quit
{
  NSLog(@"quitting pianobar");
  
  if ([pianobar isRunning])
  {
    [self sendCommand:QUIT];
    [pianobar terminate];
  }
 
  [pianobar release];
  pianobar = nil;
}


// Sends a command to pianobar via stdin
- (void)sendCommand:(NSString *)command
{
  [writeHandle writeData:[[NSString stringWithFormat:@"%@\n", command] dataUsingEncoding:NSUTF8StringEncoding]];
}


// Notification when output is available from pianobar 
- (void)outputAvailable: (NSNotification *)notification
{  
  NSData *data;
  NSString *output;
  
  data = [[notification userInfo] objectForKey:@"NSFileHandleNotificationDataItem"];
  
  if ([data length])
  {
    output = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    
    [self processOutput:output];
    
    // Not using these at the moment, username/password should be in ~/.config/pianobar/config
    if ([output rangeOfString:@"Username"].location != NSNotFound)
    {
      [self sendCommand:@""];
    }
    else if ([output rangeOfString:@"Password"].location != NSNotFound)
    {
      [self sendCommand:@""];
    }
    else if ([output rangeOfString:@"Select station"].location != NSNotFound)
    {
      // Hardcoded to station 1
      [self sendCommand:@"1"];
    }
    
    [readHandle readInBackgroundAndNotify];
  }
}


// Take all the output and figure out what to do with it
// Currently just using it to get the current track time
- (void)processOutput:(NSString *)output
{
  // Remove whitespace and newlines from output as well as the character pianobar starts every line with
	NSString *cleaned = [[output stringByReplacingOccurrencesOfString:@"\033[2K" withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  // Time lines are prefixed with #
  if ([cleaned hasPrefix:@"#"])
  {
    self.currentTime = [cleaned stringByReplacingOccurrencesOfString:@"#  " withString:@""];
  }
}



#pragma mark -
#pragma mark NSDistributedNotification - communication with helper app

// Only handling a single event, when a new song starts
- (void)handleSongStartEvent:(NSNotification *)notification
{
	[self parseEventInfo:[notification object]];	
}


// Data passed from helper app is one string of name = value pairs separated by newlines
// Parse into a dictionary so we can get the info we need out easier
- (void)parseEventInfo:(NSString *)info
{
	NSMutableDictionary *data = [NSMutableDictionary dictionary];
	NSArray *lines = [[info stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@"\n"];
  
	for (NSString *line in lines)
	{
		NSArray *keyValue = [line componentsSeparatedByString:@"="];
		[data setObject:[keyValue objectAtIndex:1] forKey:[keyValue objectAtIndex:0]];
	}
	
  // Use accessors to ensure KVO notifications are sent
	self.currentArtist = [data objectForKey:@"artist"];
	self.currentSong = [data objectForKey:@"title"];
	self.currentAlbum = [data objectForKey:@"album"];
	self.currentArtworkURL = [NSURL URLWithString:[data objectForKey:@"coverArt"]];
}


#pragma mark -
#pragma mark Default Apple Singleton code

+ (TRPianobarManager *)sharedManager
{
  if (sharedPianobarManager == nil)
  {
    sharedPianobarManager = [[super allocWithZone:NULL] init];
  }
  
  return sharedPianobarManager;
}


+ (id)allocWithZone:(NSZone *)zone
{
  return [[self sharedManager] retain];
}


- (id)copyWithZone:(NSZone *)zone
{
  return self;
}


- (id)retain
{
  return self;
}


- (NSUInteger)retainCount
{
  return NSUIntegerMax;  //denotes an object that cannot be released
}


- (void)release
{
  //do nothing
}


- (id)autorelease
{
  return self;
}

@end