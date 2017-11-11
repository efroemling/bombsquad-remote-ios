#import "BrowserViewController.h"
#import "AppController.h"
#import "HelpViewController.h"
#import "RemoteViewController.h"
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

#include <ifaddrs.h>

#define kProgressIndicatorSize 20.0
#include <iostream>

using namespace std;


// A category on NSNetService that's used to sort NSNetService objects by their name.
@interface NSNetService (BrowserViewControllerAdditions)
- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSNetService *)aService;
@end

@implementation NSNetService (BrowserViewControllerAdditions)
- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSNetService *)aService {
	return [[self name] localizedCaseInsensitiveCompare:[aService name]];
}
@end


@interface BrowserViewController()
@property (nonatomic, retain, readwrite) NSNetService *ownEntry;
@property (nonatomic, assign, readwrite) BOOL showDisclosureIndicators;
//@property (nonatomic, retain, readwrite) NSMutableArray *games;
@property (nonatomic, retain, readwrite) NSMutableArray *bonjourGames;
@property (nonatomic, retain, readwrite) NSNetServiceBrowser *netServiceBrowser;
@property (nonatomic, retain, readwrite) NSNetService *currentResolve;
@property (nonatomic, retain, readwrite) NSTimer *timer;
@property (nonatomic, assign, readwrite) BOOL needsActivityIndicator;
@property (nonatomic, assign, readwrite) BOOL initialWaitOver;

@property (nonatomic, retain, readwrite) NSTimer *titleTimer;


- (void)stopCurrentResolve;
- (void)initialWaitOver:(NSTimer *)timer;
- (void) showPrefs;
- (void) showHelp;
- (void) showManualConnectDialog;
- (void) showSetNameDialog;
- (void) update:(NSTimer *)timer;

@end

@implementation BrowserViewController

@synthesize delegate = _delegate;
@synthesize ownEntry = _ownEntry;
@synthesize showDisclosureIndicators = _showDisclosureIndicators;
@synthesize currentResolve = _currentResolve;
@synthesize netServiceBrowser = _netServiceBrowser;
@synthesize bonjourGames = _bonjourGames;
//@synthesize games = _games;
@synthesize needsActivityIndicator = _needsActivityIndicator;
@dynamic timer;
@dynamic titleTimer;
@synthesize initialWaitOver = _initialWaitOver;
@synthesize tableBG=_tableBG;
@synthesize nameButton=_nameButton;
@synthesize manualButton=_manualButton;
@synthesize logo=_logo;


- (id)initWithTitle:(NSString *)title showDisclosureIndicators:(BOOL)show showCancelButton:(BOOL)showCancelButton {
	
	if ((self = [super initWithStyle:UITableViewStylePlain])) {
		self.title = title;
		_bonjourGames = [[NSMutableArray alloc] init];
		self.showDisclosureIndicators = show;

        //_games = [[NSMutableArray alloc] init];

		if (showCancelButton) {
			// add Cancel button as the nav bar's custom right view
			UIBarButtonItem *addButton = [[UIBarButtonItem alloc]
										  initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelAction)];
			self.navigationItem.rightBarButtonItem = addButton;
			[addButton release];
		}

		// Make sure we have a chance to discover devices before showing the user that nothing was found (yet)
		[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(initialWaitOver:) userInfo:nil repeats:NO];
        
        self.titleTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(update:) userInfo:nil repeats:YES];

	}

	return self;
}

- (NSString *)searchingForServicesString {
	return _searchingForServicesString;
}

- (void)stop
{
    //printf("STOPPING!\n");

    if (_scanSocket){
        CFSocketInvalidate(_scanSocket);
        CFRelease(_scanSocket);
        _scanSocket = NULL;
    }

    // clear any existing...
    [self stopCurrentResolve];
	[self.netServiceBrowser stop];
    self.netServiceBrowser = nil;
	[self.bonjourGames removeAllObjects];
    [self.tableView reloadData];

}

