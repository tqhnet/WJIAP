//
//  TTIPAManager.m
//  YJCloudLesson
//
//  Created by Lam_TT on 2018/11/22.
//  Copyright © 2018年 com.YJTC. All rights reserved.
//

#import "TTIPAManager.h"
#import "OrderApi.h"
#import "SecureUDID.h"
@interface TTIPAManager()<SKPaymentTransactionObserver,SKProductsRequestDelegate>{
    NSString           *_purchID;
    IAPCompletionHandle _handle;
}

@end

@implementation TTIPAManager

#pragma mark - ♻️life cycle
+ (instancetype)shareSIAPManager{
    
    static TTIPAManager *IAPManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        IAPManager = [[TTIPAManager alloc] init];
    });
    return IAPManager;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        // 购买监听写在程序入口,程序挂起时移除监听,这样如果有未完成的订单将会自动执行并回调 paymentQueue:updatedTransactions:方法
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}


#pragma mark - 🚪public
- (void)startPurchWithID:(NSString *)purchID completeHandle:(IAPCompletionHandle)handle{
    if (purchID) {
        if ([SKPaymentQueue canMakePayments]) {
            // 开始购买服务
            _purchID = purchID;
            _handle = handle;
            NSSet *nsset = [NSSet setWithArray:@[purchID]];
            SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
            request.delegate = self;
            [request start];
        }else{
            [self handleActionWithType:SIAPPurchNotArrow data:nil];
        }
    }
}

#pragma mark - 🔒private
- (void)handleActionWithType:(SIAPPurchType)type data:(NSData *)data{
#if DEBUG
    switch (type) {
        case SIAPPurchSuccess:
            NSLog(@"购买成功");
            break;
        case SIAPPurchFailed:
            NSLog(@"购买失败");
            break;
        case SIAPPurchCancle:
            NSLog(@"用户取消购买");
            break;
        case SIAPPurchVerFailed:
            NSLog(@"订单校验失败");
            break;
        case SIAPPurchVerSuccess:
            NSLog(@"订单校验成功");
            break;
        case SIAPPurchNotArrow:
            NSLog(@"不允许程序内付费");
            break;
        default:
            break;
    }
#endif
    if(_handle){
        _handle(type,data);
    }
}
#pragma mark - 🍐delegate

// 交易结束
- (void)completeTransaction:(SKPaymentTransaction *)transaction{
    DLog(@"交易结束");
    // Your application should implement these two methods.
    NSString * productIdentifier = transaction.payment.productIdentifier;
    if ([productIdentifier length] > 0) {
        // 向自己的服务器验证购买凭证
    }
    
    [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:YES];
}

