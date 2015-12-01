//
//  POPBIFBuilder.m
//  OrangeCrush
//
//  Created by Kevin Scardina on 5/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "BifBuilder.h"


@implementation BifBuilder

NSTask *ffmpeg;
NSPipe *outputPipe;
NSPipe *inputPipe;
unsigned int interval;
NSString *inFileName;
NSString *__err;
NSMutableArray *mp4s;
NSTask *mp4info;
BOOL isErr;
BOOL rebuild;
BOOL cancelled;
id delegate;
int mp4sCount;
NSInteger currentDuration;


-(id)init
{
	self = [super init];
    if (self){
        ffmpeg = nil;
        mp4info = nil;
        mp4s = nil;
        mp4sCount = 0;
        currentDuration = 0;
        inputPipe = nil;
        cancelled = NO;
        outputPipe = nil;
        
        NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
        if([resourcePath characterAtIndex:[resourcePath length]-1] != '/')
            resourcePath = [resourcePath stringByAppendingString:@"/"];
        self.ffmpegCmd = [resourcePath stringByAppendingString:@"ffmpeg"];
        self.ffmpegCmdFmt = @"%@ -i %@ -r %0.2f -s %@ %@/%%08d.jpg";
        self.mp4infoCmd = [resourcePath stringByAppendingString:@"mp4info"];
        [self setRebuild:NO];
        [self setInterval:10];
    }
	
	return self;
}

@synthesize mp4infoCmd;
@synthesize ffmpegCmd;
@synthesize ffmpegCmdFmt;
@synthesize inFileLoc;
@synthesize outFileLoc;
@synthesize outFileName;
@synthesize tempDirectory;
@synthesize interval;
@synthesize cmd;
@synthesize rebuild;

-(void) setDelegate:(id)newDelegate
{
	delegate = newDelegate;
}

-(id) delegate
{
	return delegate;
}

-(void)setInFileName:(NSString*)ifn
{
	if(ifn == nil)
	{
		__err = @"[POPBIFBuilder setInFileName:(NSString *)ifn] -> ifn CANNOT BE NIL";
		isErr = YES;
		return;
	}
	if(![[NSFileManager defaultManager] fileExistsAtPath:ifn])
	{
		__err = [NSString stringWithFormat:@"[POPBIFBuilder setInFileName:(NSString *)ifn] -> %@ is not a file", ifn];
		isErr = YES;
		return;
	}
	inFileName = [ifn copy];
	[self setValue:[ifn stringByDeletingLastPathComponent] 
			forKey:@"inFileLoc"];
	[self setValue:[ifn stringByDeletingLastPathComponent] 
			forKey:@"outFileLoc"];
	[self setValue:[[ifn stringByDeletingPathExtension] stringByAppendingString:@"-SD.bif"] 
			forKey:@"outFileName"];
    self.outFileName = [[ifn stringByDeletingPathExtension] stringByAppendingString:@"-SD.bif"];
	//[self setValue:[NSString stringWithFormat:[self ffmpegCmdFmt], [self ffmpegCmd], [self inFileName], [self outFileName]] 
	//		forKey:@"cmd"];
	isErr = NO;
	return;
}


-(NSString *)inFileName
{
	return inFileName;
}

