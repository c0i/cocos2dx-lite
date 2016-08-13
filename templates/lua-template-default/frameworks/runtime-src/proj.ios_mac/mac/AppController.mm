#import "AppController.h"

#import "CreateNewProjectDialogController.h"
#import "ProjectConfigDialogController.h"
#import "ConsoleWindowController.h"

#include "AppDelegate.h"
#include "glfw3.h"
#include "glfw3native.h"

#include "cocos2d.h"
#include "audio/include/SimpleAudioEngine.h"
//#include "CCLuaEngine.h"

//#include "PlayerMac.h"

USING_NS_CC;

@implementation AppController

@synthesize menu;

- (void) dealloc
{
    if (_buildTask)
    {
        [_buildTask interrupt];
        _buildTask = nil;
    }
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
//    auto player = player::PlayerMac::create();
//    player->setController(self);

    _isAlwaysOnTop = NO;
    _hasPopupDialog = NO;
    _debugLogFile = 0;

    _buildTask = nil;
    _isBuildingFinished = YES;

    // load C2D_ROOT from ~/.C2D_ROOT
    NSMutableString *path = [NSMutableString stringWithString:NSHomeDirectory()];
    [path appendString:@"/.C2D_ROOT"];
    NSError *error = [[[NSError alloc] init] autorelease];
    NSString *env = [NSString stringWithContentsOfFile:path
                                              encoding:NSUTF8StringEncoding
                                                 error:&error];
    if ([error code] || env.length == 0)
    {
        [self showAlertWithoutSheet:@"Please run \"setup_mac.sh\", set quick-cocos2d-x root path."
                          withTitle:@"quick player error"];
        [[NSApplication sharedApplication] terminate:self];
    }

    env = [env stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    SimulatorConfig::getInstance()->setQuickCocos2dxRootPath([env cStringUsingEncoding:NSUTF8StringEncoding]);

    [self updateProjectFromCommandLineArgs:&_project];
    [self createWindowAndGLView];
    [self registerEventsHandler];
    [self startup];
}

- (BOOL) windowShouldClose:(id)sender
{
    return YES;
}

- (void) windowWillClose:(NSNotification *)notification
{
    [[NSRunningApplication currentApplication] terminate];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)theApplication
{
    return YES;
}

- (BOOL) applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
    return NO;
}

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
    return _hasPopupDialog == NO;
}

- (void) updateUI
{
    NSMenu *menuPlayer = [[[_window menu] itemWithTitle:@"Player"] submenu];
    NSMenuItem *itemWriteDebugLogToFile = [menuPlayer itemWithTitle:@"Write Debug Log to File"];
    [itemWriteDebugLogToFile setState:_project.isWriteDebugLogToFile() ? NSOnState : NSOffState];

    NSMenu *menuScreen = [[[_window menu] itemWithTitle:@"Screen"] submenu];
    NSMenuItem *itemPortait = [menuScreen itemWithTitle:@"Portait"];
    NSMenuItem *itemLandscape = [menuScreen itemWithTitle:@"Landscape"];
    if (_project.isLandscapeFrame())
    {
        [itemPortait setState:NSOffState];
        [itemLandscape setState:NSOnState];
    }
    else
    {
        [itemPortait setState:NSOnState];
        [itemLandscape setState:NSOffState];
    }

    int scale = _project.getFrameScale() * 100;

    NSMenuItem *itemZoom100 = [menuScreen itemWithTitle:@"Actual (100%)"];
    NSMenuItem *itemZoom75 = [menuScreen itemWithTitle:@"Zoom Out (75%)"];
    NSMenuItem *itemZoom50 = [menuScreen itemWithTitle:@"Zoom Out (50%)"];
    NSMenuItem *itemZoom25 = [menuScreen itemWithTitle:@"Zoom Out (25%)"];
    [itemZoom100 setState:NSOffState];
    [itemZoom75 setState:NSOffState];
    [itemZoom50 setState:NSOffState];
    [itemZoom25 setState:NSOffState];
    if (scale == 100)
    {
        [itemZoom100 setState:NSOnState];
    }
    else if (scale == 75)
    {
        [itemZoom75 setState:NSOnState];
    }
    else if (scale == 50)
    {
        [itemZoom50 setState:NSOnState];
    }
    else if (scale == 25)
    {
        [itemZoom25 setState:NSOnState];
    }

    NSArray *recents = [[NSUserDefaults standardUserDefaults] arrayForKey:@"recents"];
    NSMenu *menuRecents = [[[[[_window menu] itemWithTitle:@"File"] submenu] itemWithTitle:@"Open Recent"] submenu];
    while (true)
    {
        NSMenuItem *item = [menuRecents itemAtIndex:0];
        if ([item isSeparatorItem]) break;
        [menuRecents removeItemAtIndex:0];
    }

    for (NSInteger i = [recents count] - 1; i >= 0; --i)
    {
        NSDictionary *recentItem = [recents objectAtIndex:i];
        NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:[recentItem objectForKey:@"title"]
                                                       action:@selector(onFileOpenRecent:)
                                                keyEquivalent:@""] autorelease];
        [menuRecents insertItem:item atIndex:0];
    }

    [_window setTitle:[NSString stringWithFormat:@"quick player (%0.0f%%)", _project.getFrameScale() * 100]];
}

