#import "BrowserViewController.h"
#import "AppController.h"
#import "HelpViewController.h"
#import "RemoteViewController.h"
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <iostream>
#include <net/if.h>
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

  if (_scanSocket4) {
    CFSocketInvalidate(_scanSocket4);
    CFRelease(_scanSocket4);
    _scanSocket4 = NULL;
  }
  if (_scanSocket6) {
    CFSocketInvalidate(_scanSocket6);
    CFRelease(_scanSocket6);
    _scanSocket6 = NULL;
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
  sockaddr_storage addr;
  socklen_t l = sizeof(addr);
  int amt = static_cast<int>(
      recvfrom(s, buffer, sizeof(buffer), 0, (sockaddr *)&addr, &l));

  if (amt == -1) {
    // any case where we'd need to look at errors here?...
  }
  // if (s == _scanSocket4Raw) {
  //   NSLog(@"GOT RESPONSE FROM 4");
  // } else if (s == _scanSocket6Raw) {
  //   NSLog(@"GOT RESPONSE FROM 6");
  // }
  if (amt > 0) {

    switch (buffer[0]) {
    case BS_REMOTE_MSG_GAME_RESPONSE: {
      if (amt > 1) {
        const char *game_name = buffer + 1;

        // the rest of the packet is the game name
        if (amt >= sizeof(buffer)) {
          buffer[sizeof(buffer) - 1] = 0;
        } else {
          buffer[amt] = 0;
        }

        // if this entry is new, reload the list
        bool isNew = (_games.find(game_name) == _games.end());

        CFTimeInterval curTime = CACurrentMediaTime();

        // only update its addr if its new or if we haven't heard from it
        // in a few seconds... this way we'll tend to use the address
        // we heard back from first if there's multiple addrs for the same game
        if (isNew || (curTime - _games[game_name].lastTime > 2.0f)) {
          memcpy(&_games[game_name].addr, &addr, l);
          _games[game_name].addrSize = l;
        }

        _games[game_name].lastTime = CACurrentMediaTime();

        if (isNew) {
          [self.tableView reloadData];
        }
        break;
      }
    }
    default:
      break;
    }
  }
}

