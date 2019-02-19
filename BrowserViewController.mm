#import "BrowserViewController.h"
#import "AppController.h"
#import "HelpViewController.h"
#import "RemoteViewController.h"
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <iostream>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/types.h>

#define kProgressIndicatorSize 20.0

using namespace std;

@interface BrowserViewController ()
@property(nonatomic, assign, readwrite) BOOL needsActivityIndicator;
@property(nonatomic, assign, readwrite) BOOL initialWaitOver;

@property(nonatomic, retain, readwrite) NSTimer *titleTimer;

- (void)initialWaitOver:(NSTimer *)timer;
- (void)showPrefs;
- (void)showHelp;
- (void)showManualConnectDialog;
- (void)showSetNameDialog;
- (void)update:(NSTimer *)timer;

@end

@implementation BrowserViewController

@synthesize delegate = _delegate;
@synthesize needsActivityIndicator = _needsActivityIndicator;
@dynamic titleTimer;
@synthesize initialWaitOver = _initialWaitOver;
@synthesize tableBG = _tableBG;
@synthesize nameButton = _nameButton;
@synthesize manualButton = _manualButton;
@synthesize logo = _logo;

- (id)initWithTitle:(NSString *)title {

  if ((self = [super initWithStyle:UITableViewStylePlain])) {
    self.title = title;

    // Make sure we have a chance to discover devices before showing the user
    // that nothing was found (yet)
    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self
                                   selector:@selector(initialWaitOver:)
                                   userInfo:nil
                                    repeats:NO];

    self.titleTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                       target:self
                                                     selector:@selector(update:)
                                                     userInfo:nil
                                                      repeats:YES];
  }

  return self;
}

- (NSString *)searchingForServicesString {
  return _searchingForServicesString;
}

- (void)stop {

  if (_scanSocket) {
    CFSocketInvalidate(_scanSocket);
    CFRelease(_scanSocket);
    _scanSocket = NULL;
  }

  // clear any existing...
  [self.tableView reloadData];
}

static void readCallback(CFSocketRef cfSocket, CFSocketCallBackType type,
                         CFDataRef address, const void *data, void *info) {
  BrowserViewController *vc = (BrowserViewController *)info;
  int s = CFSocketGetNative(cfSocket);
  if (s) {
    [vc readFromSocket:s];
  }
}

- (void)readFromSocket:(int)s {
  char buffer[256];
  sockaddr addr;
  socklen_t l = sizeof(addr);
  int amt = static_cast<int>(recvfrom(s, buffer, sizeof(buffer), 0, &addr, &l));

  if (amt == -1) {
    // any case where we'd need to look at errors here?...
  }
  if (amt > 0) {

    switch (buffer[0]) {
    case BS_REMOTE_MSG_GAME_RESPONSE: {
      if (amt > 1) {
        // the rest of the packet is the game name
        if (amt >= sizeof(buffer)) {
          buffer[sizeof(buffer) - 1] = 0;
        } else {
          buffer[amt] = 0;
        }

        // if this entry is new, reload the list
        bool isNew = (_games.find(buffer + 1) == _games.end());
        _games[buffer + 1].lastTime = CACurrentMediaTime();
        memcpy(&_games[buffer + 1].addr, &addr, l);
        _games[buffer + 1].addrSize = l;
        if (isNew)
          [self.tableView reloadData];
        break;
      }
    }
    default:
      break;
    }
  }
}

