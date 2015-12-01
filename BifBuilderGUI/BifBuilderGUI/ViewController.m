//
//  ViewController.m
//  BifBuilderGUI
//
//  Created by Kevin Scardina on 11/27/15.
//  Copyright © 2015 PopMedic Software, Inc. All rights reserved.
//

#import "ViewController.h"
#import "BifBuilder.h"

@implementation ViewController

BifBuilder* bifBuilder;
BOOL go = NO;
NSInteger fileIndex;

- (IBAction)addButtonClick:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setAllowedFileTypes:@[@"mp4"]];
    [panel setCanChooseDirectories:YES];
    [panel setAllowsMultipleSelection:YES]; // yes if more than one dir is allowed
    
    NSInteger clicked = [panel runModal];
    
    if (clicked == NSFileHandlingPanelOKButton) {
        for (NSURL *url in [panel URLs]) {
            [self.arrayController addObject: @{@"location":url.path}];
        }
    }
}
- (IBAction)removeButtonClick:(id)sender {
    if([[self.arrayController arrangedObjects] count] > 0){
        [self.arrayController removeObjectAtArrangedObjectIndex:[self.tableView selectedRow]];
    }
}
- (IBAction)goStopButtonClick:(id)sender {
    if([[self.arrayController arrangedObjects] count] > 0){
        if(!go){
            fileIndex = 0;
            NSDictionary* dict = [[self.arrayController arrangedObjects] objectAtIndex:fileIndex];
            if([dict isKindOfClass:[NSDictionary class]]){
                NSString* path = dict[@"location"];
                if([path isKindOfClass:[NSString class]]){
                    BOOL isDir;
                    if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]){
                        go = YES;
                        [self.goStopButton setImage:[NSImage imageNamed:@"cancel_button"]];
                        if(!isDir){dispatch_async(dispatch_get_main_queue(), ^{
                            [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:fileIndex] byExtendingSelection:NO];
                        });
                            [bifBuilder createBifFor:path];
                        }
                    }
                }
            }
        }
        else{
            go = NO;
            [bifBuilder cancelCreateBifForFile];
            /*[self.goStopButton setImage:[NSImage imageNamed:@"go_button"]];
            dispatch_async(dispatch_get_main_queue(), ^{                
                [self.progressIndicator setDoubleValue:0.0];
                [self.totalProgressIndicator setDoubleValue:0.0];
            });*/
        }
        [self.addButton setEnabled:!go];
        [self.removeButton setEnabled:!go];
        [self.tableView setEnabled:!go];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    bifBuilder = [[BifBuilder alloc] init];
    [bifBuilder setDelegate:self];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (void)bifBuilderFinished:(id) sender {
    fileIndex = fileIndex + 1;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Total Progress: %f", (double)((double)fileIndex/(double)[[self.arrayController arrangedObjects] count]));
        [self.totalProgressIndicator setDoubleValue:(double)((double)fileIndex/(double)[[self.arrayController arrangedObjects] count])*100.0];
    });
    
    if(fileIndex < [[self.arrayController arrangedObjects] count] && go){
        NSDictionary* dict = [[self.arrayController arrangedObjects] objectAtIndex:fileIndex];
        if([dict isKindOfClass:[NSDictionary class]]){
            NSString* path = dict[@"location"];
            if([path isKindOfClass:[NSString class]]){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:fileIndex] byExtendingSelection:NO];
                });
                [bifBuilder createBifFor:path];
            }
        }
    }
    else{
        // we are at the end!!! or cancelled...
        go = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.goStopButton setImage:[NSImage imageNamed:@"go_button"]];
            [self.addButton setEnabled:!go];
            [self.removeButton setEnabled:!go];
            [self.tableView setEnabled:!go];
            [self.progressIndicator setDoubleValue:0.0];
            [self.totalProgressIndicator setDoubleValue:0.0];
        });
    }
}

-(void)bifBuilderPercentCreatingFile:(float)percent{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressIndicator setDoubleValue:(double)percent];
    });
}
@end
