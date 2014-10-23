//
//  NSDate+Exts.h
//  version:1.0
//
//  更新日期:2013-06-30 20:00
//
//  Created by lishuan yang on 13-6-28.
//  Copyright (c) 2013年 lishuan yang. All rights reserved.
//
//  emailto: 2008.yls@163.com
//  QQ: 603291699
//
/***************************************************************************
 * 格式化日期字符串，常用参数：
 * a: AM/PM (上午/下午)
 * A: 0~86399999 (一天的第A微秒)
 * c/cc: 1~7 (一周的第一天, 周天为1)
 * ccc: Sun/Mon/Tue/Wed/Thu/Fri/Sat (星期几简写)
 * cccc: Sunday/Monday/Tuesday/Wednesday/Thursday/Friday/Saturday (星期几全拼)
 * d: 1~31 (月份的第几天, 带0)
 * D: 1~366 (年份的第几天,带0)
 * e: 1~7 (一周的第几天, 带0)
 * E~EEE: Sun/Mon/Tue/Wed/Thu/Fri/Sat (星期几简写)
 * EEEE: Sunday/Monday/Tuesday/Wednesday/Thursday/Friday/Saturday (星期几全拼)
 * F: 1~5 (每月的第几周, 一周的第一天为周一)
 * g: Julian Day Number (number of days since 4713 BC January 1) 未知
 * G~GGG: BC/AD (Era Designator Abbreviated) 未知
 * GGGG: Before Christ/Anno Domini 未知
 * h: 1~12 (0 padded Hour (12hr)) 带0的时, 12小时制
 * H: 0~23 (0 padded Hour (24hr))  带0的时, 24小时制
 * k: 1~24 (0 padded Hour (24hr) 带0的时, 24小时制
 * K: 0~11 (0 padded Hour (12hr)) 带0的时, 12小时制
 * L/LL: 1~12 (0 padded Month)  第几月
 * LLL: Jan/Feb/Mar/Apr/May/Jun/Jul/Aug/Sep/Oct/Nov/Dec 月份简写
 * LLLL: January/February/March/April/May/June/July/August/September/October/November/December 月份全称
 * m: 0~59 (0 padded Minute) 分钟
 * M/MM: 1~12 (0 padded Month) 第几月
 * MMM: Jan/Feb/Mar/Apr/May/Jun/Jul/Aug/Sep/Oct/Nov/Dec
 * MMMM: January/February/March/April/May/June/July/August/September/October/November/December
 * q/qq: 1~4 (0 padded Quarter) 第几季度
 * qqq: Q1/Q2/Q3/Q4 季度简写
 * qqqq: 1st quarter/2nd quarter/3rd quarter/4th quarter 季度全拼
 * Q/QQ: 1~4 (0 padded Quarter) 同小写
 * QQQ: Q1/Q2/Q3/Q4 同小写
 * QQQQ: 1st quarter/2nd quarter/3rd quarter/4th quarter 同小写
 * s: 0~59 (0 padded Second) 秒数
 * S: (rounded Sub-Second) 未知
 * u: (0 padded Year) 未知
 * v~vvv: (General GMT Timezone Abbreviation) 常规GMT时区的编写
 * vvvv: (General GMT Timezone Name) 常规GMT时区的名称
 * w: 1~53 (0 padded Week of Year, 1st day of week = Sunday, NB: 1st week of year starts from the last Sunday of last year) 一年的第几周, 一周的开始为周日,第一周从去年的最后一个周日起算
 * W: 1~5 (0 padded Week of Month, 1st day of week = Sunday) 一个月的第几周
 * y/yyyy: (Full Year) 完整的年份
 * yy/yyy: (2 Digits Year)  2个数字的年份
 * Y/YYYY: (Full Year, starting from the Sunday of the 1st week of year) 这个年份未知干嘛用的
 * YY/YYY: (2 Digits Year, starting from the Sunday of the 1st week of year) 这个年份未知干嘛用的
 * z~zzz: (Specific GMT Timezone Abbreviation) 指定GMT时区的编写
 * zzzz: (Specific GMT Timezone Name) Z: +0000 (RFC 822 Timezone) 指定GMT时区的名称
 ***************************************************************************/

