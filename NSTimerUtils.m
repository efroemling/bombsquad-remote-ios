#import "NSTimerUtils.h"

typedef void (^PSYTimerBlock)(NSTimer *);

@interface NSTimer (UtilsPrivate)
+ (void)PSYBlockTimer_executeBlockWithTimer:(NSTimer *)timer;
@end

@implementation NSTimer (Utils)
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)seconds repeats:(BOOL)repeats usingBlock:(void (^)())fireBlock
{
  return [self scheduledTimerWithTimeInterval:seconds target:self selector:@selector(PSYBlockTimer_executeBlockWithTimer:) userInfo:[[fireBlock copy] autorelease] repeats:repeats];
}

+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)seconds repeats:(BOOL)repeats usingBlock:(void (^)())fireBlock
{
  return [self timerWithTimeInterval:seconds target:self selector:@selector(PSYBlockTimer_executeBlockWithTimer:) userInfo:[[fireBlock copy] autorelease] repeats:repeats];
}
@end

@implementation NSTimer (Utils_Private)
+ (void)PSYBlockTimer_executeBlockWithTimer:(NSTimer *)timer
{
  PSYTimerBlock block = [timer userInfo];
  block(timer);
}
@end
