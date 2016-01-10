//
//  JSONCreatorFromMessage.m
//  AtlassianTest
//
//  Created by Samuel Kitono on 6/01/2016.
//  Copyright © 2016 Samuel Kitono. All rights reserved.
//

#import "JSONCreatorFromMessage.h"

#define kMentionsDictionaryKey @"mentions"
#define kEmoticonsDictionaryKey @"emoticons"
#define kLinksDictionaryKey @"links"
#define kURLDictionaryKey @"url"
#define kTitleDictionaryKey @"title"



@implementation JSONCreatorFromMessage

+(NSMutableArray *) createOrGetArrayFromDictionary:(NSMutableDictionary *) dictionary withKey:(NSString *) key{
    
    NSMutableArray * finalArray = dictionary[key];
    if (finalArray == nil) {
        finalArray = [NSMutableArray new];
        dictionary[key] = finalArray;
    }

    return finalArray;
}

+(NSString *) createJSONStringFromDictionary:(NSDictionary *) dictionary{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:0
                                                         error:&error];
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
        return nil;
    }
    
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSASCIIStringEncoding];
    return jsonString;
}

+(BOOL) validateStringAsURL:(NSString *) inputString{

    NSUInteger length = [inputString length];
    // Empty strings should return NO
    if (length > 0) {
        NSError *error = nil;
        NSDataDetector *dataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
        if (dataDetector && !error) {
            NSRange range = NSMakeRange(0, length);
            NSRange notFoundRange = (NSRange){NSNotFound, 0};
            NSRange linkRange = [dataDetector rangeOfFirstMatchInString:inputString options:0 range:range];
            if (!NSEqualRanges(notFoundRange, linkRange) && NSEqualRanges(range, linkRange)) {
                return YES;
            }
        }
        else {
            NSLog(@"Could not create link data detector: %@ %@", [error localizedDescription], [error userInfo]);
        }
    }
    return NO;
}

//find title from the html string we find
+(void) getTitleFromURL:(NSURL *) url withCompletionBlock:(void (^)(NSError * error, NSString * titleString))completionBlock{
    
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithURL:url
            completionHandler:^(NSData *data,
                                NSURLResponse *response,
                                NSError *error) {

                NSString *htmlCode = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSString * start = @"<title>";
                NSRange range1 = [htmlCode rangeOfString:start];
                
                NSString * end = @"</title>";
                NSRange range2 = [htmlCode rangeOfString:end];
                
                NSString * titleString = [htmlCode substringWithRange:NSMakeRange(range1.location + 7, range2.location - range1.location - 7)];
                
                if (completionBlock) {
                    completionBlock(error,titleString);
                }
            }] resume];

}


//create dictionary object for each link encountered
+(void) createDictionaryForURLString:(NSString *) urlString withCompletionBlock:(void (^)(NSDictionary * dictionary)) completionBlock{
    
    
    
    NSURL * url = nil;
    if ([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"https://"]) {
        url = [NSURL URLWithString:urlString];
    }else{
        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@",urlString]];
    }
    
    
    
    [self getTitleFromURL:url withCompletionBlock:^(NSError *error, NSString *titleString) {\
        NSMutableDictionary * linkDictionary = [NSMutableDictionary new];
        linkDictionary[kURLDictionaryKey] = urlString;
        linkDictionary[kTitleDictionaryKey] = titleString;
        if (error == nil) {
            if (completionBlock) {
                completionBlock(linkDictionary);
            }
        }else{
            if (completionBlock) {
                completionBlock(nil);
            }
        }
    }];
}



+(NSString *) createJSONFromChatMessage:(NSString *) chatMessage{
    
    dispatch_queue_t queue;
    queue = dispatch_queue_create("com.Atlassian.MyQueue", NULL);

    
    NSArray * wordArray = [chatMessage componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    //to make sure there is no blank character
    wordArray = [wordArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != ''"]];
    
    NSMutableDictionary * jsonFinalDictionary = [NSMutableDictionary new];
    
    
    int linkCount = 0;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    for (NSString * word in wordArray) {
        NSString * firstCharString = [word substringToIndex:1];
        NSString * lastCharString = [word substringFromIndex:word.length-1];
        
        //now we check if it is mention or emoticons or links else we will do nothing
        if ([firstCharString isEqualToString:@"@"]) {
            NSString * mentionString = [word substringFromIndex:1];
            if(mentionString.length){
                NSMutableArray * mentionArray = [self createOrGetArrayFromDictionary:jsonFinalDictionary withKey:kMentionsDictionaryKey];
                [mentionArray addObject:mentionString];
            }
        }else if ([firstCharString isEqualToString:@"("] && [lastCharString isEqualToString:@")"]){
            NSString * emoticonString = [word substringWithRange:NSMakeRange(1, word.length-2)];
            if (emoticonString.length) {
                NSMutableArray * emoticonArray = [self createOrGetArrayFromDictionary:jsonFinalDictionary withKey:kEmoticonsDictionaryKey];
                [emoticonArray addObject:emoticonString];
            }
        }else if ([self validateStringAsURL:word]){
            NSMutableArray * linksArray = [self createOrGetArrayFromDictionary:jsonFinalDictionary withKey:kLinksDictionaryKey];
            linkCount++;
            
            //To speed up the link parsing process we use GCD blocks to get multiple request called at once
            [self createDictionaryForURLString:word withCompletionBlock:^(NSDictionary * dictionary) {
                //to make sure it is synchronized we use serial queue and semaphores
                dispatch_barrier_async(queue, ^{
                    [linksArray addObject:dictionary];
                    dispatch_semaphore_signal(semaphore);
                });
            }];
        }
    }
    
    //we wait for all dictionary to be created or wait for 20 secs till it fails
    for (int i = 0; i < linkCount; i++) {
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC));
    }
    
    //if there is nothing that can be parsed return nil
    if (jsonFinalDictionary.allKeys.count == 0) {
        return nil;
    }
    
    
    return [self createJSONStringFromDictionary:jsonFinalDictionary];
}

+(void) createJSONFromChatMessage:(NSString *)chatMessage withBlock:(finishParsingJSONBlock)finishBlock{
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        NSString * jsonMessage = [self createJSONFromChatMessage:chatMessage];
        //to make sure this finishblock is executed at main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            finishBlock(jsonMessage);
        });
    });
}

@end