static void readCallback(CFSocketRef cfSocket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
{
    BrowserViewController *vc = (BrowserViewController*)info;
    int s = CFSocketGetNative(cfSocket);
    if (s){
        //printf("GOT DATAA!!\n");
        [vc readFromSocket:s];
    }
}


- (void) readFromSocket:(int) s
{
    char buffer[256];
    sockaddr addr;
    socklen_t l = sizeof(addr);
    int amt = static_cast<int>(recvfrom(s,buffer,sizeof(buffer),0,&addr,&l));

    if (amt == -1){
        // any case where we'd need to look at errors here?...
    }
    if (amt > 0){

        switch(buffer[0]){
            case BS_REMOTE_MSG_GAME_RESPONSE:{
                if (amt > 1){
                    // the rest of the packet is the game name
                    if (amt >= sizeof(buffer)) buffer[sizeof(buffer)-1] = 0;
                    else buffer[amt] = 0;
                    //NSString *s = [NSString stringWithUTF8String:buffer+1];
                    //[self.games addObject:s];
                    //cout << "GOT GAME RESPONSE " << buffer+1 << endl;

                    // if this entry is new, reload the list
                    bool isNew = (_games.find(buffer+1) == _games.end());
                    _games[buffer+1].lastTime = CACurrentMediaTime();
                    memcpy(&_games[buffer+1].addr,&addr,l);
                    _games[buffer+1].addrSize = l;
                    if (isNew)  [self.tableView reloadData];
                    //cout << "HEARD FRO " << (buffer+1) << " AT " << _games[buffer+1] << endl;
                    break;
                }
            }
            default: break;
        }
        //cout << "GOT DATA " << amt << endl;
        //printf("LEN %d\n",_games.size());
    }
}


- (void)start
{
   // printf("STARTING!\n");

    // create our scan socket...
    if (_scanSocket == NULL){
        CFSocketContext socketCtxt = {0, self, NULL, NULL, NULL};
        _scanSocket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_DGRAM, IPPROTO_UDP, kCFSocketReadCallBack, (CFSocketCallBack)&readCallback, &socketCtxt);;
        if (_scanSocket == NULL){
            NSLog(@"ERROR CREATING SCANNER SOCKET");
            abort();
        }
        // bind it to a any port
        if (_scanSocket != NULL){
            // bind it...
            struct sockaddr_in addr4;
            memset(&addr4, 0, sizeof(addr4));
            addr4.sin_len = sizeof(addr4);
            addr4.sin_family = AF_INET;
            addr4.sin_port = 0;
            addr4.sin_addr.s_addr = htonl(INADDR_ANY);
            NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];

            if (kCFSocketSuccess != CFSocketSetAddress(_scanSocket, (CFDataRef)address4)) {
                NSLog(@"ERROR ON CFSocketSetAddress for scan socket");
                if (_scanSocket) CFRelease(_scanSocket);
                _scanSocket = NULL;
            }
            if (_scanSocket != NULL){
                _scanSocketRaw = CFSocketGetNative(_scanSocket);
                // set broadcast..
                int opVal = 1;
                int result = setsockopt(_scanSocketRaw,SOL_SOCKET,SO_BROADCAST,&opVal,sizeof(opVal));
                if (result != 0){
                    NSLog(@"Error setting up scanner socket");
                    abort();
                }
                // wire this socket up to our run loop
                CFRunLoopRef cfrl = CFRunLoopGetCurrent();
                CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _scanSocket, 0);
                CFRunLoopAddSource(cfrl, source, kCFRunLoopCommonModes);
                CFRelease(source);
                //success = YES;
            }
        }
    }
    //printf("SO FAR SO GOOD\n");


    // clear any existing...
    [self stopCurrentResolve];
	[self.netServiceBrowser stop];
    self.netServiceBrowser = nil;
	[self.bonjourGames removeAllObjects];

    // start anew..
    [self searchForServicesOfType:[NSString stringWithFormat:@"_%@._udp.", kGameIdentifier] inDomain:@""];
}