- (void)start {

  // set up our ipv4 broadcast socket
  if (_scanSocket4 == NULL) {
    CFSocketContext socketCtxt = {0, self, NULL, NULL, NULL};
    _scanSocket4 = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_DGRAM,
                                  IPPROTO_UDP, kCFSocketReadCallBack,
                                  (CFSocketCallBack)&readCallback, &socketCtxt);
    ;
    if (_scanSocket4 == NULL) {
      NSLog(@"ERROR CREATING IPv4 SCANNER SOCKET");
      // abort();
    } else {
      // bind it to a any port
      struct sockaddr_in addr4;
      memset(&addr4, 0, sizeof(addr4));
      addr4.sin_len = sizeof(addr4);
      addr4.sin_family = AF_INET;
      addr4.sin_port = 0;
      addr4.sin_addr.s_addr = htonl(INADDR_ANY);
      NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];

      if (kCFSocketSuccess !=
          CFSocketSetAddress(_scanSocket4, (CFDataRef)address4)) {
        NSLog(@"ERROR ON CFSocketSetAddress for ipv4 scan socket");
        if (_scanSocket4) {
          CFRelease(_scanSocket4);
        }
        _scanSocket4 = NULL;
      }
      if (_scanSocket4 != NULL) {
        _scanSocket4Raw = CFSocketGetNative(_scanSocket4);
        // set broadcast..
        int opVal = 1;
        int result = setsockopt(_scanSocket4Raw, SOL_SOCKET, SO_BROADCAST,
                                &opVal, sizeof(opVal));
        if (result != 0) {
          NSLog(@"Error setting up ipv4 scanner socket");
          abort();
        }
        // wire this socket up to our run loop
        CFRunLoopRef cfrl = CFRunLoopGetCurrent();
        CFRunLoopSourceRef source =
            CFSocketCreateRunLoopSource(kCFAllocatorDefault, _scanSocket4, 0);
        CFRunLoopAddSource(cfrl, source, kCFRunLoopCommonModes);
        CFRelease(source);
        NSLog(@"ipv4 scan socket created successfully.");
      }
    }
  }

  // set up our ipv6 broadcast socket
  if (_scanSocket6 == NULL) {
    _scanSocket6Interface = -1;
    // ok, the first thing we do is try to find our wifi interface
    // which is where we'll send out multicast packets from.
    // on iOS this should be en0, en1, etc.
    // Theoretically we could create a socket for every interface we come
    // across but perhaps it's better to strictly limit to wifi?...
    // (for instance the awdl0 interface sounds like peer to peer wifi
    // used for air-drop/etc. and there may be weird performance issues
    // if we're sending out packets on there AND regular wifi)
    struct ifaddrs *ifaddr;
    if (getifaddrs(&ifaddr) != -1) {
      for (ifaddrs *ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == NULL) {
          NSLog(@"Got null ifa_addr; odd.");
          continue;
        }
        if ((ifa->ifa_addr->sa_family == AF_INET6) &&
            !(ifa->ifa_flags & IFF_LOOPBACK) &&
            !(ifa->ifa_flags & IFF_POINTOPOINT) &&
            (ifa->ifa_flags & IFF_MULTICAST)) {
          int index = if_nametoindex(ifa->ifa_name);
          if (strlen(ifa->ifa_name) > 2 && !strncmp(ifa->ifa_name, "en", 2)) {
            _scanSocket6Interface = index;
            break;
          }
        }
      }
      freeifaddrs(ifaddr);
    }

    if (_scanSocket6Interface == -1) {
      NSLog(@"Unable to find suitable ipv6 interface.");
    } else {
      CFSocketContext socketCtxt = {0, self, NULL, NULL, NULL};
      _scanSocket6 = CFSocketCreate(
          kCFAllocatorDefault, PF_INET6, SOCK_DGRAM, IPPROTO_UDP,
          kCFSocketReadCallBack, (CFSocketCallBack)&readCallback, &socketCtxt);
      ;
      if (_scanSocket6 == NULL) {
        NSLog(@"ERROR CREATING IPv6 SCANNER SOCKET");
        // abort();
      } else {
        // bind it to a any port
        struct sockaddr_in6 addr6;
        memset(&addr6, 0, sizeof(addr6));
        addr6.sin6_len = sizeof(addr6);
        addr6.sin6_family = AF_INET6;
        addr6.sin6_port = 0;
        addr6.sin6_addr = in6addr_any;
        // addr6.sin6_scope_id = interface;  // is this necessary?
        NSData *address6 = [NSData dataWithBytes:&addr6 length:sizeof(addr6)];

        if (kCFSocketSuccess !=
            CFSocketSetAddress(_scanSocket6, (CFDataRef)address6)) {
          NSLog(@"ERROR ON CFSocketSetAddress for ipv6 scan socket");
          if (_scanSocket6) {
            CFRelease(_scanSocket6);
          }
          _scanSocket6 = NULL;
        }
        if (_scanSocket6 != NULL) {
          _scanSocket6Raw = CFSocketGetNative(_scanSocket6);

          int success = setsockopt(_scanSocket6Raw, IPPROTO_IPV6,
                                   IPV6_MULTICAST_IF, &_scanSocket6Interface,
                                   sizeof(_scanSocket6Interface)) == 0;
          if (!success) {
            NSLog(@"Error setting up ipv6 scanner socket");
            if (_scanSocket6) {
              CFRelease(_scanSocket6);
            }
            _scanSocket6 = NULL;
          }

          // wire this socket up to our run loop
          CFRunLoopRef cfrl = CFRunLoopGetCurrent();
          CFRunLoopSourceRef source =
              CFSocketCreateRunLoopSource(kCFAllocatorDefault, _scanSocket6, 0);
          CFRunLoopAddSource(cfrl, source, kCFRunLoopCommonModes);
          CFRelease(source);
          NSLog(@"ipv6 scan socket created successfully.");
        }
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
          NSLog(@"  %s: %s\n", ipver, ipstr);

          [[AppController sharedApp] browserViewController:self
                                          didSelectAddress:p->ai_addr
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
  // special case - say '1' when we're searching so we can show
  // or searching widget.
  if (self.searchingForServicesString && self.initialWaitOver) {
    return 1;
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
    if (_dotCount == 0) {
      cell.textLabel.text =
          [NSString stringWithFormat:@"%@", self.searchingForServicesString];
    } else if (_dotCount == 1) {
      cell.textLabel.text =
          [NSString stringWithFormat:@".%@.", self.searchingForServicesString];
    } else if (_dotCount == 2) {
      cell.textLabel.text = [NSString
          stringWithFormat:@"..%@..", self.searchingForServicesString];
    } else if (_dotCount == 3) {
      cell.textLabel.text = [NSString
          stringWithFormat:@"...%@...", self.searchingForServicesString];
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
    for (auto i : _games) {
      if (index == indexPath.row) {
        cell.textLabel.text = [NSString stringWithUTF8String:i.first.c_str()];
      }
      index++;
    }
    cell.accessoryView = nil;
  } else {
    NSLog(@"Obsolete bonjour code path; should not get here.");
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
        [self.delegate
            browserViewController:self
                 didSelectAddress:(struct sockaddr *)(&i.second.addr)withSize
                                 :i.second.addrSize];
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

  // fire off ipv4 broadcast packets on all our ipv4 interfaces
  // (we use one socket here and just switch target addrs)
  // NOTE TO SELF - remember to disable this periodically to test if IPv6
  // scanning is working...
  if (_scanSocket4 != NULL) {
    struct ifaddrs *ifaddr;
    if (getifaddrs(&ifaddr) != -1) {
      int i = 0;
      for (ifaddrs *ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == NULL) {
          NSLog(@"Got null ifa_addr; odd.");
          continue;
        }
        if ((ifa->ifa_addr->sa_family == AF_INET) &&
            !(ifa->ifa_flags & IFF_LOOPBACK) &&
            !(ifa->ifa_flags & IFF_POINTOPOINT) &&
            (ifa->ifa_flags & IFF_BROADCAST)) {
          sockaddr_in broadcastAddr;
          memcpy(&broadcastAddr, ifa->ifa_addr, sizeof(sockaddr_in));
          UInt32 addr = ntohl(((sockaddr_in *)ifa->ifa_addr)->sin_addr.s_addr);
          UInt32 subnet =
              ntohl(((sockaddr_in *)ifa->ifa_netmask)->sin_addr.s_addr);
          UInt32 broadcast = addr | (~subnet);
          broadcastAddr.sin_addr.s_addr = htonl(broadcast);
          broadcastAddr.sin_port = htons(43210);

          UInt8 data[1] = {BS_REMOTE_MSG_GAME_QUERY};

          int err = static_cast<int>(sendto(_scanSocket4Raw, data, 1, 0,
                                            (sockaddr *)&broadcastAddr,
                                            sizeof(broadcastAddr)));
          if (err == -1) {
            // let's note only unexpected errors...
            if (errno != EHOSTDOWN && errno != EHOSTUNREACH) {
              NSLog(@"ERROR %d on sendto for scanner socket\n", errno);
            }
          }
        }
        i++;
      }
      freeifaddrs(ifaddr);
    }
  }

  // Ok now for ipv6.
  // In this case we've already picked a single interface we're sending
  // multicast packets out to. Now just do the thing.
  if (_scanSocket6 != NULL) {
    struct sockaddr_in6 addr6;
    memset(&addr6, 0, sizeof(addr6));
    addr6.sin6_len = sizeof(addr6);
    addr6.sin6_family = AF_INET6;
    addr6.sin6_port = htons(43210);
    addr6.sin6_scope_id = _scanSocket6Interface;
    // use the magical 'send-to-all-ipv6 devices' multicast address..
    int success = inet_pton(AF_INET6, "FF02::1", &addr6.sin6_addr) == 1;
    assert(success);
    UInt8 data[1] = {BS_REMOTE_MSG_GAME_QUERY};
    long bytesSent = sendto(_scanSocket6Raw, data, 1, 0,
                            (struct sockaddr *)&addr6, sizeof(addr6));
  }

  // remove games from our list that we havn't heard from in a while
  CFTimeInterval curTime = CACurrentMediaTime();
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