- (void)start {

  // create our scan socket...
  if (_scanSocket == NULL) {
    CFSocketContext socketCtxt = {0, self, NULL, NULL, NULL};
    _scanSocket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_DGRAM,
                                 IPPROTO_UDP, kCFSocketReadCallBack,
                                 (CFSocketCallBack)&readCallback, &socketCtxt);
    ;
    if (_scanSocket == NULL) {
      NSLog(@"ERROR CREATING IPv4 SCANNER SOCKET");
      abort();
    }

    // bind it to a any port
    if (_scanSocket != NULL) {
      struct sockaddr_in addr4;
      memset(&addr4, 0, sizeof(addr4));
      addr4.sin_len = sizeof(addr4);
      addr4.sin_family = AF_INET;
      addr4.sin_port = 0;
      addr4.sin_addr.s_addr = htonl(INADDR_ANY);
      NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];

      if (kCFSocketSuccess !=
          CFSocketSetAddress(_scanSocket, (CFDataRef)address4)) {
        NSLog(@"ERROR ON CFSocketSetAddress for scan socket");
        if (_scanSocket) {
          CFRelease(_scanSocket);
        }
        _scanSocket = NULL;
      }
      if (_scanSocket != NULL) {
        _scanSocketRaw = CFSocketGetNative(_scanSocket);
        // set broadcast..
        int opVal = 1;
        int result = setsockopt(_scanSocketRaw, SOL_SOCKET, SO_BROADCAST,
                                &opVal, sizeof(opVal));
        if (result != 0) {
          NSLog(@"Error setting up ipv4 scanner socket");
          abort();
        }
        // wire this socket up to our run loop
        CFRunLoopRef cfrl = CFRunLoopGetCurrent();
        CFRunLoopSourceRef source =
            CFSocketCreateRunLoopSource(kCFAllocatorDefault, _scanSocket, 0);
        CFRunLoopAddSource(cfrl, source, kCFRunLoopCommonModes);
        CFRelease(source);
      }
    }
  }
}

- (void)viewDidLoad {

  [super viewDidLoad];
  UIImage *image = [UIImage imageNamed:@"tableBG.png"];

  self.tableBG = nil;
  _tableBG = [[UIImageView alloc] initWithImage:image];
  _tableBG.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

  // add a logo here on iphone version..
  if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
    float logoSize = 200;
    self.logo = [[[UIImageView alloc]
        initWithImage:[UIImage imageNamed:@"logo.png"]] autorelease];
    _logo.autoresizingMask = (UIViewAutoresizingFlexibleRightMargin |
                              UIViewAutoresizingFlexibleLeftMargin |
                              UIViewAutoresizingFlexibleTopMargin |
                              UIViewAutoresizingFlexibleBottomMargin);
    _logo.frame = CGRectMake(_tableBG.bounds.size.width / 2 - logoSize / 2,
                             _tableBG.bounds.size.height * 0.6 - logoSize / 2,
                             logoSize, logoSize);
    [_tableBG addSubview:_logo];
  }

  self.navigationController.view.backgroundColor = [UIColor colorWithRed:0.7
                                                                   green:0.5
                                                                    blue:0.3
                                                                   alpha:1];
  self.view.backgroundColor = [UIColor colorWithRed:0.7
                                              green:0.5
                                               blue:0.3
                                              alpha:1];

  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

  UIBarButtonItem *b = [[[UIBarButtonItem alloc]
      initWithTitle:@"options"
              style:UIBarButtonItemStylePlain
             target:self
             action:@selector(showPrefs)] autorelease];
  self.navigationItem.rightBarButtonItem = b;

  b = [[[UIBarButtonItem alloc] initWithTitle:@"tips"
                                        style:UIBarButtonItemStylePlain
                                       target:self
                                       action:@selector(showHelp)] autorelease];
  self.navigationItem.leftBarButtonItem = b;

  // add 'change name' button...
  self.nameButton = nil;
  self.nameButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [_nameButton addTarget:self
                  action:@selector(showSetNameDialog)
        forControlEvents:UIControlEventTouchUpInside];
  NSString *s =
      [NSString stringWithFormat:@"Name: %@", [AppController playerName]];
  [_nameButton setTitle:s forState:UIControlStateNormal];

  // add manual-connect button...
  self.manualButton = nil;
  self.manualButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [_manualButton addTarget:self
                    action:@selector(showManualConnectDialog)
          forControlEvents:UIControlEventTouchUpInside];
  [_manualButton setTitle:@"Connect by Address..."
                 forState:UIControlStateNormal];
}

- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
  // Prevent crashing undo bug – see note below.
  if (range.length + range.location > textField.text.length) {
    return NO;
  }

  NSUInteger newLength =
      [textField.text length] + [string length] - range.length;
  return newLength <= 10;
}

- (void)showSetNameDialog {
  _doingNameDialog = true;
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Player Name"
                                                  message:nil
                                                 delegate:self
                                        cancelButtonTitle:@"Cancel"
                                        otherButtonTitles:@"OK", nil];
  alert.alertViewStyle = UIAlertViewStylePlainTextInput;
  UITextField *alertTextField = [alert textFieldAtIndex:0];
  alertTextField.delegate = self;
  alertTextField.keyboardType = UIKeyboardTypeDefault;
  alertTextField.placeholder = @"Enter a name";
  alertTextField.text = [AppController playerName];
  [alert show];
}