- (void)viewDidLoad {

    [super viewDidLoad];
	UIImage *image = [UIImage imageNamed:@"tableBG.png"];


    self.tableBG = nil;
	_tableBG = [[UIImageView alloc] initWithImage:image];
	_tableBG.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
 //  _tableBG.userInteractionEnabled = YES;

    // add a logo here on iphone version..
    if(UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        float logoSize = 200;
        self.logo = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"logo.png"]] autorelease];
        _logo.autoresizingMask = (UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin
                                       | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
        _logo.frame = CGRectMake(_tableBG.bounds.size.width/2-logoSize/2,_tableBG.bounds.size.height*0.6-logoSize/2,logoSize,logoSize);
        [_tableBG addSubview:_logo];
    }

    self.navigationController.view.backgroundColor = [UIColor colorWithRed:0.7 green:0.5 blue:0.3 alpha:1];
    self.view.backgroundColor = [UIColor colorWithRed:0.7 green:0.5 blue:0.3 alpha:1];

	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    UIBarButtonItem *b = [[[UIBarButtonItem alloc] initWithTitle:@"options" style:UIBarButtonItemStylePlain target:self action:@selector(showPrefs)] autorelease];
    //[b setTitle:@"TEST" forState:UIControlStateNormal];
    self.navigationItem.rightBarButtonItem = b;

    b = [[[UIBarButtonItem alloc] initWithTitle:@"tips" style:UIBarButtonItemStylePlain target:self action:@selector(showHelp)] autorelease];
    //[b setTitle:@"TEST" forState:UIControlStateNormal];
    self.navigationItem.leftBarButtonItem = b;

  // UIButton *button = [[UIButton alloc] initWithFrame]

  // add 'change name' button...
  self.nameButton = nil;
  self.nameButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [_nameButton addTarget:self
                  action:@selector(showSetNameDialog)
        forControlEvents:UIControlEventTouchUpInside];
  NSString *s = [NSString stringWithFormat:@"Name: %@",[AppController playerName]];
  [_nameButton setTitle:s forState:UIControlStateNormal];
  // [[_nameButton layer] setBorderWidth:2.0f];

  // add manual-connect button...
  self.manualButton = nil;
  self.manualButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [_manualButton addTarget:self
                  action:@selector(showManualConnectDialog)
        forControlEvents:UIControlEventTouchUpInside];
  [_manualButton setTitle:@"Connect by Address..." forState:UIControlStateNormal];
  // [[_manualButton layer] setBorderWidth:2.0f];

}

//- (BOOL)textFieldShouldReturn:(UITextField *)textField {
//  printf("HELLO WORLD\n");
//  [textField resignFirstResponder];
//  return YES;
//}


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
  // Prevent crashing undo bug – see note below.
  if(range.length + range.location > textField.text.length)
  {
    return NO;
  }

  NSUInteger newLength = [textField.text length] + [string length] - range.length;
  return newLength <= 10;
}

- (void) showSetNameDialog
{
  _doingNameDialog = true;
  UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Player Name" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK",nil];
  alert.alertViewStyle = UIAlertViewStylePlainTextInput;
  UITextField * alertTextField = [alert textFieldAtIndex:0];
  alertTextField.delegate = self;
  alertTextField.keyboardType = UIKeyboardTypeDefault;
  alertTextField.placeholder = @"Enter a name";
  alertTextField.text = [AppController playerName];
  [alert show];
}

