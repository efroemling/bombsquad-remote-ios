#import "HelpViewController.h"

@implementation HelpViewController

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
  }
  return self;
}

- (void)dealloc {
  [super dealloc];
}

- (IBAction)closePressed:(id)caller {
  [self dismissModalViewControllerAnimated:YES];
}

- (void)didReceiveMemoryWarning {
  // Releases the view if it doesn't have a superview.
  [super didReceiveMemoryWarning];

  // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view from its nib.

  // Custom initialization
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    _text.font = [UIFont systemFontOfSize:16];
  } else {
    _text.font = [UIFont systemFontOfSize:12];
  }
}

- (void)viewDidUnload {
  [super viewDidUnload];
  // Release any retained subviews of the main view.
  // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:
    (UIInterfaceOrientation)interfaceOrientationIn {
  // iPad works any which way.. iPhone only landscape
  // FIXME - can't we just specify this in the info.plist?
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    return YES;
  } else {
    return (interfaceOrientationIn == UIInterfaceOrientationLandscapeLeft ||
            interfaceOrientationIn == UIInterfaceOrientationLandscapeRight);
  }
}

@end
