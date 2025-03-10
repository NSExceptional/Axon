#import "Tweak.h"
#import "AXNManager.h"

BOOL dpkgInvalid = NO;
BOOL initialized = NO;
BOOL enabled;
BOOL badgesEnabled;
BOOL badgesShowBackground;
BOOL hapticFeedback;
BOOL darkMode;
NSInteger sortingMode;
NSInteger selectionStyle;
NSInteger style;
NSInteger showByDefault;
NCNotificationCombinedListViewController *clvc = nil;
SBDashBoardCombinedListViewController *sbclvc = nil;
NCNotificationDispatcher *dispatcher = nil;

%group Axon

#pragma mark Legibility color

%hook SBFLockScreenDateView

-(id)initWithFrame:(CGRect)arg1 {
    %orig;
    if (self.legibilitySettings && self.legibilitySettings.primaryColor) {
        [AXNManager sharedInstance].fallbackColor = [self.legibilitySettings.primaryColor copy];
    }
    return self;
}

-(void)setLegibilitySettings:(_UILegibilitySettings *)arg1 {
    %orig;
    if (self.legibilitySettings && self.legibilitySettings.primaryColor) {
        [AXNManager sharedInstance].fallbackColor = [self.legibilitySettings.primaryColor copy];
    }
}

%end

#pragma mark Store dispatcher for future use

%hook SBNCNotificationDispatcher

-(id)init {
    %orig;
    dispatcher = self.dispatcher;
    if ([AXNManager sharedInstance].view) [AXNManager sharedInstance].view.dispatcher = dispatcher;
    return self;
}

-(void)setDispatcher:(NCNotificationDispatcher *)arg1 {
    %orig;
    dispatcher = arg1;
    if ([AXNManager sharedInstance].view) [AXNManager sharedInstance].view.dispatcher = arg1;
}

%end

#pragma mark Inject the Axon view into NC

%hook SBDashBoardNotificationAdjunctListViewController

%property (nonatomic, retain) AXNView *axnView;

-(void)viewDidLoad {
    %orig;

    if (!initialized) {
        initialized = YES;
        UIStackView *stackView = [self valueForKey:@"_stackView"];
        self.axnView = [[AXNView alloc] initWithFrame:CGRectMake(0,0,64,90)];
        self.axnView.translatesAutoresizingMaskIntoConstraints = NO;
        self.axnView.hapticFeedback = hapticFeedback;
        self.axnView.badgesEnabled = badgesEnabled;
        self.axnView.badgesShowBackground = badgesShowBackground;
        self.axnView.selectionStyle = selectionStyle;
        self.axnView.style = style;
        self.axnView.sortingMode = sortingMode;
        self.axnView.darkMode = darkMode;
        self.axnView.showByDefault = showByDefault;
        [AXNManager sharedInstance].view = self.axnView;

        if (clvc) [AXNManager sharedInstance].view.clvc = clvc;
        if (sbclvc) [AXNManager sharedInstance].view.sbclvc = sbclvc;
        if (dispatcher) [AXNManager sharedInstance].view.dispatcher = dispatcher;

        [stackView addArrangedSubview:self.axnView];

        [NSLayoutConstraint activateConstraints:@[
            [self.axnView.centerXAnchor constraintEqualToAnchor:stackView.centerXAnchor],
            [self.axnView.leadingAnchor constraintEqualToAnchor:stackView.leadingAnchor constant:10],
            [self.axnView.trailingAnchor constraintEqualToAnchor:stackView.trailingAnchor constant:-10],
            [self.axnView.heightAnchor constraintEqualToConstant:90]
        ]];
    }
}

/* This is used to make the Axon view last, e.g. when media controls are presented. */

-(void)_updatePresentingContent {
    %orig;
    UIStackView *stackView = [self valueForKey:@"_stackView"];
    [stackView removeArrangedSubview:self.axnView];
    [stackView addArrangedSubview:self.axnView];
}

