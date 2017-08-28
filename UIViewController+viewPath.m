//
//  UIViewController+viewPath.m
//  TestForJenkins
//
//  Created by dvt04 on 17/8/23.
//  Copyright © 2017年 suma. All rights reserved.
//

#import "UIViewController+viewPath.h"
#import <objc/runtime.h>

#if EnableUserActionCollect

#import "TSUserActionCollectAdapter.h"

#if IS_IPHONE
#import "TSAVPlayer4iPhoneViewController.h" // iPhone
#import "TSTabBarController.h"
#import "TSGDHomeViewController.h"
#else
#import "TSAVPlayerViewController.h" // ipad
#import "RDVTabBarController.h"
#endif

#import "TSHomeViewController.h"
#import "TSSplashViewController.h"

#endif

static UIViewController *currentViewController;
static UIViewController *previousViewController;

@implementation UIViewController (viewPath)

+ (void)load
{
    Method viewWillAppear = class_getInstanceMethod(self, @selector(viewWillAppear:));
    Method new_viewWillAppear = class_getInstanceMethod(self, @selector(hook_viewWillAppear:));
    method_exchangeImplementations(viewWillAppear, new_viewWillAppear);

    Method viewWillDisappear = class_getInstanceMethod(self, @selector(viewWillDisappear:));
    Method new_viewWillDisappear = class_getInstanceMethod(self, @selector(hook_viewWillDisappear:));
    method_exchangeImplementations(viewWillDisappear, new_viewWillDisappear);
}

- (void)hook_viewWillAppear:(BOOL)animated
{
#if EnableUserActionCollect
    // 获取当前页面信息
    [self getCurrentViewInfo];
    
    // 发送数据采集信息
#if IS_IPHONE
    [self setupViewInfo4UserAction];
#else
    [self setupViewInfo4UserActionByiPad];
#endif
    
#endif
}

- (void)hook_viewWillDisappear:(BOOL)animated
{
#if EnableUserActionCollect
    // 页面退出时保存该页面信息，作为下一个页面的源路径
    previousViewController = self;

#endif
}

#pragma mark - 数据采集

#if EnableUserActionCollect

