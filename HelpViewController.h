#import <UIKit/UIKit.h>


@interface HelpViewController : UIViewController {
    @private
    
    IBOutlet UITextView *_text;
}

- (IBAction) closePressed: (id) caller;

@end