-(void)_insertItem:(id)arg1 animated:(BOOL)arg2 {
    %orig;
    UIStackView *stackView = [self valueForKey:@"_stackView"];
    [stackView removeArrangedSubview:self.axnView];
    [stackView addArrangedSubview:self.axnView];
}

/* Let Springboard know we have a little surprise for it. */

-(BOOL)isPresentingContent {
    return YES;
}

%end

#pragma mark Store SBDashBoardCombinedListViewController for future use

%hook SBDashBoardCombinedListViewController

-(void)viewDidLoad{
    %orig;
    sbclvc = self;
    if ([AXNManager sharedInstance].view) [AXNManager sharedInstance].view.sbclvc = self;
}

%end

#pragma mark Notification management

%hook NCNotificationCombinedListViewController

%property (nonatomic,assign) BOOL axnAllowChanges;

/* Store this object for future use. */

-(id)init {
    %orig;
    clvc = self;
    if ([AXNManager sharedInstance].view) [AXNManager sharedInstance].view.clvc = self;
    self.axnAllowChanges = NO;
    return self;
}

/* Replace notification management functions with our logic. */

-(bool)insertNotificationRequest:(NCNotificationRequest *)req forCoalescedNotification:(id)arg2 {
    if (self.axnAllowChanges) return %orig;     // This condition is true when Axon is updating filtered notifications for display.
    [[AXNManager sharedInstance] insertNotificationRequest:req];
    [[AXNManager sharedInstance].view refresh];

    if (req.bulletin.sectionID) {
        NSString *bundleIdentifier = req.bulletin.sectionID;
        if ([bundleIdentifier isEqualToString:[AXNManager sharedInstance].view.selectedBundleIdentifier]) %orig;
    }

    if (![AXNManager sharedInstance].view.selectedBundleIdentifier && showByDefault == 1) {
        [[AXNManager sharedInstance].view reset];
    }

    return YES;
}

-(bool)removeNotificationRequest:(NCNotificationRequest *)req forCoalescedNotification:(id)arg2 {
    if (self.axnAllowChanges) return %orig;     // This condition is true when Axon is updating filtered notifications for display.

    NSString *identifier = [[req notificationIdentifier] copy];

    [[AXNManager sharedInstance] removeNotificationRequest:req];
    [[AXNManager sharedInstance].view refresh];

    if (req.bulletin.sectionID) {
        NSString *bundleIdentifier = req.bulletin.sectionID;
        if ([bundleIdentifier isEqualToString:[AXNManager sharedInstance].view.selectedBundleIdentifier]) %orig;
    }

    if ([AXNManager sharedInstance].view.showingLatestRequest && identifier &&
    [[[AXNManager sharedInstance].latestRequest notificationIdentifier] isEqualToString:identifier]) {
        %orig;
    }

    return YES;
}

-(bool)modifyNotificationRequest:(NCNotificationRequest *)req forCoalescedNotification:(id)arg2 {
    if (self.axnAllowChanges) return %orig;     // This condition is true when Axon is updating filtered notifications for display.
    
    NSString *identifier = [[req notificationIdentifier] copy];

    [[AXNManager sharedInstance] modifyNotificationRequest:req];
    [[AXNManager sharedInstance].view refresh];

    if (req.bulletin.sectionID) {
        NSString *bundleIdentifier = req.bulletin.sectionID;
        if ([bundleIdentifier isEqualToString:[AXNManager sharedInstance].view.selectedBundleIdentifier]) %orig;
    }

    if ([AXNManager sharedInstance].view.showingLatestRequest && identifier &&
    [[[AXNManager sharedInstance].latestRequest notificationIdentifier] isEqualToString:identifier]) {
        %orig;
    }

    return YES;
}

-(bool)hasContent {
    if ([AXNManager sharedInstance].view.list && [[AXNManager sharedInstance].view.list count] > 0) return YES;
    return %orig;
}

