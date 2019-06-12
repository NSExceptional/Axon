#import "AXNManager.h"
#import "Tweak.h"

@implementation AXNManager

+(instancetype)sharedInstance {
    static AXNManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [AXNManager alloc];
        sharedInstance.names = [NSMutableDictionary new];
        sharedInstance.timestamps = [NSMutableDictionary new];
        sharedInstance.notificationRequests = [NSMutableDictionary new];
        sharedInstance.iconStore = [NSMutableDictionary new];
        sharedInstance.backgroundColorCache = [NSMutableDictionary new];
        sharedInstance.textColorCache = [NSMutableDictionary new];
        sharedInstance.fallbackColor = [UIColor whiteColor];
    });
    return sharedInstance;
}

-(id)init {
    return [AXNManager sharedInstance];
}

-(UIImage *)getIcon:(NSString *)bundleIdentifier {
    if (self.iconStore[bundleIdentifier]) return self.iconStore[bundleIdentifier];

    SBIconModel *model = [[(SBIconController *)[NSClassFromString(@"SBIconController") sharedInstance] homescreenIconViewMap] iconModel];
    SBIcon *icon = [model applicationIconForBundleIdentifier:bundleIdentifier];
    UIImage *image = [icon getIconImage:2];

    if (!image) {
        for (int i = 0; i < [self.notificationRequests[bundleIdentifier] count]; i++) {
            NCNotificationRequest *request = self.notificationRequests[bundleIdentifier][i];
            if ([request.sectionIdentifier isEqualToString:bundleIdentifier] && request.content && request.content.icon) {
                image = request.content.icon;
                break;
            }
        }
    }

    if (!image) {
        icon = [model applicationIconForBundleIdentifier:@"com.apple.Preferences"];
        image = [icon getIconImage:2];
    }

    if (!image) {
        image = [UIImage _applicationIconImageForBundleIdentifier:bundleIdentifier format:0 scale:[UIScreen mainScreen].scale];
    }

    if (image) {
        self.iconStore[bundleIdentifier] = [image copy];
    }

    return image ?: [UIImage new];
}

-(void)clearAll:(NSString *)bundleIdentifier {
    if (self.view && self.notificationRequests[bundleIdentifier]) {
        [self.view.dispatcher destination:nil requestsClearingNotificationRequests:self.notificationRequests[bundleIdentifier]];
    }
}

-(void)insertNotificationRequest:(NCNotificationRequest *)req {
    if (!req || ![req notificationIdentifier] || !req.bulletin || !req.bulletin.sectionID) return;
    NSString *bundleIdentifier = req.bulletin.sectionID;

    if (req.content && req.content.header) {
        self.names[bundleIdentifier] = [req.content.header copy];
    }

    if (req.timestamp) {
        if (!self.timestamps[bundleIdentifier] || [req.timestamp compare:self.timestamps[bundleIdentifier]] == NSOrderedDescending) {
            self.timestamps[bundleIdentifier] = [req.timestamp copy];
        }

        if (!self.latestRequest || [req.timestamp compare:self.latestRequest.timestamp] == NSOrderedDescending) {
            self.latestRequest = req;
        }
    }

    if (self.notificationRequests[bundleIdentifier]) {
        BOOL found = NO;
        for (int i = 0; i < [self.notificationRequests[bundleIdentifier] count]; i++) {
            NCNotificationRequest *request = self.notificationRequests[bundleIdentifier][i];
            if (request && [[req notificationIdentifier] isEqualToString:[request notificationIdentifier]]) {
                found = YES;
                break;
            }
        }

        if (!found) [self.notificationRequests[bundleIdentifier] addObject:req];
    } else {
        self.notificationRequests[bundleIdentifier] = [NSMutableArray new];
        [self.notificationRequests[bundleIdentifier] addObject:req];
    }
}

-(void)removeNotificationRequest:(NCNotificationRequest *)req {
    if (!req || ![req notificationIdentifier] || !req.bulletin || !req.bulletin.sectionID) return;
    NSString *bundleIdentifier = req.bulletin.sectionID;

    if (self.latestRequest && [[self.latestRequest notificationIdentifier] isEqualToString:[req notificationIdentifier]]) {
        self.latestRequest = nil;
    }

    if (self.notificationRequests[bundleIdentifier]) {
        for (int i = 0; i < [self.notificationRequests[bundleIdentifier] count]; i++) {
            NCNotificationRequest *request = self.notificationRequests[bundleIdentifier][i];
            if (request && [[req notificationIdentifier] isEqualToString:[request notificationIdentifier]]) {
                [self.notificationRequests[bundleIdentifier] removeObject:request];
            }
        }
    }
}

-(void)modifyNotificationRequest:(NCNotificationRequest *)req {
    if (!req || ![req notificationIdentifier] || !req.bulletin || !req.bulletin.sectionID) return;
    NSString *bundleIdentifier = req.bulletin.sectionID;

    if (self.latestRequest && [[self.latestRequest notificationIdentifier] isEqualToString:[req notificationIdentifier]]) {
        self.latestRequest = req;
    }

    if (self.notificationRequests[bundleIdentifier]) {
        for (int i = 0; i < [self.notificationRequests[bundleIdentifier] count]; i++) {
            NCNotificationRequest *request = self.notificationRequests[bundleIdentifier][i];
            if (request && [request notificationIdentifier] && [[req notificationIdentifier] isEqualToString:[request notificationIdentifier]]) {
                [self.notificationRequests[bundleIdentifier] removeObjectAtIndex:i];
                [self.notificationRequests[bundleIdentifier] insertObject:req atIndex:i];
                return;
            }
        }
    }
}

-(void)setLatestRequest:(NCNotificationRequest *)request {
    _latestRequest = request;

    if (self.view.showingLatestRequest) {
        [self.view reset];
    }
}

@end