- (void)getCurrentViewInfo
{
    if ([self isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)self;
        currentViewController = nav.topViewController;
    } else {
#if IS_IPHONE
        if ([self isKindOfClass:[TSTabBarController class]]) {
            TSTabBarController *tabBarController = (TSTabBarController *)self;
            if ([tabBarController.selectedViewController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *nav = (UINavigationController *)tabBarController.selectedViewController;
                currentViewController = nav.topViewController;
            }
        }
#else
        if ([self isKindOfClass:[RDVTabBarController class]]) {
            RDVTabBarController *tabBarController = (RDVTabBarController *)self;
            if ([tabBarController.selectedViewController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *nav = (UINavigationController *)tabBarController.selectedViewController;
                currentViewController = nav.topViewController;
            }
        }
#endif
        else {
            currentViewController = self;
        }
    }
}

#if IS_IPHONE

- (void)setupViewInfo4UserAction
{
    NSString *recommendId = @"";
    NSString *viewName = @"";
    __block NSString *assetId = @"";
    
    if (TS_IS_STR_NOT_NIL(currentViewController.navigationItem.title)) {
        viewName = currentViewController.navigationItem.title;
    }
    
    if ([UIApplication sharedApplication].keyWindow.rootViewController == nil ||
        [[UIApplication sharedApplication].keyWindow.rootViewController isKindOfClass:[TSSplashViewController class]]) {
        // 进入应用后再进行数据采集（即忽略启动页面和广告页面）
        return;
    }
    
    if (([previousViewController isKindOfClass:[TSGDHomeViewController class]] ||
         [previousViewController isKindOfClass:[TSHomeViewController class]])
        && [currentViewController isKindOfClass:[TSAVPlayer4iPhoneViewController class]]) {
        // 如果是从首页进入点播播放页，则将recommendId置为推荐位ID;若不是从推荐位传过来的，则recommendId设为0
        if ([previousViewController isKindOfClass:[TSHomeViewController class]]) {
            // 获取推荐位id
            TSHomeViewController *homeViewController = (TSHomeViewController *)previousViewController;
            id curRecommendId = [homeViewController valueForKey:@"recommendId"];
            recommendId = [curRecommendId stringValue];
        }
        // TODO:广东新版首页待完善
    } else {
        recommendId = @"0";
    }
    
    NSLog(@"viewPath DataSource ----- previousViewController is %@ ", previousViewController);
    NSLog(@"viewPath DataSource ----- currentViewController is %@, name is :%@", currentViewController, self.navigationItem.title);
    
    if ([currentViewController isKindOfClass:[TSAVPlayer4iPhoneViewController class]]) {
        // 如果当前是点播页面，则传点播assetId
        TSAVPlayer4iPhoneViewController *player = (TSAVPlayer4iPhoneViewController *)self;
        // KVC获取当前播放节目的类型
        id type = [player valueForKey:@"authType"];
        if ([type integerValue] == AVPlayerAuthTypeVod) {
            // KVC获取点播节目的programId
            NSString *programId = [player valueForKey:@"programId"];
            // 通过programId获取点播的assetId
            [[TSVodUtil sharedSingleton] getProgramInfoWithProgramId:programId assetID:@"" providerID:@"" completed:^(TSVodInfo *vodInfo, NSError *error) {
                assetId = vodInfo.assetID;
                // 发送数据采集信息
                [self sendUserActionWithViewName:viewName assetId:assetId recommendId:recommendId];

                return ;
            }];
        }
    }
    // 发送数据采集信息
    [self sendUserActionWithViewName:viewName assetId:assetId recommendId:recommendId];
}

#else

- (void)setupViewInfo4UserActionByiPad
{
    NSString *recommendId = @"";
    NSString *viewName = @"";
    __block NSString *assetId = @"";
    
    if (TS_IS_STR_NOT_NIL(currentViewController.navigationItem.title)) {
        viewName = currentViewController.navigationItem.title;
    }
    
    if ([UIApplication sharedApplication].keyWindow.rootViewController == nil ||
        [[UIApplication sharedApplication].keyWindow.rootViewController isKindOfClass:[TSSplashViewController class]]) {
        // 进入应用后再进行数据采集（即忽略启动页面和广告页面）
        return;
    }
    
    if ([previousViewController isKindOfClass:[TSHomeViewController class]]
        && [currentViewController isKindOfClass:[TSAVPlayerViewController class]]) {
        // 如果是从首页进入点播播放页，则将recommendId置为推荐位ID;若不是从推荐位传过来的，则recommendId设为0
        if ([previousViewController isKindOfClass:[TSHomeViewController class]]) {
            // 获取推荐位id
            TSHomeViewController *homeViewController = (TSHomeViewController *)previousViewController;
            id curRecommendId = [homeViewController valueForKey:@"recommendId"];
            recommendId = [curRecommendId stringValue];
        }
    } else {
        recommendId = @"0";
    }
    
    NSLog(@"viewPath DataSource ----- previousViewController is %@ ", previousViewController);
    NSLog(@"viewPath DataSource ----- currentViewController is %@, name is :%@", currentViewController, self.navigationItem.title);
    
    if ([currentViewController isKindOfClass:[TSAVPlayerViewController class]]) {
        // 如果当前是点播页面，则传点播assetId
        TSAVPlayerViewController *player = (TSAVPlayerViewController *)self;
        // KVC获取当前播放节目的类型
        id type = [player valueForKey:@"authType"];
        if ([type integerValue] == AVPlayerAuthTypeVod) {
            // KVC获取点播节目的programId
            NSString *programId = [player valueForKey:@"programId"];
            // 通过programId获取点播的assetId
            [[TSVodUtil sharedSingleton] getProgramInfoWithProgramId:programId assetID:@"" providerID:@"" completed:^(TSVodInfo *vodInfo, NSError *error) {
                assetId = vodInfo.assetID;
                // 发送数据采集信息
                [self sendUserActionWithViewName:viewName assetId:assetId recommendId:recommendId];
                
                return ;
            }];
        }
    }
    // 发送数据采集信息
    [self sendUserActionWithViewName:viewName assetId:assetId recommendId:recommendId];
}

#endif

- (void)sendUserActionWithViewName:(NSString *)viewName assetId:(NSString *)assetId recommendId:(NSString *)recommendId
{
    // 拼装数据
    TSViewInfo4UserAction *viewInfo = [[TSViewInfo4UserAction alloc] init];
    viewInfo.currentViewPath = NSStringFromClass([currentViewController class]);
    viewInfo.sourceViewPath = NSStringFromClass([previousViewController class]);
    viewInfo.viewName = viewName;
    viewInfo.assetId = assetId;
    viewInfo.recommendId = recommendId;
    
    // 发送页面信息
    [[TSUserActionCollectAdapter sharedSingleTon] postPageViewMsg:viewInfo complete:^(id response, NSError *error) {
        
    }];
}

#endif

@end