-(void)viewDidAppear:(BOOL)animated {
    %orig;
    [[AXNManager sharedInstance].view reset];
    [[AXNManager sharedInstance].view refresh];
}

/* Fix pull to clear all tweaks. */

-(void)_clearAllPriorityListNotificationRequests {
    [dispatcher destination:nil requestsClearingNotificationRequests:[self allNotificationRequests]];
}

-(void)_clearAllNotificationRequests {
    [dispatcher destination:nil requestsClearingNotificationRequests:[self allNotificationRequests]];
}

-(void)clearAll {
    [dispatcher destination:nil requestsClearingNotificationRequests:[self axnNotificationRequests]];
}

/* Compatibility thing for other tweaks. */

%new
-(id)axnNotificationRequests {
    NSMutableOrderedSet *allRequests = [NSMutableOrderedSet new];
    for (NSString *key in [[AXNManager sharedInstance].notificationRequests allKeys]) {
        [allRequests addObjectsFromArray:[AXNManager sharedInstance].notificationRequests[key]];
    }
    return allRequests;
}

%end

#pragma mark Compatibility stuff

%hook NCNotificationListViewController

/* FastUnlockX */

-(BOOL)hasVisibleContent {
    if (sbclvc) return [sbclvc hasContent];
    return %orig;
}

%end

%hook SparkAutoUnlockX

/* The only way I know of... AutoUnlockX */

-(BOOL)externalBlocksUnlock {
    if (sbclvc && [sbclvc hasContent]) return [sbclvc hasContent];
    return %orig;
}

%end

%hook NCNotificationListSectionRevealHintView

/* Hide "No older notifications." */

-(void)layoutSubviews {
    %orig;
    MSHookIvar<UILabel *>(self, "_revealHintTitle").hidden = YES;
}

%end

%hook SBDashBoardViewController

/* Hide all notifications on open. */

-(void)viewWillAppear:(BOOL)animated {
    %orig;
    [[AXNManager sharedInstance].view reset];
    [[AXNManager sharedInstance].view refresh];
}

%end

%end

/* Hide all notifications on open. */

static void displayStatusChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[AXNManager sharedInstance].view reset];
    [[AXNManager sharedInstance].view refresh];
}

%ctor {
    HBPreferences *preferences = [[HBPreferences alloc] initWithIdentifier:@"me.nepeta.axon"];
    [preferences registerBool:&enabled default:YES forKey:@"Enabled"];
    [preferences registerBool:&hapticFeedback default:YES forKey:@"HapticFeedback"];
    [preferences registerBool:&badgesEnabled default:YES forKey:@"BadgesEnabled"];
    [preferences registerBool:&badgesShowBackground default:YES forKey:@"BadgesShowBackground"];
    [preferences registerBool:&darkMode default:NO forKey:@"DarkMode"];
    [preferences registerInteger:&sortingMode default:0 forKey:@"SortingMode"];
    [preferences registerInteger:&selectionStyle default:0 forKey:@"SelectionStyle"];
    [preferences registerInteger:&style default:0 forKey:@"Style"];
    [preferences registerInteger:&showByDefault default:0 forKey:@"ShowByDefault"];
    [preferences registerPreferenceChangeBlock:^() {
        if (initialized && [AXNManager sharedInstance].view) {
            [AXNManager sharedInstance].view.hapticFeedback = hapticFeedback;
            [AXNManager sharedInstance].view.badgesEnabled = badgesEnabled;
            [AXNManager sharedInstance].view.badgesShowBackground = badgesShowBackground;
            [AXNManager sharedInstance].view.selectionStyle = selectionStyle;
            [AXNManager sharedInstance].view.sortingMode = sortingMode;
            [AXNManager sharedInstance].view.style = style;
            [AXNManager sharedInstance].view.darkMode = darkMode;
            [AXNManager sharedInstance].view.showByDefault = showByDefault;
        }
    }];
}