- (void) showManualConnectDialog
{
  _doingNameDialog = false;
  UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Connect by Address" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Connect",nil];
  alert.alertViewStyle = UIAlertViewStylePlainTextInput;
  UITextField * alertTextField = [alert textFieldAtIndex:0];
  alertTextField.keyboardType = UIKeyboardTypeDefault;
  alertTextField.placeholder = @"Enter an address";
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:@"manualAddress"]!=nil) {
    alertTextField.text = [defaults stringForKey:@"manualAddress"];
  }

  [alert show];
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
  if (buttonIndex == alertView.cancelButtonIndex) {
    // they canceled; do nothing
  } else {
    UITextField *t = [alertView textFieldAtIndex:0];
    if (t != nil) {
      // either set a name or connect to an address...
      if (_doingNameDialog) {
        [[NSUserDefaults standardUserDefaults] setObject:t.text forKey:@"playerName"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSString *s = [NSString stringWithFormat:@"Name: %@",[AppController playerName]];
        [_nameButton setTitle:s forState:UIControlStateNormal];

      } else {
        [[NSUserDefaults standardUserDefaults] setObject:t.text forKey:@"manualAddress"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        struct addrinfo hints, *res, *p;
        int status;
        char ipstr[INET6_ADDRSTRLEN];
        memset(&hints, 0, sizeof hints);
        hints.ai_family = AF_UNSPEC; // AF_INET or AF_INET6 to force version
        hints.ai_socktype = SOCK_STREAM;
        if ((status = getaddrinfo(t.text.UTF8String, NULL, &hints, &res)) != 0) {
          // fprintf(stderr, "getaddrinfo: %s\n", strerror(status));
          return;
        }
        //printf("IP addresses:\n\n");
        for(p = res;p != NULL; p = p->ai_next) {
          void *addr;
          char *ipver;
          // get the pointer to the address itself,
          // different fields in IPv4 and IPv6:
          if (p->ai_family == AF_INET) { // IPv4
            struct sockaddr_in *ipv4 = (struct sockaddr_in *)p->ai_addr;
            addr = &(ipv4->sin_addr);
            ipv4->sin_port = htons(43210);
            // ipver = "IPv4";
          } else { // IPv6
            struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)p->ai_addr;
            addr = &(ipv6->sin6_addr);
            ipv6->sin6_port = htons(43210);
            // ipver = "IPv6";
          }

          //RemoteViewController *r = [[[RemoteViewController alloc] initWithAddress:addr andSize:size] autorelease];
          //[_navController pushViewController:r animated:YES];

          // BrowserViewController *bvc = nil;
          [[AppController sharedApp] browserViewController:self didSelectAddress:*p->ai_addr withSize:p->ai_addrlen];
          break; // only do first

          // convert the IP to a string and print it:
          inet_ntop(p->ai_family, addr, ipstr, sizeof ipstr);
          printf("  %s: %s\n", ipver, ipstr);
        }
        
        freeaddrinfo(res); // free the linked list
      }
    }
  }
}

- (void) showHelp
{
    //- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil

    HelpViewController *vc = [[[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil] autorelease];
    //mmvc.matchmakerDelegate = self;
    vc.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;

	[self presentModalViewController:vc animated:YES];

    //[[AppController sharedApp] showPrefsWithDelegate:self];
}

- (void) showPrefs
{
    [[AppController sharedApp] showPrefsWithDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self start];

    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.7 alpha:1];

    // fade in our bg view
	[self.navigationController.view insertSubview:_tableBG atIndex:1];
	CGRect imageframe = self.navigationController.view.bounds;
	_tableBG.frame = imageframe;
	_tableBG.alpha = 0.0;
    if (animated) [UIView animateWithDuration:0.3 animations:^{ _tableBG.alpha = 1.0;} completion:^(BOOL completed){}];
    else _tableBG.alpha = 1.0;

  // add our name and manual-connect buttons...
  [self.navigationController.view addSubview:_nameButton];
  _nameButton.frame = CGRectMake(10.0, _tableBG.bounds.size.height - 50, 200.0, 40.0);
  [self.navigationController.view addSubview:_manualButton];
  _manualButton.frame = CGRectMake(_tableBG.bounds.size.width - 210, _tableBG.bounds.size.height - 50, 200.0, 40.0);


}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self stop];
    [UIView animateWithDuration:0.3 animations:^{ _tableBG.alpha = 0.0;} completion:^(BOOL completed){[_tableBG removeFromSuperview];}];
  [_nameButton removeFromSuperview];
  [_manualButton removeFromSuperview];

}