// 交易失败
- (void)failedTransaction:(SKPaymentTransaction *)transaction{
    DLog(@"交易失败");
    if (transaction.error.code != SKErrorPaymentCancelled) {
        [self handleActionWithType:SIAPPurchFailed data:nil];
    }else{
        [self handleActionWithType:SIAPPurchCancle data:nil];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)verifyPurchaseWithPaymentTransaction:(SKPaymentTransaction *)transaction isTestServer:(BOOL)flag{
    //交易验证
    DLog(@"交易验证");
    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    
    if(!receipt){
        // 交易凭证为空验证失败
        [self handleActionWithType:SIAPPurchVerFailed data:nil];
        return;
    }
    
    NSError *error;
    NSDictionary *requestContents = @{
                                      @"receipt-data": [receipt base64EncodedStringWithOptions:0]
                                      };
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                                          options:0
                                                            error:&error];
    
    if (!requestData) {
        //交易凭证为空验证失败
        [self handleActionWithType:SIAPPurchVerFailed data:nil];
        return;
    }
    
    
    //向服务器发送凭证验证
   
    NSMutableDictionary * dic = [NSMutableDictionary new];
    [dic setObject:[receipt base64EncodedStringWithOptions:0] forKey:@"receipt-data"];
    if (IsLogin) {
        //已登录
         NSString * userId = [UserInfo share].userInfoModel.ID;
         [dic setObject:userId forKey:KuserId];
    }else{
        // no Login
        NSString * bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        NSString * identifier = [SecureUDID UDIDForDomain:bundleIdentifier usingKey:KSecuirutyUDIDValue];
//        DLog(@"udid = %@",identifier);
//        [dic setObject:identifier forKey:@"map"];
    }
    
    [self verificationReceiptRequestWithPaymentTransaction:transaction Dic:dic];
    
    return ;
    
    
    //以下是本地验单------
    
    //In the test environment, use https://sandbox.itunes.apple.com/verifyReceipt
    //In the real environment, use https://buy.itunes.apple.com/verifyReceipt
    
//    NSString *serverString = @"https://buy.itunes.apple.com/verifyReceipt";
//    if (flag) {
//        serverString = @"https://sandbox.itunes.apple.com/verifyReceipt";
//    }
//    NSURL *storeURL = [NSURL URLWithString:serverString];
//    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
//    [storeRequest setHTTPMethod:@"POST"];
//    [storeRequest setHTTPBody:requestData];
//    storeRequest.timeoutInterval = 30;
//    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
//
//    [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
//                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
//                               if (connectionError) {
//                                   // 无法连接服务器,购买校验失败
//                                   [self handleActionWithType:SIAPPurchVerFailed data:nil];
//                               } else {
//                                   NSError *error;
//                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data
//                                                                                                options:0
//                                                                                                  error:&error];
//                                   if (!jsonResponse) {
//                                       // 苹果服务器校验数据返回为空校验失败
//                                       [self handleActionWithType:SIAPPurchVerFailed data:nil];
//                                   }
//
//                                   // 先验证正式服务器,如果正式服务器返回21007再去苹果测试服务器验证,沙盒测试环境苹果用的是测试服务器
//                                   NSString *status = [NSString stringWithFormat:@"%@",jsonResponse[@"status"]];
//                                   if (status && [status isEqualToString:@"21007"]) {
//                                       [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:YES];
//                                   }else if(status && [status isEqualToString:@"0"]){
//                                       [self handleActionWithType:SIAPPurchVerSuccess data:nil];
//                                   }
//#if DEBUG
//                                   NSLog(@"----验证结果 %@",jsonResponse);
//#endif
//                               }
//                           }];
//
//
//    // 验证成功与否都注销交易,否则会出现虚假凭证信息一直验证不通过,每次进程序都得输入苹果账号
//    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

#pragma mark - SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    NSArray *product = response.products;
    if([product count] <= 0){
        [ToastView dismiss];
#if DEBUG
        NSLog(@"--------------没有商品------------------");
#endif
        return;
    }
    
    SKProduct *p = nil;
    for(SKProduct *pro in product){
        if([pro.productIdentifier isEqualToString:_purchID]){
            p = pro;
            break;
        }
    }
    
#if DEBUG
    NSLog(@"productID:%@", response.invalidProductIdentifiers);
    NSLog(@"产品付费数量:%lu",(unsigned long)[product count]);
    NSLog(@"%@",[p description]);
    NSLog(@"%@",[p localizedTitle]);
    NSLog(@"%@",[p localizedDescription]);
    NSLog(@"%@",[p price]);
    NSLog(@"%@",[p productIdentifier]);
    NSLog(@"发送购买请求");
#endif
    
    SKPayment *payment = [SKPayment paymentWithProduct:p];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

//请求失败
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    [ToastView dismiss];
    [ToastView showErrorWithStatus:error.localizedDescription];
#if DEBUG
    NSLog(@"------------------错误-----------------:%@", error);
#endif
}

- (void)requestDidFinish:(SKRequest *)request{
   
#if DEBUG
    NSLog(@"------------反馈信息结束-----------------");
#endif
}


#pragma mark - SKPaymentTransactionObserver
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
    for (SKPaymentTransaction *tran in transactions) {
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:tran];
                break;
            case SKPaymentTransactionStatePurchasing:
#if DEBUG
                NSLog(@"商品添加进列表");
#endif
                break;
            case SKPaymentTransactionStateRestored:
#if DEBUG
                NSLog(@"已经购买过商品");