- (void)showManualConnectDialog {
  _doingNameDialog = false;
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connect by Address"
                                                  message:nil
                                                 delegate:self
                                        cancelButtonTitle:@"Cancel"
                                        otherButtonTitles:@"Connect", nil];
  alert.alertViewStyle = UIAlertViewStylePlainTextInput;
  UITextField *alertTextField = [alert textFieldAtIndex:0];
  alertTextField.keyboardType = UIKeyboardTypeDefault;
  alertTextField.placeholder = @"Enter an address";
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:@"manualAddress"] != nil) {
    alertTextField.text = [defaults stringForKey:@"manualAddress"];
  }
  [alert show];
}

- (void)alertView:(UIAlertView *)alertView
    willDismissWithButtonIndex:(NSInteger)buttonIndex {
  if (buttonIndex == alertView.cancelButtonIndex) {
    // they canceled; do nothing
  } else {
    UITextField *t = [alertView textFieldAtIndex:0];
    if (t != nil) {
      // either set a name or connect to an address...
      if (_doingNameDialog) {
        [[NSUserDefaults standardUserDefaults] setObject:t.text
                                                  forKey:@"playerName"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSString *s =
            [NSString stringWithFormat:@"Name: %@", [AppController playerName]];
        [_nameButton setTitle:s forState:UIControlStateNormal];

      } else {
        [[NSUserDefaults standardUserDefaults] setObject:t.text
                                                  forKey:@"manualAddress"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        struct addrinfo hints, *res, *p;
        int status;
        char ipstr[INET6_ADDRSTRLEN];
        memset(&hints, 0, sizeof hints);
        hints.ai_family = AF_UNSPEC; // AF_INET or AF_INET6 to force version
        hints.ai_socktype = SOCK_STREAM;
        if ((status = getaddrinfo(t.text.UTF8String, NULL, &hints, &res)) !=
            0) {
          return;
        }
        for (p = res; p != NULL; p = p->ai_next) {
          void *addr;
          const char *ipver;
          // get the pointer to the address itself,
          // different fields in IPv4 and IPv6:
          if (p->ai_family == AF_INET) { // IPv4
            struct sockaddr_in *ipv4 = (struct sockaddr_in *)p->ai_addr;
            addr = &(ipv4->sin_addr);
            ipv4->sin_port = htons(43210);
            ipver = "IPv4";
          } else { // IPv6
            struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)p->ai_addr;
            addr = &(ipv6->sin6_addr);
            ipv6->sin6_port = htons(43210);
            ipver = "IPv6";
          }

          // convert the IP to a string and print it:
          inet_ntop(p->ai_family, addr, ipstr, sizeof ipstr);
          printf("  %s: %s\n", ipver, ipstr);

          [[AppController sharedApp] browserViewController:self
                                          didSelectAddress:*p->ai_addr
                                                  withSize:p->ai_addrlen];
          break; // only do first
        }

        freeaddrinfo(res); // free the linked list
      }
    }
  }
}

- (void)showHelp {
  HelpViewController *vc =
      [[[HelpViewController alloc] initWithNibName:@"HelpViewController"
                                            bundle:nil] autorelease];
  vc.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
  [self presentModalViewController:vc animated:YES];
}

- (void)showPrefs {
  [[AppController sharedApp] showPrefsWithDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self.navigationController setNavigationBarHidden:NO animated:animated];
  [self start];

  self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.4
                                                                      green:0.4
                                                                       blue:0.7
                                                                      alpha:1];

  // fade in our bg view
  [self.navigationController.view insertSubview:_tableBG atIndex:1];
  CGRect imageframe = self.navigationController.view.bounds;
  _tableBG.frame = imageframe;
  _tableBG.alpha = 0.0;
  if (animated) {
    [UIView animateWithDuration:0.3
                     animations:^{
                       _tableBG.alpha = 1.0;
                     }
                     completion:^(BOOL completed){
                     }];
  } else {
    _tableBG.alpha = 1.0;
  }

  // add our name and manual-connect buttons...
  [self.navigationController.view addSubview:_nameButton];
  _nameButton.frame =
      CGRectMake(10.0, _tableBG.bounds.size.height - 50, 200.0, 40.0);
  [self.navigationController.view addSubview:_manualButton];
  _manualButton.frame =
      CGRectMake(_tableBG.bounds.size.width - 210,
                 _tableBG.bounds.size.height - 50, 200.0, 40.0);
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  [self stop];
  [UIView animateWithDuration:0.3
      animations:^{
        _tableBG.alpha = 0.0;
      }
      completion:^(BOOL completed) {
        [_tableBG removeFromSuperview];
      }];
  [_nameButton removeFromSuperview];
  [_manualButton removeFromSuperview];
}