- (void) updateOpenRect
{
    NSMutableArray *recents = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"recents"]];

    NSString *welcomeTitle = [NSString stringWithFormat:@"%splayer/welcome/", SimulatorConfig::getInstance()->getQuickCocos2dxRootPath().c_str()];

    for (NSInteger i = [recents count] - 1; i >= 0; --i)
    {
        id recentItem = [recents objectAtIndex:i];
        if (![[recentItem class] isSubclassOfClass:[NSDictionary class]])
        {
            [recents removeObjectAtIndex:i];
            continue;
        }

        NSString *title = [recentItem objectForKey:@"title"];
        if (!title || [title length] == 0 || [welcomeTitle compare:title] == NSOrderedSame || !CCFileUtils::sharedFileUtils()->isDirectoryExist([title cStringUsingEncoding:NSUTF8StringEncoding]))
        {
            [recents removeObjectAtIndex:i];
        }
    }

    NSString *title = [NSString stringWithCString:_project.getProjectDir().c_str() encoding:NSUTF8StringEncoding];
    if ([title length] > 0 && [welcomeTitle compare:title] != NSOrderedSame)
    {
        for (NSInteger i = [recents count] - 1; i >= 0; --i)
        {
            id recentItem = [recents objectAtIndex:i];
            if ([title compare:[recentItem objectForKey:@"title"]] == NSOrderedSame)
            {
                [recents removeObjectAtIndex:i];
            }
        }

        NSMutableArray *args = [self makeCommandLineArgsFromProjectConfig:kProjectConfigOpenRecent];
        NSDictionary *item = [NSDictionary dictionaryWithObjectsAndKeys:title, @"title", args, @"args", nil];
        [recents insertObject:item atIndex:0];
    }
    [[NSUserDefaults standardUserDefaults] setObject:recents forKey:@"recents"];
}

- (void) showModelSheet
{
    _hasPopupDialog = YES;
    if (_app)
    {
        Director::getInstance()->pause();
        CocosDenshion::SimpleAudioEngine::getInstance()->pauseBackgroundMusic();
        CocosDenshion::SimpleAudioEngine::getInstance()->pauseAllEffects();
    }
}

- (void) stopModelSheet
{
    _hasPopupDialog = NO;
    if (_app)
    {
        Director::getInstance()->resume();
        CocosDenshion::SimpleAudioEngine::getInstance()->resumeBackgroundMusic();
        CocosDenshion::SimpleAudioEngine::getInstance()->resumeAllEffects();
    }
}

- (NSMutableArray*) makeCommandLineArgsFromProjectConfig
{
    return [self makeCommandLineArgsFromProjectConfig:kProjectConfigAll];
}

- (NSMutableArray*) makeCommandLineArgsFromProjectConfig:(unsigned int)mask
{
    _project.setWindowOffset(Vec2(_window.frame.origin.x, _window.frame.origin.y));
    NSString *commandLine = [NSString stringWithCString:_project.makeCommandLine(mask).c_str()
                                               encoding:NSUTF8StringEncoding];
    return [NSMutableArray arrayWithArray:[commandLine componentsSeparatedByString:@" "]];
}