#import "NSDate+Exts.h"
#import <time.h>
#import <xlocale.h>

@implementation NSDate (Exts)

#pragma mark
#pragma mark - ** 日期类方法 **
+ (id)dateWithString:(NSString *)string
{
    return [NSDate dateWithString:string format:NSDATE_FORMAT_NORMAL locale:LOCALE_CHINA];
}

+ (id)dateWithDateString:(NSString *)string
{
    return [NSDate dateWithString:string format:NSDATE_FORMAT_DATE];
}

+ (id)dateWithTimeString:(NSString *)string
{
    return [NSDate dateWithString:string format:NSDATE_FORMAT_TIME];
}

+ (id)dateWithString:(NSString *)string format:(NSString *)format
{
    return [NSDate dateWithString:string format:format locale:LOCALE_CHINA];
}

+ (id)dateWithString:(NSString *)string locale:(NSLocale *)locale
{
    return [NSDate dateWithString:string format:NSDATE_FORMAT_NORMAL locale:LOCALE_CHINA];
}

+ (id)dateWithString:(NSString *)string format:(NSString *)format locale:(NSLocale *)locale
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:format];
    [dateFormatter setLocale:locale];
    NSDate *retDate = [dateFormatter dateFromString:string];
    return retDate;
}

+ (id)dateFromRFC1123:(NSString *)rfc1123
{
    if(rfc1123 == nil)
        return nil;

    const char *str = [rfc1123 UTF8String];
    const char *fmt;
    NSDate *retDate;
    char *ret;

    fmt = "%a, %d %b %Y %H:%M:%S %Z";
    struct tm rfc1123timeinfo;
    memset(&rfc1123timeinfo, 0, sizeof(rfc1123timeinfo));
    ret = strptime_l(str, fmt, &rfc1123timeinfo, NULL);
    if (ret) {
        time_t rfc1123time = mktime(&rfc1123timeinfo);
        retDate = [NSDate dateWithTimeIntervalSince1970:rfc1123time];
        if (retDate != nil)
            return retDate;
    }


    fmt = "%A, %d-%b-%y %H:%M:%S %Z";
    struct tm rfc850timeinfo;
    memset(&rfc850timeinfo, 0, sizeof(rfc850timeinfo));
    ret = strptime_l(str, fmt, &rfc850timeinfo, NULL);
    if (ret) {
        time_t rfc850time = mktime(&rfc850timeinfo);
        retDate = [NSDate dateWithTimeIntervalSince1970:rfc850time];
        if (retDate != nil)
            return retDate;
    }

    fmt = "%a %b %e %H:%M:%S %Y";
    struct tm asctimeinfo;
    memset(&asctimeinfo, 0, sizeof(asctimeinfo));
    ret = strptime_l(str, fmt, &asctimeinfo, NULL);
    if (ret) {
        time_t asctime = mktime(&asctimeinfo);
        return [NSDate dateWithTimeIntervalSince1970:asctime];
    }

    return nil;
}

- (NSString *)rfc1123String
{
    time_t date = (time_t)[self timeIntervalSince1970];
    struct tm timeinfo;
    gmtime_r(&date, &timeinfo);
    char buffer[32];
    size_t ret = strftime_l(buffer, sizeof(buffer), "%a, %d %b %Y %H:%M:%S GMT", &timeinfo, NULL);
    if (ret) {
        return @(buffer);
    } else {
        return nil;
    }
}

#pragma mark - ** 日期实例方法 **
- (NSDate *)dateByAddingMinutes:(NSInteger)minutes
{
    NSTimeInterval aTimeInterval = [self timeIntervalSinceReferenceDate] + MINUTE_SECONDS * minutes;
	NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:aTimeInterval];
	return newDate;
}

