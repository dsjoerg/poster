//
//  PosterAppDelegate.m
//  Poster
//
//  Created by David Joerg on 2/11/14.
//  Copyright (c) 2014 David Joerg. All rights reserved.
//

#import "PosterAppDelegate.h"
#import "AnalyticsRequest.h"

#define SEGMENTIO_API_URL [NSURL URLWithString:@"http://hopscotch-analytics.herokuapp.com/api/v1/events/upload"]
#define API_TOKEN @"142770c83ab725d73d7008c4e37ffbe596541db8cad15a2a036edf85dfa352733a480137d12638ffb1b626bbf2c4d5a2b1a1a10b81100fdf77942d17490ff435"

dispatch_queue_t _serialQueue;
NSMutableArray *queue;
NSArray *batch;

static NSString *GenerateUUIDString() {
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    NSString *UUIDString = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return UUIDString;
}

// Async Utils
dispatch_queue_t dispatch_queue_create_specific(const char *label, dispatch_queue_attr_t attr) {
    dispatch_queue_t queue = dispatch_queue_create(label, attr);
    dispatch_queue_set_specific(queue, (__bridge const void *)queue, (__bridge void *)queue, NULL);
    return queue;
}

BOOL dispatch_is_on_specific_queue(dispatch_queue_t queue) {
    return dispatch_get_specific((__bridge const void *)queue) != NULL;
}

void dispatch_specific(dispatch_queue_t queue, dispatch_block_t block, BOOL waitForCompletion) {
    if (dispatch_get_specific((__bridge const void *)queue)) {
        block();
    } else if (waitForCompletion) {
        dispatch_sync(queue, block);
    } else {
        dispatch_async(queue, block);
    }
}

void dispatch_specific_async(dispatch_queue_t queue, dispatch_block_t block) {
    dispatch_specific(queue, block, NO);
}

void dispatch_specific_sync(dispatch_queue_t queue, dispatch_block_t block) {
    dispatch_specific(queue, block, YES);
}



@implementation PosterAppDelegate

- (void)dispatchBackground:(void(^)(void))block {
    dispatch_specific_async(_serialQueue, block);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];

    
    _serialQueue = dispatch_queue_create_specific("io.segment.analytics", DISPATCH_QUEUE_SERIAL);

    queue = [[NSMutableArray alloc] init];
    NSString *event = @"user_tenure";
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    [properties setValue:@1 forKey:@"tenure"];
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:event forKey:@"event"];
    [dictionary setValue:properties forKey:@"properties"];
    
    NSMutableDictionary *eventPayload = [NSMutableDictionary dictionaryWithDictionary:dictionary];
    eventPayload[@"action"] = @"track";
    eventPayload[@"timestamp"] = [[NSDate date] description];
    eventPayload[@"requestId"] = GenerateUUIDString();
    [eventPayload setValue:@"abcde" forKey:@"userId"];
    [eventPayload setValue:@"12345" forKey:@"sessionId"];

    
    [queue addObject:eventPayload];
    
    batch = [NSArray arrayWithArray:queue];

    NSMutableDictionary *payloadDictionary = [NSMutableDictionary dictionary];
    [payloadDictionary setObject:[[NSDate date] description] forKey:@"requestTimestamp"];
    [payloadDictionary setObject:API_TOKEN forKey:@"api_token"];
    [payloadDictionary setObject:batch forKey:@"batch"];

    
    NSData *serverPayload = [NSJSONSerialization dataWithJSONObject:payloadDictionary
                                                      options:0 error:NULL];


    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:SEGMENTIO_API_URL];
    [urlRequest setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setHTTPBody:serverPayload];
    NSLog(@"%@ Sending batch API request.", self);
    __block AnalyticsRequest *request = [AnalyticsRequest startWithURLRequest:urlRequest completion:^{
        [self dispatchBackground:^{
            if (request.error) {
                NSLog(@"%@ API request had an error: %@", self, request.error);
            } else {
                NSLog(@"%@ API request success 200. request=%@", self, request);
            }
        }];
    }];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
