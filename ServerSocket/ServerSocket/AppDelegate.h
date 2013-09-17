//
//  AppDelegate.h
//  ServerSocket
//
//  Created by 紫冬 on 13-9-16.
//  Copyright (c) 2013年 qsji. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
{
    CFSocketRef _socket;
}

@property (strong, nonatomic) UIWindow *window;

@end