- (void) updateProjectFromCommandLineArgs:(ProjectConfig*)config
{
    NSArray *nsargs = [[NSProcessInfo processInfo] arguments];
    long n = [nsargs count];
    if (n >= 2)
    {
        vector<string> args;
        for (int i = 0; i < [nsargs count]; ++i)
        {
            string arg = [[nsargs objectAtIndex:i] cStringUsingEncoding:NSUTF8StringEncoding];
            if (arg.length()) args.push_back(arg);
        }

        if (args.size() && args.at(1).at(0) == '/')
        {
            // for Code IDE before RC2
            config->setProjectDir(args.at(1));
            config->setDebuggerType(kCCLuaDebuggerCodeIDE);
        }
        config->parseCommandLine(args);
    }

    if (config->getProjectDir().length() == 0)
    {
        config->resetToWelcome();
    }
}

- (void) launch:(NSArray*)args
{
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    NSMutableDictionary *configuration = [NSMutableDictionary dictionaryWithObject:args forKey:NSWorkspaceLaunchConfigurationArguments];
    NSError *error = [[[NSError alloc] init] autorelease];
    [[NSWorkspace sharedWorkspace] launchApplicationAtURL:url
                                                  options:NSWorkspaceLaunchNewInstance
                                            configuration:configuration error:&error];
}

- (void) relaunch:(NSArray*)args
{
    [self launch:args];
    [[NSApplication sharedApplication] terminate:self];
}

