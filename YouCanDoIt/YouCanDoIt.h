//
//  YouCanDoIt.h
//  YouCanDoIt
//
//  Created by Orta on 11/26/15.
//  Copyright © 2015 Orta. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface YouCanDoIt : NSObject

+ (instancetype)sharedPlugin;

@property (nonatomic, strong, readonly) NSBundle* bundle;
@end