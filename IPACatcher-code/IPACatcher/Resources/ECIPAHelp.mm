//
//  ECIPAHelp.m
//  IPACatcher
//
//  Created by Even on 2023/5/12.
//  Copyright © 2023 Daniel Radtke. All rights reserved.
//

#import "ECIPAHelp.h"
#import "ZZArchive.h"
#import "ZipZap.h"
#include "dump-ios-mobileprovision.h"

@implementation ECIPAHelp

+ (NSDictionary * _Nullable)getMobileProvisionFromIpa:(NSURL *)ipaUrl savePath:(NSURL *)savePath {
    
    NSError* error;
    ZZArchive* archive = [ZZArchive archiveWithURL:ipaUrl error:&error];
    if (error) {
        return nil;
    }
    for (ZZArchiveEntry * ectry in archive.entries) {
        if ([ectry.fileName hasSuffix:@".mobileprovision"]) {
            NSError* error;
            NSData * data = [ectry newDataWithError:&error];
            if (!error) {
                BOOL res = [data writeToFile:savePath.path atomically:YES];
                if (res) {
                    return [self readMobileProvision: savePath.path];
                }
            }
        }
    }
    
    return nil;
}

+ (NSDictionary * _Nullable)readMobileProvision:(NSString *)prov_path {
    
    char* path = (char*)[prov_path UTF8String];
    OCTET_STRING_t* xml = dumpMobileProvision(path);
    if (xml == NULL) {
        [NSFileManager.defaultManager removeItemAtPath:prov_path error:nil];
        return nil;
    }
    NSError* error;
    NSDictionary* obj = [NSPropertyListSerialization propertyListWithData:[NSData dataWithBytes:xml->buf length:xml->size] options:0 format:0 error:&error];
    
    NSString* AppIDName = [obj objectForKey:@"AppIDName"];
    NSString* TeamName = [obj objectForKey:@"TeamName"];
    NSArray* TeamIdentifier = [obj objectForKey:@"TeamIdentifier"];
    NSDate* ExpirationDate = [obj objectForKey:@"ExpirationDate"];
    NSDate* CreationDate = [obj objectForKey:@"CreationDate"];
    NSString* Name = [obj objectForKey:@"Name"];
    NSString* UUID = [obj objectForKey:@"UUID"];
//    id ProvisionAllDevices = [obj objectForKey:@"ProvisionsAllDevices"];
    NSArray* ProvisionedDevices = [obj objectForKey:@"ProvisionedDevices"];
    NSDictionary* Entitlements = [obj objectForKey:@"Entitlements"];
    NSString* AppID = [Entitlements objectForKey:@"application-identifier"];
    NSString* BundleID = [AppID stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@.", [Entitlements objectForKey:@"com.apple.developer.team-identifier"]] withString:@""];
    NSArray* DeveloperCertificates = [obj objectForKey:@"DeveloperCertificates"];
    NSArray* CerNames = [self paserCertifiers:DeveloperCertificates];
    
    NSDateFormatter *format=[[NSDateFormatter alloc] init];
    format.timeZone = [NSTimeZone systemTimeZone];
    [format setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *startString= [format stringFromDate:CreationDate];
    NSString *endString= [format stringFromDate:ExpirationDate];
    
    NSMutableDictionary* dic = [NSMutableDictionary dictionary];
    dic[@"app_id"] = AppID;
    dic[@"bundle_id"] = BundleID;
    dic[@"name"] = Name;
    dic[@"app_id_name"] = AppIDName;
    dic[@"certificates"] = CerNames;
    dic[@"team"] = TeamName;
    dic[@"team_identifier"] = TeamIdentifier;
    dic[@"create_date"] = startString;
    dic[@"expiration_date"] = endString;
    dic[@"uuid"] = UUID;
    dic[@"device_udids"] = ProvisionedDevices;
    return dic.copy;
}

+ (NSArray *)paserCertifiers:(NSArray *)cers{
    
    NSMutableArray* cer_names = [NSMutableArray array];
    NSString* iphoneDeveloper = @"iPhone Developer";
    NSString* iphoneDistribution = @"iPhone Distribution";
    NSString* appleDeveloper = @"Apple Development";
    for (NSData* content in cers) {
     
        NSString* str = [[NSString alloc]initWithData:content encoding:1];
        NSRange startRange = [str rangeOfString:iphoneDeveloper];
        if (startRange.length == 0) {
            startRange = [str rangeOfString:iphoneDistribution];
        }
        if (startRange.length == 0) {
            startRange = [str rangeOfString:appleDeveloper];
        }
        if (startRange.length == 0) {
            continue;
        }

        NSString* sub_str = [str substringWithRange:NSMakeRange(startRange.location, startRange.length+50)];
        
        NSRange endRange = [sub_str rangeOfString:@")1"];
        
        if (endRange.length > 0) {
            
            NSString* name = [sub_str substringToIndex:endRange.location+1];
            if (name) {
                [cer_names addObject:name];
            }
            
        } else {
            [cer_names addObject:sub_str];
        }
    }
    
    return cer_names.copy;
}

@end