// Holds the string that's displayed in the table view during service discovery.
- (void)setSearchingForServicesString:(NSString *)searchingForServicesString {
	if (_searchingForServicesString != searchingForServicesString) {
		[_searchingForServicesString release];
		_searchingForServicesString = [searchingForServicesString copy];

        // If there are no services, reload the table to ensure that searchingForServicesString appears.
		if ([self.bonjourGames count] == 0) {
			[self.tableView reloadData];
		}
	}
}

- (NSString *)ownName {
	return _ownName;
}

// Holds the string that's displayed in the table view during service discovery.
- (void)setOwnName:(NSString *)name {
	if (_ownName != name) {
		_ownName = [name copy];
		
		if (self.ownEntry)
			[self.bonjourGames addObject:self.ownEntry];
		
		NSNetService* service;
		
		for (service in self.bonjourGames) {
			if ([service.name isEqual:name]) {
				self.ownEntry = service;
				[_bonjourGames removeObject:service];
				break;
			}
		}
		
		[self.tableView reloadData];
	}
}

// Creates an NSNetServiceBrowser that searches for services of a particular type in a particular domain.
// If a service is currently being resolved, stop resolving it and stop the service browser from
// discovering other services.
- (BOOL)searchForServicesOfType:(NSString *)type inDomain:(NSString *)domain {
	
	[self stopCurrentResolve];
	[self.netServiceBrowser stop];
	[self.bonjourGames removeAllObjects];

	NSNetServiceBrowser *aNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
	if(!aNetServiceBrowser) {
        // The NSNetServiceBrowser couldn't be allocated and initialized.
		return NO;
	}

	aNetServiceBrowser.delegate = self;
	self.netServiceBrowser = aNetServiceBrowser;
	[aNetServiceBrowser release];
	[self.netServiceBrowser searchForServicesOfType:type inDomain:domain];
	[self.tableView reloadData];
	return YES;
}

- (NSTimer *)timer {
	return _timer;
}