-(void) compileBif
{	
	NSError *nsErr;
	
	NSMutableData *bifData;
	bifData = [[NSMutableData alloc] init];
	
	isErr = NO;
	//get the images array
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self tempDirectory] error:&nsErr];
	if(files == nil)
	{
		__err = [NSString stringWithFormat:@"[POPBIFBuilder compileBif] -> %@", [nsErr localizedDescription]];
		isErr = YES;
	}
	else
	{
		//add image files to image array
		NSMutableArray *images = [[NSMutableArray alloc] init];
		NSInteger c = [files count];
		for(int i = 0; i < c; i++)
		{
            NSString *f = (NSString*)[files objectAtIndex:i];
            if(i < 2){
                if([[NSFileManager defaultManager] fileExistsAtPath:f]){
                    if(![[NSFileManager defaultManager] removeItemAtPath:f error:&nsErr])
                    {
                        isErr = YES;
                        __err = [NSString stringWithFormat:@"[POPIMGBuilder compileBif] -> %@", [nsErr localizedDescription]];
                    }
                }
            }
            else{
                if([[f pathExtension] caseInsensitiveCompare:@"jpg"] == 0)
                {
                    [images addObject:[f copy]];
                }
            }
		}
		
		//write out the magic bytes
		char magic[8];
		magic[0] = 0x89;
		magic[1] = 0x42;
		magic[2] = 0x49;
		magic[3] = 0x46;
		magic[4] = 0x0d;
		magic[5] = 0x0a;
		magic[6] = 0x1a;
		magic[7] = 0x0a;
		[bifData appendBytes:magic length:8];
		
		//write out the version
		unsigned int v = 0;
		[bifData appendBytes:(char*)&v length:sizeof(unsigned int)];
		
		//write out the number of images
		unsigned int imgCnt = (unsigned int)[images count];
		[bifData appendBytes:(char*)&imgCnt length:sizeof(unsigned int)];
		
		//write out the intervals
		unsigned int intervals = 1000 * [self interval];
		[bifData appendBytes:(char*)&intervals length:sizeof(unsigned int)];
		
		//write out the NULL block
		char null = '\0';
		while([bifData length] < 64) [bifData appendBytes:&null length:sizeof(char)];
		
		//vars for image length and indexing
		unsigned int bifTableSize = 8 + (8 * (unsigned int)[images count]);
		unsigned int imageIndex = 64 + bifTableSize;
		unsigned int timestamp = 1;
		//now write out the image length and indexing
		NSString *td;
		if([[self tempDirectory] characterAtIndex:[[self tempDirectory] length]-1] == '/') td = [self tempDirectory];
		else td = [[self tempDirectory] stringByAppendingString:@"/"];
		c = [images count];
		for(int i = 0; i < c; i++)
		{
			[bifData appendBytes:(char*)&timestamp length:sizeof(unsigned int)];
			[bifData appendBytes:(char*)&imageIndex length:sizeof(unsigned int)];
			
            NSString *fp = [td stringByAppendingString:(NSString*)[images objectAtIndex:i]];
			NSDictionary *fattrs = [[NSFileManager defaultManager] fileAttributesAtPath:fp traverseLink:NO];
			unsigned int fs = [[fattrs objectForKey:NSFileSize] unsignedLongLongValue];
			
			timestamp += 1;
			imageIndex += fs;
			
			fp = nil;
			fattrs = nil;
		}
		
		unsigned int fin = 0xffffffff;
		[bifData appendBytes:(char*)&fin length:sizeof(unsigned int)];
		[bifData appendBytes:(char*)&imageIndex length:sizeof(unsigned int)];
		
		//now write out the images
        for(int i = 0; i < c; i++)
		{
			NSString *fp = [td stringByAppendingString:(NSString*)[images objectAtIndex:i]];
			NSData *imgData = [NSData dataWithContentsOfFile:fp];
			
			[bifData appendData:imgData];
			
            fp = nil;
			imgData = nil;
		}
        //now delete the images
        for(int i = 0; i < c; i++)
        {
            NSString *fp = [td stringByAppendingString:(NSString*)[images objectAtIndex:i]];
            if([[NSFileManager defaultManager] fileExistsAtPath:fp]){
                if(![[NSFileManager defaultManager] removeItemAtPath:fp error:&nsErr])
                {
                    isErr = YES;
                    __err = [NSString stringWithFormat:@"[POPIMGBuilder compileBif] -> %@", [nsErr localizedDescription]];
                }
            }
            fp = nil;
        }
		//now write the file out
		[bifData writeToFile:[self outFileName] atomically:NO];
		
		//clean up the array
		while([images count] > 0)
		{
			NSString *t = [images objectAtIndex:[images count]-1]; 
			[images removeObjectAtIndex:[images count]-1];
			//[t release];
			t = nil;
		}
		//[images release];
		images = nil;
		
		td = nil;
		files = nil;
		images = nil;
	}
	//delete the temp directory
	if(![[NSFileManager defaultManager] removeItemAtPath:[self tempDirectory] error:&nsErr])
	{
		isErr = YES;
		__err = [NSString stringWithFormat:@"[POPIMGBuilder compileBif] -> %@", [nsErr localizedDescription]];
	}
	
	//clean up the bifData
	//[bifData release];
	bifData = nil;
	return;
}

