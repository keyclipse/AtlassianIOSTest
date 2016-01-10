//
//  AtlassianTestIOSTests.m
//  AtlassianTestIOSTests
//
//  Created by Samuel Kitono on 9/01/2016.
//  Copyright © 2016 Samuel Kitono. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "JSONCreatorFromMessage.h"

@interface AtlassianTestIOSTests : XCTestCase

@end

@implementation AtlassianTestIOSTests

- (NSDictionary *) createDictionaryFromJSON:(NSString *) jsonMessage{
    NSError *jsonError;
    NSData *objectData = [jsonMessage dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:objectData
                                                         options:NSJSONReadingMutableContainers
                                                           error:&jsonError];
    if (jsonError) {
        return nil;
    }
    return json;
}

- (BOOL) assertStringArray:(NSArray *) stringArray withMatchStringArray:(NSArray *) matchStringArray{
    
    if (stringArray.count != matchStringArray.count) {
        return NO;
    }
    
    for (int i = 0; i < stringArray.count; i++) {
        NSString * string = stringArray[i];
        NSString * match = matchStringArray[i];
        if (![string isEqualToString:match]) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL) assertDictionaryArray:(NSArray *) dictionaryArray withMatchDictionaryArray:(NSArray *) matchDictionaryArray{
    if (dictionaryArray.count != matchDictionaryArray.count) {
        return NO;
    }
    
    for (int i = 0; i < dictionaryArray.count; i++) {
        NSDictionary * dictionary = dictionaryArray[i];
        NSDictionary * matchDictionary = matchDictionaryArray[i];
        if (![dictionary isEqualToDictionary:matchDictionary]) {
            return NO;
        }
    }
    
    return YES;
}

-(void)testNull{
    NSString * jsonMessage = [JSONCreatorFromMessage createJSONFromChatMessage:nil];
    XCTAssert(jsonMessage == nil, @"Test Null");
}

-(void)testMentions {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.\
    
    //@bob @john (success) such a cool feature; https://twitter.com/jdorfman/status/430511497475670016
    NSString * jsonMessage = [JSONCreatorFromMessage createJSONFromChatMessage:@"@bob @john @lina @jeffrey"];
    NSDictionary * jsonDictionary = [self createDictionaryFromJSON:jsonMessage];
    
    
    NSArray * mentions = jsonDictionary[@"mentions"];

    BOOL mentionTest = [self assertStringArray:mentions withMatchStringArray:@[@"bob",@"john",@"lina",@"jeffrey"]];
    XCTAssert(mentionTest, @"Mention Test");
    
    BOOL falseMentionTest = [self assertStringArray:mentions withMatchStringArray:@[@"bob",@"john",@"linali",@"jeffrey"]];
    XCTAssert(!falseMentionTest, @"False Mention Test");
}

-(void)testEmoticons {
    NSString * jsonMessage = [JSONCreatorFromMessage createJSONFromChatMessage:@"(success) (failure) (smile) (happy)"];
    NSDictionary * jsonDictionary = [self createDictionaryFromJSON:jsonMessage];
    
    NSArray * emoticons = jsonDictionary[@"emoticons"];

    BOOL emoticonTest = [self assertStringArray:emoticons withMatchStringArray:@[@"success",@"failure",@"smile",@"happy"]];
    XCTAssert(emoticonTest, @"Emoticon Test");
    
    BOOL falseEmoticonTest = [self assertStringArray:emoticons withMatchStringArray:@[@"success",@"failure",@"bloated",@"happy"]];
    XCTAssert(!falseEmoticonTest, @"False Emoticon Test");
}

-(void) testLinks {
    NSString * jsonMessage = [JSONCreatorFromMessage createJSONFromChatMessage:@"https://twitter.com/jdorfman/status/430511497475670016 google.com http://www.twitter.com"];
    NSDictionary * jsonDictionary = [self createDictionaryFromJSON:jsonMessage];
    
    NSArray * links = jsonDictionary[@"links"];
    
    
    NSArray * dictArray = @[@{
                                @"url":@"https://twitter.com/jdorfman/status/430511497475670016",
                                @"title":@"Justin Dorfman on Twitter: &quot;nice @littlebigdetail from @HipChat (shows hex colors when pasted in chat). http://t.co/7cI6Gjy5pq&quot;"
                                },
                            @{
                                @"url":@"google.com",
                                @"title":@"Google"
                                },
                            @{
                                @"url":@"http://www.twitter.com",
                                @"title":@"Welcome to Twitter - Login or Sign up"
                                }

                            ];
    
    NSArray * falseDictArray = @[@{
                                @"url":@"https://twitter.com/jdorfman/status/430511497475670016",
                                @"title":@"Justin Dorfman on Twitter: &quot;nice @littlebigdetail from @HipChat (shows hex colors when pasted in chat). http://t.co/7cI6Gjy5pq&quot;"
                                },
                            @{
                                @"url":@"google.com",
                                @"title":@"Google Google"
                                },
                            @{
                                @"url":@"http://www.twitter.com",
                                @"title":@"Twitter"
                                }
                            
                            ];
    
    BOOL linkTest = [self assertDictionaryArray:links withMatchDictionaryArray:dictArray];
    XCTAssert(linkTest, @"Links Test");
    
    BOOL falseLinkTest = [self assertDictionaryArray:links withMatchDictionaryArray:falseDictArray];
    XCTAssert(!falseLinkTest, @"False Links Test");
}



- (void)testCompleteMessage {
    NSString * jsonMessage = [JSONCreatorFromMessage createJSONFromChatMessage:@"@bob @john (success) such a cool feature; https://twitter.com/jdorfman/status/430511497475670016"];
    NSDictionary * jsonDictionary = [self createDictionaryFromJSON:jsonMessage];
    
    
    NSArray * mentions = jsonDictionary[@"mentions"];
    NSArray * emoticons = jsonDictionary[@"emoticons"];
    NSArray * links = jsonDictionary[@"links"];
    
    BOOL mentionTest = [self assertStringArray:mentions withMatchStringArray:@[@"bob",@"john"]];
    XCTAssert(mentionTest, @"Mention Test");
    
    BOOL emoticonTest = [self assertStringArray:emoticons withMatchStringArray:@[@"success"]];
    XCTAssert(emoticonTest, @"Emoticon Test");
    
    NSArray * dictArray = @[@{
                                @"url":@"https://twitter.com/jdorfman/status/430511497475670016",
                                @"title":@"Justin Dorfman on Twitter: &quot;nice @littlebigdetail from @HipChat (shows hex colors when pasted in chat). http://t.co/7cI6Gjy5pq&quot;"
                                }];
    
    BOOL linkTest = [self assertDictionaryArray:links withMatchDictionaryArray:dictArray];
    XCTAssert(linkTest, @"Links Test");
}




@end