- (void) relaunch
{
    [self relaunch:[self makeCommandLineArgsFromProjectConfig]];
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

- (void) loadLuaConfig
{
//    LuaEngine* pEngine = LuaEngine::getInstance();
//    ScriptEngineManager::getInstance()->setScriptEngine(pEngine);
//
//    luaopen_PlayerLuaCore(pEngine->getLuaStack()->getLuaState());
//    luaopen_PlayerLuaCore_Manual(pEngine->getLuaStack()->getLuaState());
//
//
//    NSMutableString *path = [NSMutableString stringWithString:NSHomeDirectory()];
//    [path appendString:@"/"];
//
//
//    //
//    // set user home dir
//    //
//    lua_pushstring(pEngine->getLuaStack()->getLuaState(), path.UTF8String);
//    lua_setglobal(pEngine->getLuaStack()->getLuaState(), "__USER_HOME__");
//
//
//    //
//    // ugly: Add the opening project to the "Open Recents" list
//    //
//    lua_pushstring(pEngine->getLuaStack()->getLuaState(), _project.getProjectDir().c_str());
//    lua_setglobal(pEngine->getLuaStack()->getLuaState(), "__PLAYER_OPEN_TITLE__");
//
//    lua_pushstring(pEngine->getLuaStack()->getLuaState(), _project.makeCommandLine().c_str());
//    lua_setglobal(pEngine->getLuaStack()->getLuaState(), "__PLAYER_OPEN_COMMAND__");
//
//    //
//    // load player.lua file
//    //
//    string playerCoreFilePath = SimulatorConfig::getInstance()->getQuickCocos2dxRootPath() + "quick/welcome/src/player.lua";
//    pEngine->executeScriptFile(playerCoreFilePath.c_str());
}

- (void) adjustEditMenuIndex
{
    NSApplication *thisApp = [NSApplication sharedApplication];
    NSMenu *mainMenu = [thisApp mainMenu];

    NSMenuItem *editMenuItem = [mainMenu itemWithTitle:@"Edit"];
    if (editMenuItem)
    {
        NSUInteger index = 2;
        if (index > [mainMenu itemArray].count)
            index = [mainMenu itemArray].count;
        [[editMenuItem menu] removeItem:editMenuItem];
        [mainMenu insertItem:editMenuItem atIndex:index];
    }
}

#pragma mark -
#pragma mark functions

- (void) createWindowAndGLView
{
    GLContextAttrs glContextAttrs = {8, 8, 8, 8, 24, 8};
    GLView::setGLContextAttrs(glContextAttrs);

    float frameScale = _project.getFrameScale();

    // create opengl view
    cocos2d::Size frameSize = _project.getFrameSize();

    const cocos2d::Rect frameRect = cocos2d::Rect(0, 0, frameSize.width, frameSize.height);
    NSString *title = [NSString stringWithFormat:@"quick-x-player (%s)", cocos2dVersion()];
    GLViewImpl *eglView = GLViewImpl::createWithRect([title UTF8String], frameRect, frameScale, _project.isResizeWindow());

    auto director = Director::getInstance();
    director->setOpenGLView(eglView);

    _window = eglView->getCocoaWindow();
    [NSApp setDelegate:self];
    [_window center];

    if (_project.getProjectDir().length())
    {
        [self setZoom:_project.getFrameScale()];
        Vec2 pos = _project.getWindowOffset();
        if (pos.x != 0 && pos.y != 0)
        {
            [_window setFrameOrigin:NSMakePoint(pos.x, pos.y)];
        }
    }
}

- (void) registerEventsHandler
{
    [self registerKeyboardEventHandler];
    [self registerWindowEventsHandler];
}

- (void) registerWindowEventsHandler
{
    auto eventDispatcher = Director::getInstance()->getEventDispatcher();
    eventDispatcher->addCustomEventListener("APP.WINDOW_CLOSE_EVENT", [&](EventCustom* event)
                                            {
//                                                // If script set event's result to "cancel", ignore window close event
//                                                EventCustom forwardEvent("APP.EVENT");
//                                                stringstream buf;
//                                                buf << "{\"name\":\"close\"}";
//                                                forwardEvent.setDataString(buf.str());
//                                                Director::getInstance()->getEventDispatcher()->dispatchEvent(&forwardEvent);
//                                                if (forwardEvent.getResult().compare("cancel") != 0)
//                                                {
//                                                    GLViewImpl *glview = (GLViewImpl *) Director::getInstance()->getOpenGLView();
//                                                    glfwSetWindowShouldClose(glview->getWindow(), 1);
//                                                }
                                            });

//    ProjectConfig& lambdaProject = _project;
    eventDispatcher->addCustomEventListener("APP.VIEW_SCALE", [&](EventCustom* event)
                                            {
//                                                float scale = atof(event->getDataString().c_str());
//                                                lambdaProject.setFrameScale(scale);
//                                                cocos2d::Director::getInstance()->getOpenGLView()->setFrameZoomFactor(scale);
                                            });
}

- (void) registerKeyboardEventHandler
{
    auto keyEvent = cocos2d::EventListenerKeyboard::create();
    keyEvent->onKeyReleased = [](EventKeyboard::KeyCode key, Event*) {
//        auto event = EventCustom("APP.EVENT");
//        stringstream data;
//        data << "{\"name\":\"keyReleased\",\"data\":" << (int)key << "}";
//        event.setDataString(data.str());
//        Director::getInstance()->getEventDispatcher()->dispatchEvent(&event);
    };

    cocos2d::Director::getInstance()->getEventDispatcher()->addEventListenerWithFixedPriority(keyEvent, 1);
}

- (void) startup
{
    FileUtils::getInstance()->setPopupNotify(false);

    std::string path = SimulatorConfig::getInstance()->getQuickCocos2dxRootPath();
    const string projectDir = _project.getProjectDir();
    if (projectDir.length())
    {
//        FileUtils::getInstance()->setSearchRootPath(projectDir.c_str());
        if (_project.isWriteDebugLogToFile())
        {
            [self writeDebugLogToFile:_project.getDebugLogFilePath()];
        }
    }

    // set framework path
    if (!_project.isLoadPrecompiledFramework())
    {
        FileUtils::getInstance()->addSearchPath(SimulatorConfig::getInstance()->getQuickCocos2dxRootPath() + "quick/");
    }

    const string writablePath = _project.getWritableRealPath();
    if (writablePath.length())
    {
        FileUtils::getInstance()->setWritablePath(writablePath.c_str());
    }

    if (_project.isShowConsole())
    {
        [self openConsoleWindow];
        CCLOG("%s\n",Configuration::getInstance()->getInfo().c_str());
    }

    // add .app/Contents/Resources to search path
    FileUtils::getInstance()->addSearchPath([[NSBundle mainBundle] resourcePath].UTF8String);

    [self loadLuaConfig];
    [self adjustEditMenuIndex];
//    if (!_project.isAppMenu())
//    {
//        NSMenu *mainMenu = [[NSApplication sharedApplication] mainMenu];
//        NSArray *menuArray = [mainMenu itemArray];
//        for (int i = 1; i < [menuArray count]; i++)
//        {
//            id onemenu = [menuArray objectAtIndex:i];
//            [mainMenu removeItem:onemenu];
//        }
//    }

    // app
    _app = new AppDelegate();
    _app->setProjectConfig(_project);
    Application::getInstance()->run();
    // After run, application needs to be terminated immediately.
    [NSApp terminate: self];
}

- (void) openConsoleWindow
{
    if (!_consoleController)
    {
        _consoleController = [[ConsoleWindowController alloc] initWithWindowNibName:@"ConsoleWindow"];
    }
    [_consoleController.window orderFrontRegardless];

    //set console pipe
    _pipe = [NSPipe pipe] ;
    _pipeReadHandle = [_pipe fileHandleForReading] ;

    int outfd = [[_pipe fileHandleForWriting] fileDescriptor];
    if (dup2(outfd, fileno(stderr)) != fileno(stderr) || dup2(outfd, fileno(stdout)) != fileno(stdout))
    {
        perror("Unable to redirect output");
        //        [self showAlert:@"Unable to redirect output to console!" withTitle:@"player error"];
    }
    else
    {
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(handleNotification:) name: NSFileHandleReadCompletionNotification object: _pipeReadHandle] ;
        [_pipeReadHandle readInBackgroundAndNotify] ;
    }
}