#endif
                // 消耗型不支持恢复购买
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:tran];
                break;
            default:
                break;
        }
    }
}
#pragma mark --  向后台验证凭证
- (void)verificationReceiptRequestWithPaymentTransaction:(SKPaymentTransaction *)transaction  Dic:(NSMutableDictionary *)dic{
    
    [ToastView showWithStatus:@"验证中"];
    if (IsLogin) {
        //已登录用户充值验证
        [OrderApi verificationProductRequest:dic
                                     Success:^(id responseObject) {
                                         [ToastView dismiss];
                                         // 购买成功将交易凭证发送给服务端进行再次校验
                                         [self handleActionWithType:SIAPPurchVerSuccess data:nil];
                                         
                                     } Fail:^(NSString *msg) {
                                         [ToastView dismiss];
                                         [ToastView showErrorWithStatus:msg];
                                         [self handleActionWithType:SIAPPurchVerFailed data:nil];
                                         //订单校验失败，保存在本地。  只能在这里写代码。
                                         [self saveOrderDataArrayWithDataSource:dic];
                                     }];
    }else{
        //匿名充值验证
        [OrderApi touristVerificationProductRequest:dic
                                            Success:^(id responseObject) {
                                                [ToastView dismiss];
                                                //保存充值记录到本地
                                                [self saveTouUpRecordToLocalArrayWithDataSource:responseObject];
                                                
                                                // 购买成功将交易凭证发送给服务端进行再次校验
                                                [self handleActionWithType:SIAPPurchVerSuccess data:nil];
                                               
                                            } Fail:^(NSString *msg) {
                                                [ToastView dismiss];
                                                [ToastView showErrorWithStatus:msg];
                                                [self handleActionWithType:SIAPPurchVerFailed data:nil];
                                                //订单校验失败，保存在本地。  只能在这里写代码。
                                                [self saveOrderDataArrayWithDataSource:dic];
                                            }];
    }
  
    // 验证成功与否都注销交易,否则会出现虚假凭证信息一直验证不通过,每次进程序都得输入苹果账号
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

/**
 订单校验失败，归档在本地。

 @param dic 失败的数据
 */
- (void)saveOrderDataArrayWithDataSource:(NSMutableDictionary *)dic{
    
    NSString * filePath = [kCachePath stringByAppendingPathComponent:KOrderVertifyFailArray];
    NSMutableArray * array = [NSMutableArray arrayWithArray:[KeyedUnarchiver getKeyedUnarchiverWithFilePath:filePath]];
    [array addObject:dic];
    //归档
    [KeyedUnarchiver saveKeyedUnarchiverWithArray:array
                                         FilePath:filePath];
}

/**
 检查是否存在异常失败订单,如果存在，则再次发送验证单
 */
- (void)checkIsFailOrder{
    
    NSString * filePath = [kCachePath stringByAppendingPathComponent:KOrderVertifyFailArray];
    NSMutableArray * array = [NSMutableArray arrayWithArray:[KeyedUnarchiver getKeyedUnarchiverWithFilePath:filePath]];
    if (array.count == 0) {
        return;
    }
    
    DLog(@"异常订单数 ===== %lu",(unsigned long)array.count);
//    DLog(@"异常订单 ===== %@",array);
    
    for (NSDictionary * dataSource in array) {
        if (IsLogin) {
            //已登录用户
            NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithDictionary:dataSource];
            if (![[dataSource allKeys] containsObject:KuserId]) {
                //但是是在未登录时候 充值的。所以要加上UserID
                NSString * userId = [UserInfo share].userInfoModel.ID;
                [dic setObject:userId forKey:KuserId];
            }
            [OrderApi verificationProductRequest:dic
                                         Success:^(id responseObject) {
                                             [array removeObject:dataSource];
                                             [KeyedUnarchiver saveKeyedUnarchiverWithArray:array
                                                                                  FilePath:filePath];
                                         } Fail:^(NSString *msg) {
                                             
                                         }];
        }else{
            //游客
            if ([[dataSource allKeys] containsObject:KuserId]) {
                //但是是在登录时候充值的。所以需要调用已登录用户的验证接口
                [OrderApi verificationProductRequest:(NSMutableDictionary *)dataSource
                                             Success:^(id responseObject) {
                                                 [array removeObject:dataSource];
                                                 [KeyedUnarchiver saveKeyedUnarchiverWithArray:array
                                                                                      FilePath:filePath];
                                             } Fail:^(NSString *msg) {
                                                 
                                             }];
            }else{
                //始终是游客
                [OrderApi touristVerificationProductRequest:(NSMutableDictionary *)dataSource
                                                    Success:^(id responseObject) {
                                                        [array removeObject:dataSource];
                                                        [KeyedUnarchiver saveKeyedUnarchiverWithArray:array
                                                                                             FilePath:filePath];
                                                        //保存充值记录到本地
                                                        [self saveTouUpRecordToLocalArrayWithDataSource:responseObject];
                                                    } Fail:^(NSString *msg) {
                                                        
                                                    }];
            }
        }
    }
}



#pragma mark - 保存充值记录到本地
/**
 游客匿名充值成功记录保存，归档在本地。
 
 @param dic 充值的数据
 */
- (void)saveTouUpRecordToLocalArrayWithDataSource:(NSMutableDictionary *)dic{
   
    NSString * filePath = [kCachePath stringByAppendingPathComponent:KTouristTouUpRecordArray];
    NSMutableArray * array = [NSMutableArray arrayWithArray:[KeyedUnarchiver getKeyedUnarchiverWithFilePath:filePath]];
    [array addObject:dic];
    //归档
    [KeyedUnarchiver saveKeyedUnarchiverWithArray:array
                                         FilePath:filePath];
}

@end

