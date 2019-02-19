#import "BrowserViewController.h"
#import "HoverView.h"
#import "RemoteViewController.h"

// The Bonjour application protocol, which must:
// 1) be no longer than 14 characters
// 2) contain only lower-case letters, digits, and hyphens
// 3) begin and end with lower-case letter or digit
// It should also be descriptive and human-readable
// See the following for more information:
// http://developer.apple.com/networking/bonjour/faq.html
#define kGameIdentifier @"bsremote"

#define DEFAULT_CONTROLLER_DPAD_SENSITIVITY 0.5

@interface AppController
    : NSObject <UIApplicationDelegate, UIActionSheetDelegate,
                BrowserViewControllerDelegate, UITextFieldDelegate,
                UIAccelerometerDelegate> {
  id _prefsDelegate;
  float _accelX;
  float _accelY;
  float _accelZ;

  UISlider *_dPadSlider;
}

+ (AppController *)sharedApp;
+ (NSString *)playerName;
+ (void)debugPrint:(NSString *)s;
+ (void)timerWithInterval:(NSTimeInterval)seconds andBlock:(void (^)())b;
- (void)showPrefsWithDelegate:(id)delegate;
- (void)hidePrefs;

@property(nonatomic, retain) UIWindow *window;
@property(nonatomic, retain) UINavigationController *navController;
@property(nonatomic, retain) BrowserViewController *browserViewController;
@property(nonatomic, retain) NSMutableArray *debugTextLabels;
@property(nonatomic, retain) HoverView *hoverView;
@property(nonatomic, retain) UIButton *setTiltNeutralButton;
@property(nonatomic, retain) UILabel *joystickStyleLabel;
@property(nonatomic, retain) UISegmentedControl *joystickStyleControl;

@property(nonatomic, retain) UIImageView *logoImage;

@end
