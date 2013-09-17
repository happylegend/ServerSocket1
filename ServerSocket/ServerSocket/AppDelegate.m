//
//  AppDelegate.m
//  ServerSocket
//
//  Created by 紫冬 on 13-9-16.
//  Copyright (c) 2013年 qsji. All rights reserved.
//

#import "AppDelegate.h"

CFWriteStreamRef writeStream;

@implementation AppDelegate

- (void)dealloc
{
    [_window release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    //创建服务器端
    
    return YES;
}

//创建服务器端
-(void)createServerSocket
{
    //第一步创建CFSocketRef对象
    _socket = CFSocketCreate(kCFAllocatorDefault,       //内存分配类型一般为默认KCFAllocatorDefault
                             PF_INET,                   //协议族,一般为Ipv4:PF_INET,(Ipv6,PF_INET6)
                             SOCK_STREAM,               //套接字类型TCP:SOCK_STREAM    UDP:SOCK_DGRAM
                                                        /*
                                                         在Socket中提供了两种类型：SOCK_STREAM和SOCK_DGRAM。
                                                         SOCK_STREAM表明数据像字符流一样通过Socket；
                                                         而SOCK_DGRAM则表明数据以数据报（Datagrams）的形式通过Socket
                                                         */
                             
                             IPPROTO_TCP,               //套接字协议TCP:IPPROTO_TCP    UDP:IPPROTO_UDP;
                             kCFSocketAcceptCallBack,   //回调事件触发类型
                                                        /*
                                                         Enum CFSocketCallBACKType
                                                        {
                                                             KCFSocketNoCallBack = 0,
                                                             KCFSocketReadCallBack =1,
                                                             KCFSocketAcceptCallBack = 2,(常用)
                                                             KCFSocketDtatCallBack = 3,
                                                             KCFSocketConnectCallBack = 4,
                                                             KCFSocketWriteCallBack = 8
                                                         }
                                                        */
                             TCPServerAcceptCallBack,   //触发时调用的函数
                             NULL);
    
    if (_socket == NULL)
    {
        NSLog(@"Cannot create socket");
        return;
    }
    
    
    //第二步：初始化，对socket进行定义设置
    int optval = 1;
    setsockopt(CFSocketGetNative(_socket),    //返回系统原生套接字,补齐缺省
               SOL_SOCKET,
               SO_REUSEADDR,                  //允许重用本地地址和端口
               (void *)&optval,
               sizeof(optval));
    
    
    //第三步：为服务器端的socket绑定地址和端口
    struct sockaddr_in addr4;      // 定义监听地址以及端口
    int port = 8888;
    memset(&addr4, 0, sizeof(addr4));
    addr4.sin_len = sizeof(addr4);
    
    /*
     有两种类型可供读者选择：AF_UNIX和AF_INET，它们代表Socket的地址格式。
     如果选择AF_UNIX，意味着需要为Socket提供一个类似Unix路径的名称，
     这个选项主要用于本地程序之间的socket通讯；本文主要讲解网络通讯，所以需要选择参数AF_INET。
     */
    addr4.sin_family = AF_INET;
    addr4.sin_port = htons(port);
    addr4.sin_addr.s_addr = htons(INADDR_ANY);
    
    CFDataRef address = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&addr4, sizeof(addr4));
    int result = CFSocketSetAddress(_socket, address);  //服务器端的socket绑定地址和端口
    if (kCFSocketSuccess != result)
    {
        NSLog(@"绑定地址失败");
        
        if (_socket)
        {
            CFRelease(_socket);
            
            _socket = NULL;
        }
            
        return;
    }
    
    
    //第四步：执行，即创建一个包含socket的运行循环源对象，将该对象加入到当前运行循环中
    CFRunLoopRef runLoopRef = CFRunLoopGetCurrent();
    CFRunLoopSourceRef sourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);
    CFRunLoopAddSource(runLoopRef, sourceRef, kCFRunLoopCommonModes);
    CFRelease(sourceRef);
}

//socke回调函数，类似客户端，该函数会在接收到客户端请求连接时触发
static void TCPServerAcceptCallBack(CFSocketRef socket,
                                    CFSocketCallBackType type,
                                    CFDataRef address,
                                    const void *data,       //与回调函数有关的特殊数据指针，
                                                            //对于接受连接请求事件，这个指针指向该socket的句柄，
                                                            //对于连接事件，则指向Sint32类型的错误代码
                                   
                                    void*info)              //与套接字关联的自定义的任意数据
{
    if (kCFSocketAcceptCallBack == type)
    {
        //本地套接字句柄
        CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
        
        //输出来访者地址
        uint8_t name[255];
        socklen_t nameLen = sizeof(name);
        
        if (getpeername(nativeSocketHandle, (struct sockaddr *)name, &nameLen) != 0)
        {
            NSLog(@"error");
            exit(1);
        }
        NSLog(@"%s connected.", inet_ntoa( ((struct sockaddr_in*)name)->sin_addr ));
        
        
        //创建一个可读可写的socket连接
        CFWriteStreamRef outputStream;
        CFReadStreamRef inputStream;
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &inputStream, &outputStream);
        if (inputStream && outputStream)
        {
            CFStreamClientContext streamContext = {0, NULL, NULL, NULL};
            if (!CFReadStreamSetClient(inputStream,
                                       kCFStreamEventHasBytesAvailable,  //有可用数据则执行
                                       readDataFromStream,               // 回调函数，当有可读的数据时调用
                                       &streamContext))
            {
                exit(1);
            }
            
            if (!CFWriteStreamSetClient(outputStream,                    //为流指定一个在运行循环中接受回调的客户端
                                       kCFStreamEventCanAcceptBytes,     //输出流准备完毕，可输出
                                       writeDataToStream,                //设置写入时候的函数
                                       &streamContext))
            {
                exit(1);
            }
            
            CFReadStreamScheduleWithRunLoop(inputStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
            
            CFWriteStreamScheduleWithRunLoop(outputStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
            
            CFReadStreamOpen(inputStream);
            CFWriteStreamOpen(outputStream);
        }
        else
        {
            close(nativeSocketHandle);
        }
    }
}


//读取数据，触发式，被动技能
void readDataFromStream(CFReadStreamRef stream,CFStreamEventType eventType, void *clientCallBackInfo) {
    
    UInt8 buff[255];
    
    CFReadStreamRead(stream, buff, 255);
    
    printf("received: %s", buff);
    
}

//写入流操作（仍然被动技能，在输出流准备好的时候调用）
void writeDataToStream (CFWriteStreamRef stream, CFStreamEventType eventType, void *clientCallBackInfo) {
    
    writeStream = stream;
    
}

//主动输出,在输出流准备好之后才能调用
void FucForWrite()
{
    const UInt8 buff[] = "Hunter21,this is Overlord";
    if (writeStream != NULL)
    {
        int length = sizeof(buff)/sizeof(UInt8) + 1;
        CFWriteStreamWrite(writeStream,buff,length);
    }
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
