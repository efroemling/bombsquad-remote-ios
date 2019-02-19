#import <Foundation/NSNetServices.h>
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
           didResolveInstance:(NSNetService *)ref;
- (void)browserViewController:(BrowserViewController *)bvc
             didSelectAddress:(struct sockaddr)addr
                     withSize:(int)size;
@end

@interface BrowserViewController
    : UITableViewController <NSNetServiceDelegate, NSNetServiceBrowserDelegate,
                             UITextFieldDelegate> {

@private
  id<BrowserViewControllerDelegate> _delegate;
  NSString *_searchingForServicesString;
  NSString *_ownName;
  NSNetService *_ownEntry;
  BOOL _showDisclosureIndicators;
  // NSMutableArray *_games;
  NSMutableArray *_bonjourGames;
  NSNetServiceBrowser *_netServiceBrowser;
  NSNetService *_currentResolve;
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
@property(nonatomic, copy) NSString *ownName;
@property(nonatomic, retain) UIImageView *tableBG;
@property(nonatomic, retain) UIImageView *logo;
@property(nonatomic, retain) UIButton *nameButton;
@property(nonatomic, retain) UIButton *manualButton;

- (id)initWithTitle:(NSString *)title
    showDisclosureIndicators:(BOOL)showDisclosureIndicators
            showCancelButton:(BOOL)showCancelButton;
- (BOOL)searchForServicesOfType:(NSString *)type inDomain:(NSString *)domain;
- (void)stop;
- (void)start;

@end