- (bool) writeDebugLogToFile:(const string)path
{
    if (_debugLogFile) return true;
    //log to file
    if(_fileHandle) return true;
    NSString *fPath = [NSString stringWithCString:path.c_str() encoding:[NSString defaultCStringEncoding]];
    [[NSFileManager defaultManager] createFileAtPath:fPath contents:nil attributes:nil] ;
    _fileHandle = [NSFileHandle fileHandleForWritingAtPath:fPath];
    [_fileHandle retain];
    return true;
}

- (void)handleNotification:(NSNotification *)note
{
    //NSLog(@"Received notification: %@", note);
    [_pipeReadHandle readInBackgroundAndNotify] ;
    NSData *data = [[note userInfo] objectForKey:NSFileHandleNotificationDataItem];
    NSString *str = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

    //show log to console
    [_consoleController trace:str];
    if(_fileHandle!=nil){
        [_fileHandle writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
    }

}

- (void) closeDebugLogFile
{
    if(_fileHandle){
        [_fileHandle closeFile];
        [_fileHandle release];
        _fileHandle = nil;
    }
    if (_debugLogFile)
    {
        close(_debugLogFile);
        _debugLogFile = 0;
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self];
    }
}

- (void) setZoom:(float)scale
{
    Director::getInstance()->getOpenGLView()->setFrameZoomFactor(scale);
    _project.setFrameScale(scale);
}

-(void) setAlwaysOnTop:(BOOL)alwaysOnTop
{
    NSMenuItem *windowMenu = [[_window menu] itemWithTitle:@"Window"];
    NSMenuItem *menuItem = [[windowMenu submenu] itemWithTitle:@"Always On Top"];
    if (alwaysOnTop)
    {
        [_window setLevel:NSFloatingWindowLevel];
        [menuItem setState:NSOnState];
    }
    else
    {
        [_window setLevel:NSNormalWindowLevel];
        [menuItem setState:NSOffState];
    }
    _isAlwaysOnTop = alwaysOnTop;
}

#pragma mark -
#pragma mark IB Actions

- (IBAction) onFileNewProject:(id)sender
{
    //    [self showAlert:@"Coming soon :-)" withTitle:@"quick-player"];
    [self showModelSheet];
    CreateNewProjectDialogController *controller = [[CreateNewProjectDialogController alloc] initWithWindowNibName:@"CreateNewProjectDialog"];
    [NSApp beginSheet:controller.window modalForWindow:_window didEndBlock:^(NSInteger returnCode) {
        [self stopModelSheet];
        [controller release];
    }];
}

- (IBAction) onFileNewPlayer:(id)sender
{
    NSMutableArray *args = [self makeCommandLineArgsFromProjectConfig];
    [args removeLastObject];
    [args removeLastObject];
    [self launch:args];
}

- (IBAction) onFileOpen:(id)sender
{
    [self showModelSheet];
    ProjectConfigDialogController *controller = [[ProjectConfigDialogController alloc] initWithWindowNibName:@"ProjectConfigDialog"];
    ProjectConfig newConfig;
    if (!_project.isWelcome())
    {
        newConfig = _project;
    }
    [controller setProjectConfig:newConfig];

    id window = Director::getInstance()->getOpenGLView()->getCocoaWindow();
    [NSApp beginSheet:controller.window modalForWindow:window didEndBlock:^(NSInteger returnCode) {
        if (returnCode == NSRunStoppedResponse)
        {
            _project = controller.projectConfig;
            [self relaunch];
        }
        [self stopModelSheet];
        [controller release];
    }];
}