- (NSDate *)dateByAddingHours:(NSInteger)hours
{
    NSTimeInterval aTimeInterval = [self timeIntervalSinceReferenceDate] + HOUR_SECONDS * hours;
	NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:aTimeInterval];
	return newDate;
}

- (NSDate *)dateByAddingDays:(NSInteger)days
{
	NSTimeInterval aTimeInterval = [self timeIntervalSinceReferenceDate] + DAY_SECONDS * days;
	NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:aTimeInterval];
	return newDate;
}

- (NSDate *)dateByAddingMonths:(NSInteger)months
{
    NSDate *date = self;
    NSInteger m = abs(months);
    NSInteger flag = months/m;
    
    for (int i = 0; i < m; i++) {
        NSInteger days = [date daysOfMonth];
        date = [date dateByAddingDays:flag * days];
    }
    return date;
}

- (NSDate *)dateBySetSecond:(NSInteger)second
{
    NSString *dateStr = [self string];
    NSRange range = NSMakeRange(17, 2);
    NSString *yearStr = [NSString stringWithFormat:@"%2d", second];
    dateStr = [dateStr stringByReplacingCharactersInRange:range withString:yearStr];
    NSDate *retDate = [NSDate dateWithString:dateStr];
    return retDate;
}

- (NSDate *)dateBySetMinute:(NSInteger)minute
{
    NSString *dateStr = [self string];
    NSRange range = NSMakeRange(14, 2);
    NSString *yearStr = [NSString stringWithFormat:@"%2d", minute];
    dateStr = [dateStr stringByReplacingCharactersInRange:range withString:yearStr];
    NSDate *retDate = [NSDate dateWithString:dateStr];
    return retDate;
}

- (NSDate *)dateBySetHour:(NSInteger)hour
{
    NSString *dateStr = [self string];
    NSRange range = NSMakeRange(11, 2);
    NSString *yearStr = [NSString stringWithFormat:@"%2d", hour];
    dateStr = [dateStr stringByReplacingCharactersInRange:range withString:yearStr];
    NSDate *retDate = [NSDate dateWithString:dateStr];
    return retDate;
}

- (NSDate *)dateBySetDay:(NSInteger)day
{
    NSString *dateStr = [self string];
    NSRange range = NSMakeRange(8, 2);
    NSString *yearStr = [NSString stringWithFormat:@"%2d", day];
    dateStr = [dateStr stringByReplacingCharactersInRange:range withString:yearStr];
    NSDate *retDate = [NSDate dateWithString:dateStr];
    return retDate;
}

- (NSDate *)dateBySetMonth:(NSInteger)month
{
    NSString *dateStr = [self string];
    NSRange range = NSMakeRange(5, 2);
    NSString *yearStr = [NSString stringWithFormat:@"%2d", month];
    dateStr = [dateStr stringByReplacingCharactersInRange:range withString:yearStr];
    return [NSDate dateWithString:dateStr];
}

- (NSDate *)dateBySetYear:(NSInteger)year
{
    NSString *dateStr = [self string];
    NSRange range = NSMakeRange(0, 4);
    NSString *yearStr = [NSString stringWithFormat:@"%4d", year];
    dateStr = [dateStr stringByReplacingCharactersInRange:range withString:yearStr];
    return [NSDate dateWithString:dateStr];
}

- (NSDate *)dateOfWeekStart
{
    NSInteger nth = [self nthDayOfWeek];
    return [self dateByAddingDays:(1 - nth)];
}

- (NSDate *)dateOfMonthStart
{
    NSInteger nth = [self nthDayOfMonth];
    return [self dateByAddingDays:(1 - nth)];
}

- (NSDate *)dateOfYearStart
{
    NSInteger nth = [self nthDayOfYear];
    return [self dateByAddingDays:(1 - nth)];
}

