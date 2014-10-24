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

#import <Foundation/Foundation.h>

// 年、月、日、小时、分钟换算成秒
#define MINUTE_SECONDS  60
#define HOUR_SECONDS    3600
#define DAY_SECONDS     86400
#define WEEK_SECONDS    604800
#define YEAR_SECONDS    31556926

// 参考日期：年、月、日、小时、分钟、秒
#define REFERENCE_DATE_YEAR     1970
#define REFERENCE_DATE_MONTH    1
#define REFERENCE_DATE_DAY      1
#define REFERENCE_DATE_HOUR     0
#define REFERENCE_DATE_MINUTE   0
#define REFERENCE_DATE_SECOND   0

#define DATE_COMPONENTS (kCFCalendarUnitEra | NSYearCalendarUnit| NSMonthCalendarUnit | NSDayCalendarUnit | NSWeekCalendarUnit |  NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit | NSWeekdayCalendarUnit | NSWeekdayOrdinalCalendarUnit)
#define CURRENT_CALENDAR [NSCalendar currentCalendar]

// 日期字符串常用格式，NSDATE_FORMAT_NORMAL为默认格式。
#define NSDATE_FORMAT_NORMAL    @"yyyy-MM-dd HH:mm:ss"
#define NSDATE_FORMAT_NORMAL_1  @"yyyy/MM/dd HH:mm:ss"
#define NSDATE_FORMAT_DATE      @"yyyy-MM-dd"
#define NSDATE_FORMAT_DATE_1    @"yyyy/MM/dd"
#define NSDATE_FORMAT_TIME      @"HH:mm:ss"

// 常用地区
#define LOCALE_CHINA [[NSLocale alloc] initWithLocaleIdentifier:@"zh_Hans_CN"]
#define LOCALE_USA [[NSLocale alloc] initWithLocaleIdentifier:@"es_US"]

// 判断日期在两个日期之间，比较两个日期，忽略选项。
typedef NS_OPTIONS(NSUInteger, NSDateCompareIgnoreOptions) {
    NSDateIgnoreNone    =  0,
    NSDateIgnoreYear    =  1 << 0,
    NSDateIgnoreMonth   =  1 << 1,
    NSDateIgnoreDay     =  1 << 2,
    NSDateIgnoreHour    =  1 << 3,
    NSDateIgnoreMin     =  1 << 4,
    NSDateIgnoreSecond  =  1 << 5
};

// NS_AVAILABLE(10_7, 5_0).
@interface NSDate (Exts)

// 根据字符串返回date,|formatterString|格式为yyyy-MM-dd HH:mm +0800;
// +dateWithYYYYMMDD:方法中|ymd|为yyyy-MM-dd;
// +dateWithHhmm:方法中|hhmm|为HH:mm;
// @return date.
#pragma mark
#pragma mark - ** 日期类方法 **
+ (id)dateWithString:(NSString *)string;
+ (id)dateWithDateString:(NSString *)string;
+ (id)dateWithTimeString:(NSString *)string;
+ (id)dateWithString:(NSString *)string format:(NSString *)format;
+ (id)dateWithString:(NSString *)string locale:(NSLocale *)locale;
+ (id)dateWithString:(NSString *)string format:(NSString *)format locale:(NSLocale *)locale;

/// rfc1123格式为：Tue, 21 Dec 2013 05:54:26 GMT
+ (id)dateFromRFC1123:(NSString*)rfc1123;

#pragma mark - ** 日期实例方法 **
- (NSDate *)dateByAddingMinutes:(NSInteger)minutes;
- (NSDate *)dateByAddingHours:(NSInteger)hours;
- (NSDate *)dateByAddingDays:(NSInteger)days;
- (NSDate *)dateByAddingMonths:(NSInteger)months;

- (NSDate *)dateBySetSecond:(NSInteger)second;
- (NSDate *)dateBySetMinute:(NSInteger)minute;
- (NSDate *)dateBySetHour:(NSInteger)hour;
- (NSDate *)dateBySetDay:(NSInteger)day;
- (NSDate *)dateBySetMonth:(NSInteger)month;
- (NSDate *)dateBySetYear:(NSInteger)year;

- (NSDate *)dateOfWeekStart;
- (NSDate *)dateOfMonthStart;
- (NSDate *)dateOfYearStart;
- (NSDate *)dateOfWeekEnd;
- (NSDate *)dateOfMonthEnd;
- (NSDate *)dateOfYearEnd;

// 两个日期相隔时间段;
// @return 返回值为正，date日期在前;否则date日期在后.
#pragma mark - ** 两个日期相隔时间段 **
- (NSInteger)distanceInDaysToDate:(NSDate *)anotherDate;

#pragma mark - ** 判断某个日期在两个日期之间、比较两个日期、判断是否是周末 **
- (BOOL)isBetween:(NSDate *)date1 date2:(NSDate *)date2;
- (BOOL)isBetween:(NSDate *)date1 date2:(NSDate *)date2 ignore:(NSDateCompareIgnoreOptions)option;

- (NSComparisonResult)compare:(NSDate *)other ignore:(NSDateCompareIgnoreOptions)option;

- (BOOL)isEqualToDate:(NSDate *)aDate ignore:(NSDateCompareIgnoreOptions)option;

- (BOOL) isWeekend;
- (BOOL) isWorkday;

#pragma mark - ** 按指定格式返回字符串 **
- (NSString *)string;
- (NSString *)dateString;
- (NSString *)timeString;
- (NSString *)stringWithLocale:(NSLocale *)locale;
- (NSString *)stringWithFormat:(NSString *)format;
- (NSString *)stringWithFormat:(NSString *)format locale:(NSLocale *)locale;

/// rfc1123格式为：Tue, 21 Dec 2013 05:54:26 GMT
- (NSString *)rfc1123String;

#pragma mark - ** 纪元、年、月、日、小时、分钟、秒、星期 **
- (NSInteger)era;
- (NSInteger)year;
- (NSInteger)month;
- (NSInteger)day;
- (NSInteger)hour;
- (NSInteger)minute;
- (NSInteger)second;
- (NSInteger)week;
- (NSInteger)weekday;
- (NSInteger)quarter NS_AVAILABLE(10_6, 4_0);
- (NSInteger)weekOfMonth NS_AVAILABLE(10_7, 5_0);
- (NSInteger)weekOfYear NS_AVAILABLE(10_7, 5_0);
- (NSInteger)yearForWeekOfYear NS_AVAILABLE(10_7, 5_0);
- (BOOL)isLeapYear;

#pragma mark - ** 第几天、从1开始 **
- (NSInteger)nthDayOfWeek;
- (NSInteger)nthDayOfMonth;
- (NSInteger)nthDayOfYear;

#pragma mark - ** 第几周、从1开始 **
- (NSInteger)nthWeekOfMonth;
- (NSInteger)nthWeekOfYear;

#pragma mark - ** 第几季度、从1开始 **
- (NSInteger)nthSeason;

#pragma mark - ** 天数 **
- (NSInteger)daysOfMonth;
- (NSInteger)daysOfYear;

@end