- (NSTimer *)titleTimer {
  return _titleTimer;
}

// When this is called, invalidate the existing timer before releasing it.
- (void)setTitleTimer:(NSTimer *)newTimer {
  [_titleTimer invalidate];
  [newTimer retain];
  [_titleTimer release];
  _titleTimer = newTimer;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {

  if (_games.size() > 0) {
    return _games.size();
  }
  return 0;
}

- (CGFloat)tableView:(UITableView *)tableView
    heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  return 80; // returns floating point which will be used for a cell row height
             // at specified row index
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

  static NSString *tableCellIdentifier = @"UITableViewCell";
  UITableViewCell *cell = (UITableViewCell *)[tableView
      dequeueReusableCellWithIdentifier:tableCellIdentifier];
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:tableCellIdentifier]
        autorelease];
    cell.textLabel.textAlignment = UITextAlignmentCenter;
    cell.backgroundColor = [UIColor clearColor];
  }

  if (_games.size() == 0 and self.searchingForServicesString) {
    // If there are no services and searchingForServicesString is set, show one
    // row explaining that to the user.

    // doing this super-hacky for now with whatever space counts keep the text
    // from jittering - need to add custom text view and just set it
    // left-aligned.
    if ([[UIScreen mainScreen] scale] > 1.0) {
      if (_dotCount == 0) {
        cell.textLabel.text =
            [NSString stringWithFormat:@"%@", self.searchingForServicesString];
      } else if (_dotCount == 1) {
        cell.textLabel.text = [NSString
            stringWithFormat:@".%@.", self.searchingForServicesString];
      } else if (_dotCount == 2) {
        cell.textLabel.text = [NSString
            stringWithFormat:@"..%@..", self.searchingForServicesString];
      } else if (_dotCount == 3) {
        cell.textLabel.text = [NSString
            stringWithFormat:@"...%@...", self.searchingForServicesString];
      }
    } else {
      if (_dotCount == 0) {
        cell.textLabel.text =
            [NSString stringWithFormat:@"%@", self.searchingForServicesString];
      } else if (_dotCount == 1) {
        cell.textLabel.text = [NSString
            stringWithFormat:@".%@.", self.searchingForServicesString];
      } else if (_dotCount == 2) {
        cell.textLabel.text = [NSString
            stringWithFormat:@"..%@..", self.searchingForServicesString];
      } else if (_dotCount == 3) {
        cell.textLabel.text = [NSString
            stringWithFormat:@"...%@...", self.searchingForServicesString];
      }
    }
    cell.textLabel.font = [UIFont boldSystemFontOfSize:24];
    cell.backgroundColor = [UIColor clearColor];

    cell.textLabel.textColor = [UIColor colorWithRed:0
                                               green:0.1
                                                blue:0.2
                                               alpha:0.5];
    cell.accessoryType = UITableViewCellAccessoryNone;

    // Make sure to get rid of the activity indicator that may be showing if we
    // were resolving cell zero but then got didRemoveService callbacks for all
    // services (e.g. the network connection went down).
    if (cell.accessoryView) {
      cell.accessoryView = nil;
    }
    return cell;
  }

  // new simple stuff
  if (_games.size() > 0) {
    int index = 0;
    cell.textLabel.text = @"unknown";
    for (map<string, BSRemoteGameEntry>::iterator i = _games.begin();
         i != _games.end(); i++) {
      if (index == indexPath.row) {
        cell.textLabel.text = [NSString stringWithUTF8String:i->first.c_str()];
      }
      index++;
    }
    cell.accessoryView = nil;
  } else {
    NSLog(@"Obsolete bonjour code path; should not happen.");
  }
  cell.textLabel.textColor = [UIColor blackColor];
  cell.textLabel.font = [UIFont boldSystemFontOfSize:24];

  return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView
    willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  // Ignore the selection if there are no services as the
  // searchingForServicesString cell may be visible and tapping it would do
  // nothing
  if (_games.size() == 0) {
    return nil;
  }

  return indexPath;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

  // new simple style
  if (_games.size() > 0) {
    int index = 0;
    for (auto i : _games) {
      if (index == indexPath.row) {
        // cout << "THEY TAPPED ON " << i.first << endl;
        [self.delegate browserViewController:self
                            didSelectAddress:i.second.addr
                                    withSize:i.second.addrSize];
        break;
      }
      index++;
    }
  } else {
    NSLog(@"Game entries not present for row select; shouldn't happen!");
  }
}

