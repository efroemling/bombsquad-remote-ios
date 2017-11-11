#import "UIViewUtilities.h"

@implementation UIView (Utilities)

- (void) transitionInBottom
{
  float slideDist = self.superview.bounds.size.height - (self.center.y - self.bounds.size.height*0.5);
  // move it down then animate it back up
  self.center = CGPointMake(self.center.x,self.center.y+slideDist);
  [UIView animateWithDuration:0.25
                        delay:0
                      options:nil
                   animations:^{self.center = CGPointMake(self.center.x,self.center.y-slideDist);}
                   completion:^(BOOL completed){}];
  
}

- (void) transitionOutBottom
{
  float slideDist = self.superview.bounds.size.height - (self.center.y - self.bounds.size.height*0.5);
  [UIView animateWithDuration:0.25
                        delay:0
                      options:nil
                   animations:^{ self.center = CGPointMake(self.center.x,self.center.y+slideDist);}
                   completion:^(BOOL completed){
                     [self removeFromSuperview];
                   }];
  
}

- (void) transitionInTop
{
  float slideDist = self.center.y + self.bounds.size.height*0.5;
  // move it up then animate it back down
  self.center = CGPointMake(self.center.x,self.center.y-slideDist);
  [UIView animateWithDuration:0.25
                        delay:0
                      options:nil
                   animations:^{ self.center = CGPointMake(self.center.x,self.center.y+slideDist);}
                   completion:^(BOOL completed){}];
  
}

- (void) transitionOutTop
{
  float slideDist = self.center.y + self.bounds.size.height*0.5;
  [UIView animateWithDuration:0.25
                        delay:0
                      options:nil
                   animations:^{ self.center = CGPointMake(self.center.x,self.center.y-slideDist);}
                   completion:^(BOOL completed){
                     [self removeFromSuperview];
                   }];
  
}

@end