-(void) cancelCreateBifForFile{
    if(inputPipe != nil){
        NSFileHandle* wfh = [inputPipe fileHandleForWriting];
        [wfh writeData:[@"q" dataUsingEncoding:NSUTF8StringEncoding]];
        cancelled = YES;
    }
}

-(BOOL) createBifFor:(NSString*)mp4File
{
	BOOL go = NO;
	BOOL isDir = NO;
	
	NSString *tmpDir = NSTemporaryDirectory();
	if([tmpDir characterAtIndex:[tmpDir length]-1] != '/') tmpDir = [tmpDir stringByAppendingString:@"/"];
	tmpDir = [tmpDir stringByAppendingString:@"biftmpdir"];
	
	[self setInFileName:mp4File];
	if(isErr)
	{
		NSRunAlertPanel(@"ERROR", __err, @"Ok", nil, nil);
		return NO;
	}
    NSString* filePath = [[[self inFileName] stringByDeletingPathExtension] stringByAppendingString:@"-SD.bif"] ;
    if([self rebuild]){
        go = YES;
    }
    else if(![[NSFileManager defaultManager] fileExistsAtPath:filePath]){
        go = YES;
    }
    else{
        go = NO;
    }
	if(go)
	{
        [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir attributes:@{}];
		if(![[NSFileManager defaultManager] fileExistsAtPath:tmpDir isDirectory:&isDir])
		{
			NSRunAlertPanel(@"ERROR", 
							[NSString stringWithFormat:@"[POPBIFBuilder createBifFor:%@] -> Unable to create temp directory \"%@\"", 
								mp4File, tmpDir],
							@"Ok", nil, nil);
			return NO;
		}
		else 
		{
			[self setTempDirectory:tmpDir];
		}

		ffmpeg = [[NSTask alloc] init];
		[ffmpeg setLaunchPath:[self ffmpegCmd]];
		
		[ffmpeg setCurrentDirectoryPath:[self tempDirectory]];
		//"ffmpeg -i %s -r %0.2f -s %s %s/%%08d.jpg" % (videoFile, interval/100.0, videoSizes[mode], directory)
		[ffmpeg setArguments:[NSArray arrayWithObjects: @"-i", 
														[self inFileName], 
														@"-r", 
														[NSString stringWithFormat:@"%0.2f", (float)([self interval]/100.0)], 
														@"-s", 
														@"320x240", 
														[NSString stringWithFormat:@"%@/%%08d.jpg", [self tempDirectory]],
														nil]];
        outputPipe = [NSPipe pipe];
        inputPipe = [NSPipe pipe];
        [ffmpeg setStandardOutput:outputPipe];
        [ffmpeg setStandardError:outputPipe];
        [ffmpeg setStandardInput:inputPipe];
        NSFileHandle* rfh = [outputPipe fileHandleForReading];
        [rfh waitForDataInBackgroundAndNotify];
		[[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(progressHandler:) name:NSFileHandleDataAvailableNotification object:rfh];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishedHandler:) name:NSFileHandleReadToEndOfFileCompletionNotification object:rfh];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(finishedExtractingImages:) 
													 name:NSTaskDidTerminateNotification 
												   object:ffmpeg];
		[ffmpeg launch];
	}
	else 
	{
		if([delegate respondsToSelector:@selector(bifBuilderFinished:)])
            [delegate bifBuilderFinished:self];
	}
	return YES;
}

