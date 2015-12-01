//
//  POPBIFBuilder.h
//  OrangeCrush
//
//  Created by Kevin Scardina on 5/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BifBuilder : NSObject {
    
}
@property  NSString* mp4infoCmd;
@property  NSString *ffmpegCmd;
@property  NSString *ffmpegCmdFmt;
@property  NSString *inFileLoc;
@property  NSString *outFileLoc;
@property  NSString *inFileName;
@property  NSString *tempDirectory;
@property  NSString *outFileName;
@property  unsigned int interval;
@property  NSString *cmd;
@property  BOOL rebuild;
@property  id delegate;

-(id)init;

-(BOOL) createBifFor:(NSString*)mp4File;
-(void) cancelCreateBifForFile;

//delegates - override this stuff...
-(void)bifBuilderPercentCreatingFile:(float)percent;
- (void)bifBuilderFinished:(id)sender;

@end
