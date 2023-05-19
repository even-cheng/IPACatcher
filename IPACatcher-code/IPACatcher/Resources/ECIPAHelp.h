//
//  ECIPAHelp.h
//  IPACatcher
//
//  Created by Even on 2023/5/12.
//  Copyright © 2023 Daniel Radtke. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ECIPAHelp : NSObject

+ (NSDictionary * _Nullable)getMobileProvisionFromIpa:(NSURL *)ipaUrl savePath:(NSURL *)savePath;

@end

NS_ASSUME_NONNULL_END