- (NSDate *)dateOfWeekEnd
{
    NSInteger nth = [self nthDayOfWeek];
    return [self dateByAddingDays:(7 - nth)];
}

- (NSDate *)dateOfMonthEnd
{
    NSInteger nth = [self nthDayOfMonth];
    NSInteger num = [self daysOfMonth];
    return [self dateByAddingDays:(num - nth)];
}

- (NSDate *)dateOfYearEnd
{
    NSInteger nth = [self nthDayOfMonth];
    NSInteger num = [self daysOfYear];
    return [self dateByAddingDays:(num - nth)];
}

#pragma mark - ** 两个日期相隔时间段 **
- (NSInteger)distanceInDaysToDate:(NSDate *)anotherDate
{
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [gregorianCalendar components:NSDayCalendarUnit fromDate:self toDate:anotherDate options:0];
    return components.day;
}

#pragma mark - ** 两个日期相隔时间段、比较两个日期  **
- (BOOL)isBetween:(NSDate *)date1 date2:(NSDate *)date2
{
    NSTimeInterval val1 = [date1 timeIntervalSince1970];
    NSTimeInterval val2 = [date2 timeIntervalSince1970];
    NSTimeInterval val = [self timeIntervalSince1970];
    return abs(val1 - val2) == abs(val - val1) + abs(val - val2);
}

- (NSDate *)dateByIgnoreOption:(NSDateCompareIgnoreOptions)option
{
    BOOL ignoreYear = option & NSDateIgnoreYear ? YES : NO;
    BOOL ignoreMonth = option & NSDateIgnoreMonth ? YES : NO;
    BOOL ignoreDay = option & NSDateIgnoreDay ? YES : NO;
    BOOL ignoreHour = option & NSDateIgnoreHour ? YES : NO;
    BOOL ignoreMinute = option & NSDateIgnoreMin ? YES : NO;
    BOOL ignoreSecond = option & NSDateIgnoreSecond ? YES : NO;
    
    NSDate *retDate = self;
    retDate = ignoreYear ? [self dateBySetYear:REFERENCE_DATE_YEAR] : retDate;
    retDate = ignoreMonth ? [self dateBySetMonth:REFERENCE_DATE_MONTH] : retDate;
    retDate = ignoreDay ? [self dateBySetDay:REFERENCE_DATE_DAY] : retDate;
    retDate = ignoreHour ? [self dateBySetDay:REFERENCE_DATE_HOUR] : retDate;
    retDate = ignoreMinute ? [self dateBySetDay:REFERENCE_DATE_MINUTE] : retDate;
    retDate = ignoreSecond ? [self dateBySetDay:REFERENCE_DATE_SECOND] : retDate;
    
    return retDate;
}

- (BOOL)isBetween:(NSDate *)date1 date2:(NSDate *)date2 ignore:(NSDateCompareIgnoreOptions)option
{
    NSDate *date_1 = [date1 dateByIgnoreOption:option];
    NSDate *date_2 = [date2 dateByIgnoreOption:option];
    NSDate *date_self = [self dateByIgnoreOption:option];
    return [date_self isBetween:date_1 date2:date_2];
}

- (NSComparisonResult)compare:(NSDate *)other ignore:(NSDateCompareIgnoreOptions)option
{
    NSDate *date_1 = [other dateByIgnoreOption:option];
    NSDate *date_self = [self dateByIgnoreOption:option];
    return [date_self compare:date_1];
}

- (BOOL)isEqualToDate:(NSDate *)aDate ignore:(NSDateCompareIgnoreOptions)option
{
    NSDate *date_1 = [aDate dateByIgnoreOption:option];
    NSDate *date_self = [self dateByIgnoreOption:option];
    return [date_self isEqualToDate:date_1];
}