// When this is called, invalidate the existing timer before releasing it.
- (void)setTimer:(NSTimer *)newTimer {
	[_timer invalidate];
	[newTimer retain];
	[_timer release];
	_timer = newTimer;
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    if (_games.size() > 0){
        return _games.size();
    }
    else{
        // If there are no services and searchingForServicesString is set, show one row to tell the user.
        NSUInteger count = [self.bonjourGames count];

        if (count == 0 && self.searchingForServicesString && self.initialWaitOver)
            return 1;
        else if (count == 0)
            return 0;
        
        return count;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{  
    return 80; //returns floating point which will be used for a cell row height at specified row index  
} 

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	static NSString *tableCellIdentifier = @"UITableViewCell";
	UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:tableCellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tableCellIdentifier] autorelease];
        //cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textAlignment = UITextAlignmentCenter;
        cell.backgroundColor = [UIColor clearColor];


        //cell.textLabel.frame.origin.x += 100;
        //CGRect frame = cell.textLabel.frame;
        //frame.size.width -= 60;
        //frame.origin.x += 30;
        //cell.textLabel.frame = frame;
	}

	//NSUInteger count = [self.bonjourGames count];
	if ([self.bonjourGames count] == 0 and _games.size() == 0 and  self.searchingForServicesString) {
        // If there are no services and searchingForServicesString is set, show one row explaining that to the user.
        
        // doing this super-hacky for now with whatever space counts keep the text from jittering - need to add custom text view
        // and just set it left-aligned.
        if ([[UIScreen mainScreen] scale] > 1.0){
            if (_dotCount == 0)
                cell.textLabel.text = [NSString stringWithFormat: @"%@",self.searchingForServicesString];
            else if (_dotCount == 1)
                cell.textLabel.text = [NSString stringWithFormat: @".%@.",self.searchingForServicesString];
            else if (_dotCount == 2)
                cell.textLabel.text = [NSString stringWithFormat: @"..%@..",self.searchingForServicesString];
            else if (_dotCount == 3)
                cell.textLabel.text = [NSString stringWithFormat: @"...%@...",self.searchingForServicesString];
        }
        else{
            if (_dotCount == 0)
                cell.textLabel.text = [NSString stringWithFormat: @"%@",self.searchingForServicesString];
            else if (_dotCount == 1)
                cell.textLabel.text = [NSString stringWithFormat: @".%@.",self.searchingForServicesString];
            else if (_dotCount == 2)
                cell.textLabel.text = [NSString stringWithFormat: @"..%@..",self.searchingForServicesString];
            else if (_dotCount == 3)
                cell.textLabel.text = [NSString stringWithFormat: @"...%@...",self.searchingForServicesString];
            
        }
        //cell.textLabel.text = @"";

        //cell.textLabel.text = self.searchingForServicesString;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:24];
        cell.backgroundColor = [UIColor clearColor];

		cell.textLabel.textColor = [UIColor colorWithRed:0 green:0.1 blue:0.2 alpha:0.5];
		cell.accessoryType = UITableViewCellAccessoryNone;
        
		// Make sure to get rid of the activity indicator that may be showing if we were resolving cell zero but
		// then got didRemoveService callbacks for all services (e.g. the network connection went down).
		if (cell.accessoryView)
			cell.accessoryView = nil;
		return cell;
	}

    // new simple stuff
    if (_games.size() > 0){
        int index = 0;
        cell.textLabel.text = @"unknown";
        for (map<string,BSRemoteGameEntry>::iterator i = _games.begin(); i != _games.end(); i++){
            if (index == indexPath.row) cell.textLabel.text = [NSString stringWithUTF8String:i->first.c_str()];
            index++;
        }
        cell.accessoryView = nil;
    }
    // old bonjour stuff
    else{
        // Set up the text for the cell
        NSNetService *service = [self.bonjourGames objectAtIndex:indexPath.row];
        cell.textLabel.text = [service name];
        cell.accessoryType = self.showDisclosureIndicators ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

        // Note that the underlying array could have changed, and we want to show the activity indicator on the correct cell
        if (self.needsActivityIndicator && self.currentResolve == service) {
            if (!cell.accessoryView) {
                CGRect frame = CGRectMake(0.0, 0.0, kProgressIndicatorSize, kProgressIndicatorSize);
                UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithFrame:frame];
                [spinner startAnimating];
                spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
                [spinner sizeToFit];
                spinner.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
                                            UIViewAutoresizingFlexibleRightMargin |
                                            UIViewAutoresizingFlexibleTopMargin |
                                            UIViewAutoresizingFlexibleBottomMargin);
                cell.accessoryView = spinner;
                [spinner release];
            }
        } else if (cell.accessoryView) {
            cell.accessoryView = nil;
        }
    }
    cell.textLabel.textColor = [UIColor blackColor];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:24];

	return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	// Ignore the selection if there are no services as the searchingForServicesString cell
	// may be visible and tapping it would do nothing
	if ([self.bonjourGames count] == 0 and _games.size() == 0)
		return nil;

	return indexPath;
}