-(void)progressHandler:(NSNotification*)noti{
    NSFileHandle *fh = [noti object];
    NSData *data = [fh availableData];
    if (data.length > 0) { // if data is found, re-register for more data (and print)
        [fh waitForDataInBackgroundAndNotify];
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        // parse str for /Duration\\:/
        NSRange range = [str rangeOfString:@"Duration: "];
        if(range.location != NSNotFound){
            NSRange durRange = NSMakeRange(range.location + range.length, 11);
            NSString* durStr = [str substringWithRange:durRange];
            NSLog(@"#######DURSTR:  %@  ########", durStr);
            NSArray* parts = [durStr componentsSeparatedByString:@":"];
            if(parts.count > 2){
                NSInteger hours = (((NSString*)parts[0]).integerValue)*60*60;
                NSInteger mins = (((NSString*)parts[1]).integerValue)*60;
                NSInteger secs = ((NSString*)parts[2]).integerValue;
                currentDuration = hours+mins+secs;
            }
        }
        range = [str rangeOfString:@"time="];
        NSInteger time=0;
        if(range.location != NSNotFound){
            NSString* chunk = [str substringWithRange:NSMakeRange(range.location+range.length, 20)];
            NSInteger l = [chunk rangeOfString:@" "].location;
            if(l < 150) {
                NSString* timeStr = [chunk substringToIndex:[chunk rangeOfString:@" "].location];
                NSLog(@"#######TIMESTR:  %@  ########", timeStr);
                time = timeStr.integerValue;
            }
        }
        if(currentDuration > 0 && time > 0){
            NSLog(@"%f%%" ,(float)(((float)time/(float)currentDuration)*100.0));
            if([self.delegate respondsToSelector:@selector(bifBuilderPercentCreatingFile:)]){
                [self.delegate bifBuilderPercentCreatingFile:(float)(((float)time/(float)currentDuration)*100.0)];
            }
        }
    }
}

-(void)finishedHandler:(NSNotification*)noti{
    NSData* data = [[noti userInfo] objectForKey:NSFileHandleNotificationDataItem];
    NSLog(@"Read all data: %@", data);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:[noti object]];
}

- (void)finishedExtractingImages:(NSNotification *)aNotification
{
    outputPipe = nil;
    inputPipe = nil;
    if(ffmpeg != nil)
	{
        if(!cancelled){
            [self compileBif];
        }
        else{
            cancelled = NO;
        }
		if(isErr)
		{
			NSRunAlertPanel(@"ERROR", __err, @"Ok", nil, nil);
		}
		
		[[NSNotificationCenter defaultCenter] removeObserver:self];
		//[ffmpeg release];
		ffmpeg = nil;
        if([delegate respondsToSelector:@selector(bifBuilderFinished:)])
            [delegate bifBuilderFinished:self];
	}
	return;
}

//-(BOOL) walkDir:(NSString*)dir
//{
//	NSError *error = nil;
//	NSString *p = nil, *path = nil;
//	BOOL isDir = NO;
//	NSFileManager *dm = [NSFileManager defaultManager];
//	NSArray *a = [dm contentsOfDirectoryAtPath:dir 
//										 error:&error];
//	if (a == nil){
//		NSLog(@"%@",[error localizedFailureReason]);
//		__err = [error localizedFailureReason];
//		return NO;
//	}
//	else{
//		int c = [a count];
//		for (int i = 0; i < c; i++){
//			p = (NSString*)[a objectAtIndex:i];
//			if([dir characterAtIndex:[dir length]-1] != '/') path = [dir stringByAppendingFormat:@"/%@", p];
//			else path = [dir stringByAppendingString:p];
//			if([[[path pathExtension] uppercaseString] compare:@"MP4"] == 0){
//				[mp4s addObject:[path copy]];
//			}
//			else if([dm fileExistsAtPath:path isDirectory:&isDir]){
//				if(isDir)
//					[self walkDir:path];
//			}
//		}
//	}
//	return YES;
//}
- (void)bifBuilderFinished:(id) sender {} //called when done.
-(void)bifBuilderPercentCreatingFile:(float)percent{}
@end
