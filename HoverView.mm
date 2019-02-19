
#import "HoverView.h"

@implementation HoverView

- (void)fillRoundedRect:(CGRect)rect inContext:(CGContextRef)context {
  float radius = 15.0f;
  CGContextBeginPath(context);
  CGContextSetRGBFillColor(context, 0.2, 0.12, 0.2, 0.85);
  CGContextMoveToPoint(context, CGRectGetMinX(rect) + radius,
                       CGRectGetMinY(rect));
  CGContextAddArc(context, CGRectGetMaxX(rect) - radius,
                  CGRectGetMinY(rect) + radius, radius, 3 * M_PI / 2, 0, 0);
  CGContextAddArc(context, CGRectGetMaxX(rect) - radius,
                  CGRectGetMaxY(rect) - radius, radius, 0, M_PI / 2, 0);
  CGContextAddArc(context, CGRectGetMinX(rect) + radius,
                  CGRectGetMaxY(rect) - radius, radius, M_PI / 2, M_PI, 0);
  CGContextAddArc(context, CGRectGetMinX(rect) + radius,
                  CGRectGetMinY(rect) + radius, radius, M_PI, 3 * M_PI / 2, 0);
  CGContextClosePath(context);
  CGContextFillPath(context);
}

- (void)drawRect:(CGRect)rect {
  // draw a box with rounded corners to fill the view -
  CGRect boxRect = self.bounds;
  CGContextRef ctxt = UIGraphicsGetCurrentContext();
  boxRect = CGRectInset(boxRect, 1.0f, 1.0f);
  [self fillRoundedRect:boxRect inContext:ctxt];
}

- (void)dealloc {
  [super dealloc];
}

@end