- (void)stopCurrentResolve {

	self.needsActivityIndicator = NO;
	self.timer = nil;

	[self.currentResolve stop];
	self.currentResolve = nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    // new simple style
    if (_games.size() > 0){
        int index = 0;
        for (map<string,BSRemoteGameEntry>::iterator i = _games.begin(); i != _games.end(); i++){
            if (index == indexPath.row){
                //cout << "THEY TAPPED ON " << i->first << endl;
                [self.delegate browserViewController:self didSelectAddress:i->second.addr withSize:i->second.addrSize];
                break;
            }
            index++;
        }
    }
    else{
        // If another resolve was running, stop it & remove the activity indicator from that cell
        if (self.currentResolve) {
            // Get the indexPath for the active resolve cell
            NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[self.bonjourGames indexOfObject:self.currentResolve] inSection:0];

            // Stop the current resolve, which will also set self.needsActivityIndicator
            [self stopCurrentResolve];

            // If we found the indexPath for the row, reload that cell to remove the activity indicator
            if (indexPath.row != NSNotFound)
                [self.tableView reloadRowsAtIndexPaths:[NSArray	arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
        }

        // Then set the current resolve to the service corresponding to the tapped cell
        self.currentResolve = [self.bonjourGames objectAtIndex:indexPath.row];
        [self.currentResolve setDelegate:self];

        // Attempt to resolve the service. A value of 0.0 sets an unlimited time to resolve it. The user can
        // choose to cancel the resolve by selecting another service in the table view.
        [self.currentResolve resolveWithTimeout:0.0];

        // Make sure we give the user some feedback that the resolve is happening.
        // We will be called back asynchronously, so we don't want the user to think we're just stuck.
        // We delay showing this activity indicator in case the service is resolved quickly.
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(showWaiting:) userInfo:self.currentResolve repeats:NO];
    }
}

