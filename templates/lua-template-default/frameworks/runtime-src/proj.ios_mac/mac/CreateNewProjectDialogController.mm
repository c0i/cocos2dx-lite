
#import "CreateNewProjectDialogController.h"
#import "ProjectConfig/SimulatorConfig.h"

@implementation CreateNewProjectDialogController

@synthesize textFieldProjetLocation;
@synthesize textFieldPackageName;
@synthesize textView;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void) showAlertWithoutSheet:(NSString*)message withTitle:(NSString*)title
{
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:message];
    [alert setInformativeText:title];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
}

- (void)dealloc
{
    [super dealloc];
    NSLog(@"[CreateNewProjectDialogController dealloc]");
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction) onSelectProjectLocation:(id)sender
{
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setTitle:@"Select New Project Location"];
    [openDlg setCanChooseDirectories:YES];
    [openDlg setCanChooseFiles:NO];
    [openDlg setCanHide:YES];
    [openDlg setCanCreateDirectories:YES];
    [openDlg setCanSelectHiddenExtension:NO];
    [openDlg setAllowsMultipleSelection:NO];

    if ([openDlg runModal] == NSFileHandlingPanelOKButton)
    {
        NSString *path = [[openDlg.URLs objectAtIndex:0] path];
        [textFieldProjetLocation setStringValue:path];
    }
}

- (IBAction) onCancel:(id)sender
{
    [self close];
    [NSApp endSheet:self.window returnCode:NSRunAbortedResponse];
}

- (IBAction) onCreate:(id)sender
{
    // check all filed
    NSString *projectLocation = [textFieldProjetLocation stringValue];
    NSString *packageName = [textFieldPackageName stringValue];
    
    // run script
    NSString *createProjectShellFilePath = [NSString stringWithFormat:@"%s/tools/cocos2d-console/bin/cocos",
                                                      SimulatorConfig::getInstance()->getQuickCocos2dxRootPath().c_str()];
    if (![[NSFileManager defaultManager] fileExistsAtPath:createProjectShellFilePath])
    {
        NSString *msg = [NSString stringWithFormat:@"%@ isn't exist, pls check your quick env.", createProjectShellFilePath];
        [self showAlertWithoutSheet:msg withTitle:@"quick player"];
        return ;
    }
    NSString *commandLine = [NSString stringWithFormat:@"%@ new -l lua -p %@ -d %@ lua\n",
                                                                         createProjectShellFilePath,
                                                                         packageName,
                                                                         projectLocation];
    [[[textView textStorage] mutableString] appendString:commandLine];
    
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: createProjectShellFilePath];
    
    NSArray *arguments = [NSArray arrayWithObjects:@"new"
                                                   , @"-l lua"
                                                   , [NSString stringWithFormat:@"-d %@", projectLocation]
                                                   , [NSString stringWithFormat:@"-p %@", packageName]
                                                   , nil];
    [task setArguments: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data;
    data = [file readDataToEndOfFile];
    
    NSString *string;
    string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    
    [[[textView textStorage] mutableString] appendString:string];
    
    [string release];
    [task release];
}

- (IBAction) onPackageNameChanged:(id)sender
{

}

@end
