//
//  ViewController.h
//  BifBuilderGUI
//
//  Created by Kevin Scardina on 11/27/15.
//  Copyright © 2015 PopMedic Software, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController

@property (weak) IBOutlet NSButton *addButton;
@property (weak) IBOutlet NSButton *removeButton;
@property (weak) IBOutlet NSButton *goStopButton;
@property (weak) IBOutlet NSTableView *tableView;
@property (strong) IBOutlet NSArrayController *arrayController;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSProgressIndicator *totalProgressIndicator;

//delegates - override this stuff...
-(void)bifBuilderPercentCreatingFile:(float)percent;
- (void)bifBuilderFinished:(id)sender;

@end

