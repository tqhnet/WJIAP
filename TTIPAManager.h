//
//  TTIPAManager.h
//  YJCloudLesson
//
//  Created by Lam_TT on 2018/11/22.
//  Copyright © 2018年 com.YJTC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
/**
 内购管理
 */

typedef enum {
    SIAPPurchSuccess = 0,       // 购买成功
    SIAPPurchFailed = 1,        // 购买失败
    SIAPPurchCancle = 2,        // 取消购买
    SIAPPurchVerFailed = 3,     // 订单校验失败
    SIAPPurchVerSuccess = 4,    // 订单校验成功
    SIAPPurchNotArrow = 5,      // 不允许内购
}SIAPPurchType;

typedef void (^IAPCompletionHandle)(SIAPPurchType type,NSData *data);

@interface TTIPAManager : NSObject

+ (instancetype)shareSIAPManager;
//开始内购
- (void)startPurchWithID:(NSString *)purchID completeHandle:(IAPCompletionHandle)handle;


/**
 检查是否存在异常失败订单
 */
- (void)checkIsFailOrder;
@end
