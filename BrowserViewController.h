#import <UIKit/UIKit.h>

@class BrowserViewController;
#include <map>
#include <netinet/in.h>
#include <string>
#include <vector>

struct BSRemoteGameEntry {
  CFTimeInterval lastTime;
  struct sockaddr addr;
  int addrSize;
};

@protocol BrowserViewControllerDelegate <NSObject>
@required
// This method will be invoked when the user selects one of the service
// instances from the list. The ref parameter will be the selected (already
// resolved) instance or nil if the user taps the 'Cancel' button (if shown).
- (void)browserViewController:(BrowserViewController *)bvc
             didSelectAddress:(struct sockaddr)addr
                     withSize:(int)size;
@end

@interface BrowserViewController
    : UITableViewController <UITextFieldDelegate> {

@private
  id<BrowserViewControllerDelegate> _delegate;
  NSString *_searchingForServicesString;
  NSTimer *_timer;
  NSTimer *_titleTimer;
  BOOL _needsActivityIndicator;
  BOOL _initialWaitOver;
  BOOL _doingNameDialog;
  int _dotCount;

  CFSocketRef _scanSocket;
  int _scanSocketRaw;

  std::map<std::string, BSRemoteGameEntry> _games;
}

@property(nonatomic, assign) id<BrowserViewControllerDelegate> delegate;
@property(nonatomic, copy) NSString *searchingForServicesString;
@property(nonatomic, retain) UIImageView *tableBG;
@property(nonatomic, retain) UIImageView *logo;
@property(nonatomic, retain) UIButton *nameButton;
@property(nonatomic, retain) UIButton *manualButton;

- (id)initWithTitle:(NSString *)title;
- (void)stop;
- (void)start;

@end
