//
//  JSONCreatorFromMessage.h
//  AtlassianTest
//
//  Created by Samuel Kitono on 6/01/2016.
//  Copyright © 2016 Samuel Kitono. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^finishParsingJSONBlock)(NSString *);

@interface JSONCreatorFromMessage : NSObject

+(NSString *) createJSONFromChatMessage:(NSString *) chatMessage;
+(void) createJSONFromChatMessage:(NSString *)chatMessage withBlock:(finishParsingJSONBlock)finishBlock;

@end