- (void)update:(NSTimer *)timer {
  _dotCount = (_dotCount + 1) % 4;

  if (_scanSocket != NULL) {

    // broadcast game query packets to all our network interfaces
    struct ifaddrs *ifaddr;
    if (getifaddrs(&ifaddr) != -1) {
      int i = 0;
      for (ifaddrs *ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        int family = ifa->ifa_addr->sa_family;
        if (family == AF_INET) {
          if (ifa->ifa_addr != NULL) {
            sockaddr_in broadcastAddr;
            memcpy(&broadcastAddr, ifa->ifa_addr, sizeof(sockaddr_in));

            UInt32 addr =
                ntohl(((sockaddr_in *)ifa->ifa_addr)->sin_addr.s_addr);
            UInt32 subnet =
                ntohl(((sockaddr_in *)ifa->ifa_netmask)->sin_addr.s_addr);
            UInt32 broadcast = addr | (~subnet);

            broadcastAddr.sin_addr.s_addr = htonl(broadcast);
            broadcastAddr.sin_port = htons(43210);

            UInt8 data[1] = {BS_REMOTE_MSG_GAME_QUERY};

            int err = static_cast<int>(sendto(_scanSocketRaw, data, 1, 0,
                                              (sockaddr *)&broadcastAddr,
                                              sizeof(broadcastAddr)));
            if (err == -1) {
              // let's note only unexpected errors...
              if (errno != EHOSTDOWN && errno != EHOSTUNREACH) {
                NSLog(@"ERROR %d on sendto for scanner socket\n", errno);
              }
            }

            // cout << "ADDR IS " << ((addr>>24)&0xFF) << "." <<
            // ((addr>>16)&0xFF) << "." << ((addr>>8)&0xFF) << "." <<
            // ((addr>>0)&0xFF) << endl; cout << "NETMASK IS " <<
            // ((subnet>>24)&0xFF) << "." << ((subnet>>16)&0xFF) << "." <<
            // ((subnet>>8)&0xFF) << "." << ((subnet>>0)&0xFF) << endl; cout <<
            // "BROADCAST IS " << ((broadcast>>24)&0xFF) << "." <<
            // ((broadcast>>16)&0xFF) << "." << ((broadcast>>8)&0xFF) << "." <<
            // ((broadcast>>0)&0xFF) << endl;
            i++;
          }
        }
      }
    }
  }
  // cout <<"CHECKING FOR OLD GAMES"<< endl;

  CFTimeInterval curTime = CACurrentMediaTime();

  // remove games from our list that we havn't heard from in a while
  map<string, BSRemoteGameEntry>::iterator i = _games.begin();
  map<string, BSRemoteGameEntry>::iterator iNext;
  bool changed = false;
  while (i != _games.end()) {
    iNext = i;
    iNext++;
    if (curTime - i->second.lastTime > 3.0) {
      _games.erase(i);
      changed = true;
    }
    i = iNext;
  }

  if (changed) {
    [self.tableView reloadData];
  }

  // updates our 'searching' txt
  if (_games.size() == 0) {
    [self.tableView reloadData];
  }
}

- (void)initialWaitOver:(NSTimer *)timer {
  self.initialWaitOver = YES;
  if (_games.size() == 0) {
    [self.tableView reloadData];
  }
}

- (void)cancelAction {
  [self.delegate browserViewController:self didResolveInstance:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:
    (UIInterfaceOrientation)interfaceOrientationIn {
  // iPad works any which way.. iPhone only landscape
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    return YES;
  } else {
    return (interfaceOrientationIn == UIInterfaceOrientationLandscapeLeft ||
            interfaceOrientationIn == UIInterfaceOrientationLandscapeRight);
  }
}

- (void)dealloc {
  // Cleanup any running resolve and free memory
  [_searchingForServicesString release];
  self.tableBG = nil;
  self.logo = nil;
  self.titleTimer = nil;
  [super dealloc];
}

@end