// If necessary, sets up state to show an activity indicator to let the user know that a resolve is occuring.
- (void)showWaiting:(NSTimer *)timer {
    
	if (timer == self.timer) {
		NSNetService* service = (NSNetService*)[self.timer userInfo];
		if (self.currentResolve == service) {
			self.needsActivityIndicator = YES;

			NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[self.bonjourGames indexOfObject:self.currentResolve] inSection:0];
			if (indexPath.row != NSNotFound) {
				[self.tableView reloadRowsAtIndexPaths:[NSArray	arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
				// Deselect the row since the activity indicator shows the user something is happening.
				[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
			}
		}
	}
}

- (void)update:(NSTimer *)timer {
  _dotCount = (_dotCount+1)%4;
  
  if (_scanSocket != NULL){
    
    // broadcast game query packets to all our network interfaces
    struct ifaddrs *ifaddr;
    if (getifaddrs(&ifaddr) != -1) {
      int i = 0;
      for (ifaddrs *ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        int family = ifa->ifa_addr->sa_family;
        if (family == AF_INET){
          if (ifa->ifa_addr != NULL) {
            sockaddr_in broadcastAddr;
            memcpy(&broadcastAddr,ifa->ifa_addr,sizeof(sockaddr_in));
            
            UInt32 addr = ntohl(((sockaddr_in*)ifa->ifa_addr)->sin_addr.s_addr);
            UInt32 subnet = ntohl(((sockaddr_in*)ifa->ifa_netmask)->sin_addr.s_addr);
            UInt32 broadcast = addr | (~subnet);
            
            broadcastAddr.sin_addr.s_addr = htonl(broadcast);
            broadcastAddr.sin_port = htons(43210);
            
            UInt8 data[1] = {BS_REMOTE_MSG_GAME_QUERY};
            
            int err = static_cast<int>(sendto(_scanSocketRaw,data,1,0,(sockaddr*)&broadcastAddr,sizeof(broadcastAddr)));
            if (err == -1) NSLog(@"ERROR %d on sendto for scanner socket\n",errno);
            
            //cout << "ADDR IS " << ((addr>>24)&0xFF) << "." << ((addr>>16)&0xFF) << "." << ((addr>>8)&0xFF) << "." << ((addr>>0)&0xFF) << endl;
            //cout << "NETMASK IS " << ((subnet>>24)&0xFF) << "." << ((subnet>>16)&0xFF) << "." << ((subnet>>8)&0xFF) << "." << ((subnet>>0)&0xFF) << endl;
            //cout << "BROADCAST IS " << ((broadcast>>24)&0xFF) << "." << ((broadcast>>16)&0xFF) << "." << ((broadcast>>8)&0xFF) << "." << ((broadcast>>0)&0xFF) << endl;
            i++;
          }
        }
      }
    }
  }
  //cout <<"CHECKING FOR OLD GAMES"<< endl;
  
  CFTimeInterval curTime = CACurrentMediaTime();
  
  // remove games from our list that we havn't heard from in a while
  map<string,BSRemoteGameEntry>::iterator i = _games.begin();
  map<string,BSRemoteGameEntry>::iterator iNext;
  bool changed = false;
  while (i != _games.end()){
    iNext = i;
    iNext++;
    if (curTime - i->second.lastTime > 3.0){
      _games.erase(i);
      changed = true;
    }
    i = iNext;
  }
  
  if (changed) [self.tableView reloadData];
  
  // updates our 'searching' txt
  if ([self.bonjourGames count] == 0 and _games.size() == 0) {
    [self.tableView reloadData];
  }
  
}

- (void)initialWaitOver:(NSTimer *)timer {
	self.initialWaitOver= YES;
	if (![self.bonjourGames count])
		[self.tableView reloadData];
}

- (void)sortAndUpdateUI {
	// Sort the services by name.
	[self.bonjourGames sortUsingSelector:@selector(localizedCaseInsensitiveCompareByName:)];
	[self.tableView reloadData];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing {
	// If a service went away, stop resolving it if it's currently being resolved,
	// remove it from the list and update the table view if no more events are queued.
	
	if (self.currentResolve && [service isEqual:self.currentResolve]) {
		[self stopCurrentResolve];
	}
	[self.bonjourGames removeObject:service];
	if (self.ownEntry == service)
		self.ownEntry = nil;
	
	// If moreComing is NO, it means that there are no more messages in the queue from the Bonjour daemon, so we should update the UI.
	// When moreComing is set, we don't update the UI so that it doesn't 'flash'.
	if (!moreComing) {
		[self sortAndUpdateUI];
	}
}	

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing {
	// If a service came online, add it to the list and update the table view if no more events are queued.
	if ([service.name isEqual:self.ownName])
		self.ownEntry = service;
	else
		[self.bonjourGames addObject:service];

	// If moreComing is NO, it means that there are no more messages in the queue from the Bonjour daemon, so we should update the UI.
	// When moreComing is set, we don't update the UI so that it doesn't 'flash'.
	if (!moreComing) {
		[self sortAndUpdateUI];
	}
}	

// This should never be called, since we resolve with a timeout of 0.0, which means indefinite
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
	[self stopCurrentResolve];
	[self.tableView reloadData];
}

- (void)netServiceDidResolveAddress:(NSNetService *)service {
	assert(service == self.currentResolve);
	
	[service retain];
	[self stopCurrentResolve];
	
	[self.delegate browserViewController:self didResolveInstance:service];
	[service release];
}

- (void)cancelAction {
	[self.delegate browserViewController:self didResolveInstance:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientationIn
{
    // iPad works any which way.. iPhone only landscape
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    } else {
        return (interfaceOrientationIn == UIInterfaceOrientationLandscapeLeft || interfaceOrientationIn == UIInterfaceOrientationLandscapeRight);
    }
}

- (void)dealloc {
	// Cleanup any running resolve and free memory
	[self stopCurrentResolve];
	self.bonjourGames = nil;
    //self.games = nil;
	[self.netServiceBrowser stop];
	self.netServiceBrowser = nil;
	[_searchingForServicesString release];
	[_ownName release];
	[_ownEntry release];
    self.tableBG = nil;
    self.logo = nil;
    self.titleTimer = nil;

	
	[super dealloc];
}

@end
