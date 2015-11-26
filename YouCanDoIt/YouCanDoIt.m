@import AVKit;
@import AVFoundation;
@import CoreVideo;
@import CoreGraphics;
@import QuartzCore;

#import "YouCanDoIt.h"
#import "NSwindow+Fading.h"

// I just took these directly from AxeMode
// https://github.com/alloy/AxeMode/blob/master/AxeMode/AxeMode.m

@interface IDEActivityLogSection : NSObject
@property(readonly) unsigned long long totalNumberOfErrors;
@property(readonly) NSArray *subsections;
@property(readonly) NSString *text;
// TODO use this instead?
- (id)enumerateSubsectionsRecursivelyUsingPreorderBlock:(id)arg1;
@end

//@interface IDEWorkspace : IDEXMLPackageContainer
@interface IDEWorkspace : NSObject
@end


@interface IDESchemeCommand : NSObject
@property(readonly, nonatomic) NSString *commandNameGerund;
@property(readonly, nonatomic) NSString *commandName;
@end

@interface IDEBuildParameters : NSObject
@property(readonly) IDESchemeCommand *schemeCommand;
@end


@interface IDEBuildOperation : NSObject
@property(readonly) IDEBuildParameters *buildParameters;
@property(readonly) int purpose;
@end

@interface IDEWorkspaceArena : NSObject
@property(readonly) IDEWorkspace *workspace;
@end

@interface IDEExecutionEnvironment : NSObject
@property(readonly) IDEActivityLogSection *latestBuildLog;
@property(readonly) IDEWorkspaceArena *workspaceArena;
@end




static YouCanDoIt *sharedPlugin;

@interface YouCanDoIt()

@property (nonatomic, strong, readwrite) NSWindow *currentPopoverWindow;
@property (nonatomic, strong, readwrite) AVPlayerView *playerView;

@property (nonatomic, strong, readwrite) NSBundle *bundle;
@property (nonatomic, assign, readwrite) NSInteger failCount;
@property (nonatomic, assign, readwrite) NSInteger currentDoitIndex;

@end

@implementation YouCanDoIt

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

+ (instancetype)sharedPlugin
{
    return sharedPlugin;
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource access
        self.bundle = plugin;

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        NSString *buildFinished = @"ExecutionEnvironmentLastUserInitiatedBuildCompletedNotification";
        [center addObserver:self selector:@selector(didFinishBuild:) name:buildFinished object:nil];

     }
    return self;
}

static NSArray *
YCDIFindFailureLogSections(IDEActivityLogSection *section) {
    NSMutableArray *sections = [NSMutableArray new];
    if (section.totalNumberOfErrors > 0) {
        if (section.subsections) {
            for (IDEActivityLogSection *subsection in section.subsections) {
                [sections addObjectsFromArray:YCDIFindFailureLogSections(subsection)];
            }
        } else {
            [sections addObject:section];
        }
    }
    return sections;
}

- (void)didFinishBuild:(NSNotification *)notification
{
    IDEExecutionEnvironment *environment = (IDEExecutionEnvironment *)notification.object;
    IDEActivityLogSection *log = environment.latestBuildLog;
    BOOL failed = YCDIFindFailureLogSections(log).count > 0;

    if (failed) {
        self.failCount++;

        if (self.failCount == 3) {
            [self showDoItWindow];
            self.failCount = 0;
        }

        return;
    }

    self.failCount = 0;
}

- (NSURL *)urlForVideo
{
    self.currentDoitIndex++;
    if (self.currentDoitIndex == 9) { self.currentDoitIndex = 0; }

    NSString *name = [@"doit" stringByAppendingFormat:@"%@", @(self.currentDoitIndex)];
    return [self.bundle URLForResource:name withExtension:@"mp4"];
}

- (void)showDoItWindow
{
    if (!self.currentPopoverWindow && !self.playerView) {
        CGRect contentSize = CGRectMake(20, 20, 340, 220);
        NSWindow *window = [[NSWindow alloc] initWithContentRect: contentSize styleMask:NSBorderlessWindowMask
                                                         backing:NSBackingStoreBuffered defer:NO];

        AVPlayerView *playerView = [[AVPlayerView alloc] initWithFrame:contentSize];
        playerView.controlsStyle = AVPlayerViewControlsStyleNone;

        window.contentView = playerView;
        window.level = NSFloatingWindowLevel;

        self.currentPopoverWindow = window;
        self.playerView = playerView;
    }

    AVPlayer *player = [AVPlayer playerWithURL:[self urlForVideo]];
    player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    player.volume = 1;

    self.playerView.player = player;
    [player play];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:player.currentItem];


    [self.currentPopoverWindow fadeIn:self];
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    AVPlayerItem *player = [notification object];

    [self.currentPopoverWindow fadeOut:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:player];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
