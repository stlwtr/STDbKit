//
//  NSString+STDbHandle.m
//  STDbKit
//
//  Created by stlwtr on 15/3/4.
//  Copyright (c) 2015年stlwtr. All rights reserved.
//

#import "NSString+STDbHandle.h"
#import "NSData+STDbHandle.h"

@implementation NSString (STDbHandle)

- (NSData *)base64Data;
{
    NSString *encoding = [self copy];
    
    NSData *data = nil;
    unsigned char *decodedBytes = NULL;
    @try {
#define __ 255
        static char decodingTable[256] = {
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x00 - 0x0F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x10 - 0x1F
            __,__,__,__, __,__,__,__, __,__,__,62, __,__,__,63,  // 0x20 - 0x2F
            52,53,54,55, 56,57,58,59, 60,61,__,__, __, 0,__,__,  // 0x30 - 0x3F
            __, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,  // 0x40 - 0x4F
            15,16,17,18, 19,20,21,22, 23,24,25,__, __,__,__,__,  // 0x50 - 0x5F
            __,26,27,28, 29,30,31,32, 33,34,35,36, 37,38,39,40,  // 0x60 - 0x6F
            41,42,43,44, 45,46,47,48, 49,50,51,__, __,__,__,__,  // 0x70 - 0x7F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x80 - 0x8F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x90 - 0x9F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xA0 - 0xAF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xB0 - 0xBF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xC0 - 0xCF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xD0 - 0xDF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xE0 - 0xEF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xF0 - 0xFF
        };
        encoding = [encoding stringByReplacingOccurrencesOfString:@"=" withString:@""];
        NSData *encodedData = [encoding dataUsingEncoding:NSASCIIStringEncoding];
        unsigned char *encodedBytes = (unsigned char *)[encodedData bytes];
        
        NSUInteger encodedLength = [encodedData length];
        NSUInteger encodedBlocks = (encodedLength+3) >> 2;
        NSUInteger expectedDataLength = encodedBlocks * 3;
        
        unsigned char decodingBlock[4];
        
        decodedBytes = malloc(expectedDataLength);
        if( decodedBytes != NULL ) {
            
            NSUInteger i = 0;
            NSUInteger j = 0;
            NSUInteger k = 0;
            unsigned char c;
            while( i < encodedLength ) {
                c = decodingTable[encodedBytes[i]];
                i++;
                if( c != __ ) {
                    decodingBlock[j] = c;
                    j++;
                    if( j == 4 ) {
                        decodedBytes[k] = (decodingBlock[0] << 2) | (decodingBlock[1] >> 4);
                        decodedBytes[k+1] = (decodingBlock[1] << 4) | (decodingBlock[2] >> 2);
                        decodedBytes[k+2] = (decodingBlock[2] << 6) | (decodingBlock[3]);
                        j = 0;
                        k += 3;
                    }
                }
            }
            
            // Process left over bytes, if any
            if( j == 3 ) {
                decodedBytes[k] = (decodingBlock[0] << 2) | (decodingBlock[1] >> 4);
                decodedBytes[k+1] = (decodingBlock[1] << 4) | (decodingBlock[2] >> 2);
                k += 2;
            } else if( j == 2 ) {
                decodedBytes[k] = (decodingBlock[0] << 2) | (decodingBlock[1] >> 4);
                k += 1;
            }
            data = [[NSData alloc] initWithBytes:decodedBytes length:k];
        }
    }
    @catch (NSException *exception) {
        data = nil;
        NSLog(@"WARNING: error occured while decoding base 32 string: %@", exception);
    }
    @finally {
        if( decodedBytes != NULL ) {
            free( decodedBytes );
        }
    }
    return data;
}

- (NSString *)encryptWithKey:(NSString *)key;
{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
    NSData *eData = [data aes256EncryptWithKey:key];
    NSString *base64String = [eData base64String];
    return base64String;
}

- (NSString *)decryptWithKey:(NSString *)key;
{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
    NSData *eData = [data aes256DecryptWithKey:key];
    NSString *base64String = [eData base64String];
    return base64String;
}

@end