- (BOOL) isWeekend
{
    NSDateComponents *components = [CURRENT_CALENDAR components:NSWeekdayCalendarUnit fromDate:self];
    return  ((components.weekday == 1) || (components.weekday == 7)) ? YES : NO;
}

- (BOOL) isWorkday
{
    return ![self isWeekend];
}

#pragma mark - ** 两个日期相隔时间段 **
- (NSString *)stringWithFormat:(NSString *)format
{
    return [self stringWithFormat:format locale:LOCALE_CHINA];
}

- (NSString *)stringWithFormat:(NSString *)format locale:(NSLocale *)locale
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:format];
    [dateFormatter setLocale:locale];
    NSString *retStr = [dateFormatter stringFromDate:self];
    return retStr;
}

- (NSString *)string
{
    return [self stringWithFormat:NSDATE_FORMAT_NORMAL locale:LOCALE_CHINA];
}

- (NSString *)dateString
{
    return [self stringWithFormat:NSDATE_FORMAT_DATE];
}

- (NSString *)timeString
{
	return [self stringWithFormat:NSDATE_FORMAT_TIME];
}

- (NSString *)stringWithLocale:(NSLocale *)locale
{
    return [self stringWithFormat:NSDATE_FORMAT_NORMAL locale:locale];
}

#pragma mark - ** 纪元、年、月、日、小时、分钟、秒、星期 **
- (NSInteger)era
{
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
	return components.era;
}

- (NSInteger)year
{
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
	return components.year;
}

- (NSInteger)month
{
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
	return components.month;
}

- (NSInteger)day
{
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
	return components.day;
}

- (NSInteger)hour {
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
	return components.hour;
}

- (NSInteger)minute
{
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
	return components.minute;
}

- (NSInteger)second
{
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
	return components.second;
}

- (NSInteger)week
{
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
	return components.week;
}

- (NSInteger)weekday
{
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
	return components.weekday;
}

- (NSInteger)quarter NS_AVAILABLE(10_6, 4_0)
{
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
	return components.quarter;
}

- (NSInteger)weekOfMonth NS_AVAILABLE(10_7, 5_0)
{
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
	return components.weekday;
}

- (NSInteger)weekOfYear NS_AVAILABLE(10_7, 5_0)
{
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
	return components.weekday;
}

- (NSInteger)yearForWeekOfYear NS_AVAILABLE(10_7, 5_0)
{
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
	return components.yearForWeekOfYear;
}

- (BOOL)isLeapYear
{
    NSInteger year = [self year];
    return (year%4 == 0 && year%100 != 0) || year%400 == 0;
}

#pragma mark - ** 第几天 **
- (NSInteger)nthDayOfWeek
{
    return [self weekday];
}

- (NSInteger)nthDayOfMonth
{
    return [self day];
}

- (NSInteger)nthDayOfYear
{
    NSString *nthStr_year = [self stringWithFormat:@"D"];
    return [nthStr_year integerValue];
}

#pragma mark - ** 第几周 **
- (NSInteger)nthWeekOfMonth
{
    NSString *nthStr = [self stringWithFormat:@"W"];
    return [nthStr integerValue];
}

- (NSInteger)nthWeekOfYear
{
    NSString *nthStr = [self stringWithFormat:@"w"];
    return [nthStr integerValue];
}


#pragma mark - ** 第几季度 **
- (NSInteger)nthSeason
{
    NSString *nthStr_season = [self stringWithFormat:@"q"];
    return [nthStr_season integerValue];
}

#pragma mark - ** 天数 **
- (NSInteger)daysOfMonth
{
    NSInteger nthMonth = [self month];
    
    NSInteger days[12] = {  31, 28, 31, 30, 31, 30,
                            31, 31, 30, 31, 30, 31
                         };
    
    if ([self isLeapYear]) {
        return nthMonth == 2 ? 29 : 28;
    }
    return days[nthMonth - 1];
}

- (NSInteger)daysOfYear
{
    return [self isLeapYear] ? 366 : 365;
}

@end