- (IBAction) onFileOpenRecent:(id)sender
{
    NSArray *recents = [[NSUserDefaults standardUserDefaults] objectForKey:@"recents"];
    NSDictionary *recentItem = nil;
    NSString *title = [sender title];
    for (NSInteger i = [recents count] - 1; i >= 0; --i)
    {
        recentItem = [recents objectAtIndex:i];
        if ([title compare:[recentItem objectForKey:@"title"]] == NSOrderedSame)
        {
            [self relaunch:[recentItem objectForKey:@"args"]];
            break;
        }
    }
}

- (IBAction) onFileOpenRecentClearMenu:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray array] forKey:@"recents"];
    [self updateUI];
}

- (IBAction) onFileWelcome:(id)sender
{
    _project.resetToWelcome();
    [self relaunch];
}

- (IBAction) onFileClose:(id)sender
{
    [[NSApplication sharedApplication] terminate:self];
}

- (IBAction) onPlayerWriteDebugLogToFile:(id)sender
{
    bool isWrite = _project.isWriteDebugLogToFile();
    if (!isWrite)
    {
        if ([self writeDebugLogToFile:_project.getDebugLogFilePath()])
        {
            _project.setWriteDebugLogToFile(true);
            [(NSMenuItem*)sender setState:NSOnState];
        }
    }
    else
    {
        _project.setWriteDebugLogToFile(false);
        [self closeDebugLogFile];
        [(NSMenuItem*)sender setState:NSOffState];
    }
}

- (IBAction) onPlayerOpenDebugLog:(id)sender
{
    const string path = _project.getDebugLogFilePath();
    [[NSWorkspace sharedWorkspace] openFile:[NSString stringWithCString:path.c_str() encoding:NSUTF8StringEncoding]];
}

- (IBAction) onPlayerRelaunch:(id)sender
{
    [self relaunch];
}

- (IBAction) onPlayerShowProjectSandbox:(id)sender
{
    [[NSWorkspace sharedWorkspace] openFile:[NSString stringWithCString:FileUtils::getInstance()->getWritablePath().c_str() encoding:NSUTF8StringEncoding]];
}

- (IBAction) onPlayerShowProjectFiles:(id)sender
{
    [[NSWorkspace sharedWorkspace] openFile:[NSString stringWithCString:_project.getProjectDir().c_str() encoding:NSUTF8StringEncoding]];
}

- (IBAction) onScreenChangeFrameSize:(id)sender
{
    NSInteger i = [sender tag];
    if (i >= 0 && i < SimulatorConfig::getInstance()->getScreenSizeCount())
    {
        SimulatorScreenSize size = SimulatorConfig::getInstance()->getScreenSize((int)i);
        _project.setFrameSize(_project.isLandscapeFrame() ?
                              SizeMaker(size.height, size.width) :
                              SizeMaker(size.width, size.height));
        _project.setFrameScale(1.0f);
        [self relaunch];
    }
}

- (IBAction) onScreenPortait:(id)sender
{
    if ([sender state] == NSOnState) return;
    [sender setState:NSOnState];
    [[[[[_window menu] itemWithTitle:@"Screen"] submenu] itemWithTitle:@"Landscape"] setState:NSOffState];
    _project.changeFrameOrientationToPortait();
    [self relaunch];
}

- (IBAction) onScreenLandscape:(id)sender
{
    if ([sender state] == NSOnState) return;
    [sender setState:NSOnState];
    [[[[[_window menu] itemWithTitle:@"Screen"] submenu] itemWithTitle:@"Portait"] setState:NSOffState];
    _project.changeFrameOrientationToLandscape();
    [self relaunch];
}

- (IBAction) onScreenZoomOut:(id)sender
{
    if ([sender state] == NSOnState) return;
    float scale = (float)[sender tag] / 100.0f;
    [self setZoom:scale];
    [self updateUI];
    [self updateOpenRect];
}

-(IBAction) onWindowAlwaysOnTop:(id)sender
{
    [self setAlwaysOnTop:!_isAlwaysOnTop];
}

-(IBAction)onRelaunch:(id)sender
{
    [self relaunch];
}

@end
