#import "AppController.h"
#import <UIKit/UIKit.h>
#include <netinet/in.h>

#define REMOTE_VIEW_CONTROLLER_MAX_ADDRESSES 10

enum BSRemoteMsg {
  BS_REMOTE_MSG_PING,
  BS_REMOTE_MSG_PONG,
  BS_REMOTE_MSG_ID_REQUEST,
  BS_REMOTE_MSG_ID_RESPONSE,
  BS_REMOTE_MSG_DISCONNECT,
  BS_REMOTE_MSG_STATE,
  BS_REMOTE_MSG_STATE_ACK,
  BS_REMOTE_MSG_DISCONNECT_ACK,
  BS_REMOTE_MSG_GAME_QUERY,
  BS_REMOTE_MSG_GAME_RESPONSE,

  BS_REMOTE_MSG_STATE2 = 10
};

@interface RemoteViewController
    : UIViewController <NSStreamDelegate, UIAccelerometerDelegate> {

  BOOL _wantToDie;
  BOOL _canDie;
  BOOL _dying;
  BOOL _axisSnapping;
  BOOL _tiltMode;
  BOOL _floating;
  // float           _tiltNeutralX;
  float _tiltNeutralY;
  float _tiltNeutralZ;
  UInt32 _buttonStateV1;
  UInt32 _buttonStateV2;
  float _dPadStateH;
  float _dPadStateV;
  BOOL _connected;

  UITouch *_dPadTouch;
  float _prevAccelX;
  float _prevAccelY;

  float _dPadBaseX;
  float _dPadBaseY;
  CFTimeInterval _lastDPadTouchTime;
  float _lastDPadTouchPosX;
  float _lastDPadTouchPosY;
  BOOL _dPadHasMoved;
  BOOL _needToUpdateDPadBase;
  BOOL _waitingForIDResponse;

  BOOL _run1Pressed;
  BOOL _run2Pressed;
  BOOL _run3Pressed;
  BOOL _run4Pressed;

  CFSocketRef _cfSocket4;
  CFSocketRef _cfSocket6;
  // int             _socketFamily;
  int _socket4;
  int _socket6;
  int _id;
  BOOL _usingProtocolV2;
  int _idRequestKey;
  CFTimeInterval _lastContactTime;
  CFTimeInterval _lastNullStateTime;
  UInt8 _nextState;
  UInt8 _requestedState;

  // BOOL            _usingV6;
  BOOL _haveV4;
  BOOL _haveV6;
  UInt16 _statesV1[256];
  UInt32 _statesV2[256];
  CFTimeInterval _stateBirthTimes[256];
  CFTimeInterval _stateLastSentTimes[256];
  UInt32 _lastSentState;
  CFTimeInterval _lastSendTime;

  CFTimeInterval _currentLag;
  CFTimeInterval _lastLagUpdateTime;
  CFTimeInterval _averageLag;

  struct sockaddr _addresses[REMOTE_VIEW_CONTROLLER_MAX_ADDRESSES];
  int _addressSizes[REMOTE_VIEW_CONTROLLER_MAX_ADDRESSES];

  float _controllerDPadSensitivity;

  // struct sockaddr_in _targetAddr;
  // int _targetAddrSize;
  unsigned int _addrCount;

  BOOL _wantToLeave;
  CFTimeInterval _leavingStartTime;

  // CGRect _buttonFrame;

  float _ping;
  BOOL _newStyle;
}

+ (RemoteViewController *)sharedRemoteViewController;

- (id)initWithAddress:(struct sockaddr)a andSize:(int)s;
- (void)tiltModeChanged:(NSNumber *)enabled;
- (void)controllerDPadSensitivityChanged:(float)value;

- (void)joystickFloatingChanged:(NSNumber *)enabled;
- (void)tiltNeutralChangedToY:(float)y z:(float)z;
- (void)doBecomeActive;

- (void)hardwareDPadChangedX:(float)x andY:(float)y;
- (void)hardwareStickChangedX:(float)x andY:(float)y;

- (void)handleJumpPress;
- (void)handleJumpRelease;

- (void)handlePunchPress;
- (void)handlePunchRelease;

- (void)handleThrowPress;
- (void)handleThrowRelease;

- (void)handleBombPress;
- (void)handleBombRelease;

- (void)handleRun1Press;
- (void)handleRun1Release;

- (void)handleRun2Press;
- (void)handleRun2Release;

- (void)handleRun3Press;
- (void)handleRun3Release;

- (void)handleRun4Press;
- (void)handleRun4Release;

- (void)handleMenu;

@property(nonatomic, retain) NSTimer *processTimer;
//@property (nonatomic, retain) UIImageView *buttonBackingImage;
@property(nonatomic, retain) UIView *buttonBacking;

@property(nonatomic, retain) UIImageView *buttonImagePunch;
@property(nonatomic, retain) UIImageView *buttonImagePunchPressed;
@property(nonatomic, retain) UIImageView *buttonImageJump;
@property(nonatomic, retain) UIImageView *buttonImageJumpPressed;
@property(nonatomic, retain) UIImageView *buttonImageThrow;
@property(nonatomic, retain) UIImageView *buttonImageThrowPressed;
@property(nonatomic, retain) UIImageView *buttonImageBomb;
@property(nonatomic, retain) UIImageView *buttonImageBombPressed;
//@property (nonatomic, retain) UIImageView *dPadBackingImage;
@property(nonatomic, retain) UIView *dPadBacking;

@property(nonatomic, retain) UIImageView *dPadThumbImage;
@property(nonatomic, retain) UIImageView *dPadThumbPressedImage;
@property(nonatomic, retain) UIImageView *dPadCenterImage;
@property(nonatomic, retain) UIImageView *bgImage;
@property(nonatomic, retain) UIActivityIndicatorView *activityIndicator;

@property(nonatomic, retain) UILabel *lagMeter;

@property(nonatomic, retain) NSMutableSet *validTouches;
@property(nonatomic, retain) NSMutableSet *validMovedTouches;

//@property (nonatomic, retain) UIImageView *logoImage;

@end
