#import "ScanDeviceViewController.h"
#import "LocalizationHelper.h"
#import "LocalizationMacros.h"
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>

#if __has_include("SDKDemo-Swift.h")
#import "SDKDemo-Swift.h"
#endif

#if __has_include("SDKDemoInternal-Swift.h")
#import "SDKDemoInternal-Swift.h"
#endif


@interface DeviceCell : UITableViewCell

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UILabel *snLabel;
@property (nonatomic, strong) UILabel *bindStatusLabel;
@property (nonatomic, strong) UIButton *connectButton;
@property (nonatomic, strong) UIView *bindStatusIconView;
@property (nonatomic, strong) BleDevice *bleDevice;
@property (nonatomic, weak) ScanDeviceViewController* controller;
@property (nonatomic, copy) void (^connectButtonTapped)(BleDevice * device);

@end

@implementation DeviceCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    // Container View
    self.containerView = [[UIView alloc] init];
    self.containerView.backgroundColor = [UIColor whiteColor];
    self.containerView.layer.cornerRadius = 12;
    self.containerView.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.1].CGColor;
    self.containerView.layer.shadowOffset = CGSizeMake(0, 2);
    self.containerView.layer.shadowOpacity = 1;
    self.containerView.layer.shadowRadius = 4;
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.containerView];
    
    // Name Label
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.nameLabel.textColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.nameLabel];
    
    // Info Label
    self.infoLabel = [[UILabel alloc] init];
    self.infoLabel.font = [UIFont systemFontOfSize:14];
    self.infoLabel.textColor = [UIColor colorWithRed:0.45 green:0.45 blue:0.45 alpha:1.0];
    self.infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.infoLabel];
    
    // SN Label
    self.snLabel = [[UILabel alloc] init];
    self.snLabel.font = [UIFont systemFontOfSize:13];
    self.snLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    self.snLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.snLabel.numberOfLines = 1;
    self.snLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.containerView addSubview:self.snLabel];
    
    // Bind Status Label
    self.bindStatusLabel = [[UILabel alloc] init];
    self.bindStatusLabel.font = [UIFont systemFontOfSize:13];
    self.bindStatusLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    self.bindStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.bindStatusLabel];
    
    // Bind Status Icon View
    self.bindStatusIconView = [[UIView alloc] init];
    self.bindStatusIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bindStatusIconView.layer.cornerRadius = 5;
    [self.containerView addSubview:self.bindStatusIconView];
    
    // Connect Button
    self.connectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.connectButton setTitle:LocalizedString(@"common.connect") forState:UIControlStateNormal];
    [self.connectButton setTitleColor:[UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    self.connectButton.backgroundColor = [UIColor whiteColor];
    self.connectButton.layer.cornerRadius = 8;
    self.connectButton.layer.borderWidth = 1.5;
    self.connectButton.layer.borderColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0].CGColor;
    self.connectButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.connectButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.connectButton addTarget:self action:@selector(connectButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:self.connectButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.containerView.topAnchor constant:16],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor constant:16],
        [self.nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.connectButton.leadingAnchor constant:-16],
        
        [self.infoLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:8],
        [self.infoLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.infoLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.connectButton.leadingAnchor constant:-16],
        
        [self.snLabel.topAnchor constraintEqualToAnchor:self.infoLabel.bottomAnchor constant:6],
        [self.snLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.snLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.connectButton.leadingAnchor constant:-16],
        
        [self.bindStatusLabel.topAnchor constraintEqualToAnchor:self.snLabel.bottomAnchor constant:6],
        [self.bindStatusLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.bindStatusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.connectButton.leadingAnchor constant:-16],
        [self.bindStatusLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.containerView.bottomAnchor constant:-16],
        
        [self.bindStatusIconView.centerYAnchor constraintEqualToAnchor:self.bindStatusLabel.centerYAnchor],
        [self.bindStatusIconView.leadingAnchor constraintEqualToAnchor:self.bindStatusLabel.trailingAnchor constant:12],
        [self.bindStatusIconView.widthAnchor constraintEqualToConstant:10],
        [self.bindStatusIconView.heightAnchor constraintEqualToConstant:10],
        
        [self.connectButton.centerYAnchor constraintEqualToAnchor:self.containerView.centerYAnchor],
        [self.connectButton.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-16],
        [self.connectButton.widthAnchor constraintEqualToConstant:80],
        [self.connectButton.heightAnchor constraintEqualToConstant:36]
    ]];
}

- (void)configureWithDevice:(BleDevice *)device controller:(ScanDeviceViewController*)controller{
    self.bleDevice = device;
    
    self.nameLabel.text = self.bleDevice.name;
    self.infoLabel.text = [NSString stringWithFormat:LocalizedString(@"ble.device.signal_strength"), (long)self.bleDevice.rssi];
    self.snLabel.text = [NSString stringWithFormat:LocalizedString(@"ble.device.serial_number"), self.bleDevice.serialNumber];
    BOOL isUnbound = self.bleDevice.bindCode == 0;
    self.bindStatusLabel.text = isUnbound ?
        LocalizedString(@"ble.device.bind_status.unbound") :
        LocalizedString(@"ble.device.bind_status.bound");
    self.bindStatusIconView.backgroundColor = isUnbound ?
        [UIColor colorWithRed:39/255.0 green:174/255.0 blue:96/255.0 alpha:1.0] :
        [UIColor clearColor];
    self.bindStatusIconView.hidden = !isUnbound;
    
    // Add breathing animation if device is unbound
    if (isUnbound) {
        [self startBreathingAnimation];
    } else {
        [self stopBreathingAnimation];
    }
    
    [self.snLabel sizeToFit];
    self.controller = controller;
}

- (void)connectButtonAction {
    if (self.controller && self.bleDevice) {
        [self.controller connectToDevice:self.bleDevice];
    }
    
    //    //[FIRAnalytics logEventWithName:@"connect_device_tapped"
    //                        parameters:@{
    //                                     }];
    //
    //    [PlaudSDKLogger logEvent:@"connect_device_tapped"  parameters:@{
    //    }];
    
}

- (void)startBreathingAnimation {
    // Remove any existing animations
    [self.bindStatusIconView.layer removeAllAnimations];
    
    // Create breathing animation
    CABasicAnimation *breathingAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    breathingAnimation.fromValue = @(1.0);
    breathingAnimation.toValue = @(0.2);
    breathingAnimation.duration = 0.6;
    breathingAnimation.autoreverses = YES;
    breathingAnimation.repeatCount = HUGE_VALF;
    breathingAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    // Add animation to layer
    [self.bindStatusIconView.layer addAnimation:breathingAnimation forKey:@"breathing"];
}

- (void)stopBreathingAnimation {
    [self.bindStatusIconView.layer removeAllAnimations];
}

@end


@interface ScanDeviceViewController() <PlaudDeviceAgentProtocol>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<BleDevice *> *devices;
@property (nonatomic, strong) PlaudDeviceAgent *deviceAgent;
@property (nonatomic, strong) UIView *toastView;
@property (nonatomic, strong) UILabel *toastLabel;
@property (nonatomic, strong) BleDevice* currentDevice;
@property (nonatomic, assign)  BOOL autoRefresh;
@property (nonatomic, assign)  BOOL hasEverFoundDevices;

// Guide view properties
@property (nonatomic, strong) UIView *guideView;
@property (nonatomic, strong) UIScrollView *guideScrollView;
@property (nonatomic, strong) UIView *guideContentView;
@property (nonatomic, strong) UILabel *searchingLabel;
@property (nonatomic, strong) UIImageView *deviceImageView;
@property (nonatomic, strong) UIButton *helpButton;

@end


@implementation ScanDeviceViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _autoRefresh = YES;
        _hasEverFoundDevices = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.devices = [NSMutableArray array];
    self.deviceAgent = [PlaudDeviceAgent shared];
    self.deviceAgent.delegate = self;
    [self setupUI];
    [self setupTableView];
    
    // Initially show guide view since no devices are found yet
    [self updateViewsVisibility];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self updateTitleForGuideView:!self.guideView.hidden];
    
    // Parent return, reset delegate
    self.deviceAgent = [PlaudDeviceAgent shared];
    self.deviceAgent.delegate = self;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self stopScanning];
}

- (void)updateTitleForGuideView:(BOOL)isGuideVisible {
    NSString *titleText = isGuideVisible ? LocalizedString(@"ble.scan.searching") : LocalizedString(@"ble.scan.title");
    
    // Set navigation bar title style
    UIView *titleContainer = [[UIView alloc] init];
    titleContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = titleText;
    titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [titleContainer addSubview:titleLabel];
    
    // Use auto layout constraints to ensure title is centered
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.centerXAnchor constraintEqualToAnchor:titleContainer.centerXAnchor],
        [titleLabel.centerYAnchor constraintEqualToAnchor:titleContainer.centerYAnchor],
        [titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:titleContainer.leadingAnchor],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:titleContainer.trailingAnchor],
        [titleContainer.widthAnchor constraintEqualToConstant:200], // Set appropriate fixed width
        [titleContainer.heightAnchor constraintEqualToConstant:44]
    ]];
    
    self.navigationItem.titleView = titleContainer;
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor colorWithRed:0.98 green:0.98 blue:0.98 alpha:1.0];
    
    [self updateTitleForGuideView:NO];
    
    // Add refresh button
    UIButton *refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [refreshButton setImage:[UIImage systemImageNamed:@"arrow.clockwise"] forState:UIControlStateNormal];
    [refreshButton setTitle:[NSString stringWithFormat:@"%@ ", LocalizedString(@"common.refresh")] forState:UIControlStateNormal];
    [refreshButton setTitleColor:[UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    refreshButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [refreshButton addTarget:self action:@selector(refreshButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    // Set button size
    [refreshButton sizeToFit];
    CGFloat buttonWidth = refreshButton.frame.size.width + 24;
    CGFloat buttonHeight = 44;
    refreshButton.frame = CGRectMake(0, 0, buttonWidth, buttonHeight);
    
    // Set spacing between button image and text
    refreshButton.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
    refreshButton.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, -4);
    refreshButton.contentEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 8);
    
    UIBarButtonItem *refreshBarButton = [[UIBarButtonItem alloc] initWithCustomView:refreshButton];
    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spacer.width = -8;
    self.navigationItem.rightBarButtonItems = @[spacer, refreshBarButton];
    
    // Initialize Toast view
    [self setupToastView];
    
    // Setup guide view
    [self setupGuideView];
}

- (void)setupToastView {
    if (self.toastView) {
        [self.toastView removeFromSuperview];
        self.toastView = nil;
    }
    
    self.toastView = [[UIView alloc] init];
    self.toastView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    self.toastView.layer.cornerRadius = 10;
    self.toastView.clipsToBounds = YES;
    self.toastView.translatesAutoresizingMaskIntoConstraints = NO;
    self.toastView.alpha = 0;
    
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [window addSubview:self.toastView];
    
    self.toastLabel = [[UILabel alloc] init];
    self.toastLabel.textColor = [UIColor whiteColor];
    self.toastLabel.font = [UIFont systemFontOfSize:15];
    self.toastLabel.textAlignment = NSTextAlignmentCenter;
    self.toastLabel.numberOfLines = 0;
    self.toastLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toastView addSubview:self.toastLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.toastView.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
        [self.toastView.centerYAnchor constraintEqualToAnchor:window.centerYAnchor],
        [self.toastView.widthAnchor constraintLessThanOrEqualToConstant:280],
        [self.toastView.leadingAnchor constraintGreaterThanOrEqualToAnchor:window.leadingAnchor constant:40],
        [self.toastView.trailingAnchor constraintLessThanOrEqualToAnchor:window.trailingAnchor constant:-40],
        
        [self.toastLabel.topAnchor constraintEqualToAnchor:self.toastView.topAnchor constant:12],
        [self.toastLabel.leadingAnchor constraintEqualToAnchor:self.toastView.leadingAnchor constant:16],
        [self.toastLabel.trailingAnchor constraintEqualToAnchor:self.toastView.trailingAnchor constant:-16],
        [self.toastLabel.bottomAnchor constraintEqualToAnchor:self.toastView.bottomAnchor constant:-12]
    ]];
}

- (void)showToastWithMessage:(NSString *)message {
    if (!message || message.length == 0) {
        return;
    }
    
            // Cancel previous show and hide operations
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideToast) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showToastWithMessage:) object:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Ensure toastView is initialized
        if (!self.toastView) {
            [self setupToastView];
        }
        
        // If currently showing animation, complete current animation first
        if (self.toastView.alpha > 0) {
            [UIView animateWithDuration:0.15 animations:^{
                self.toastView.alpha = 0.0;
            } completion:^(BOOL finished) {
                [self showNewToast:message];
            }];
        } else {
            [self showNewToast:message];
        }
    });
}

- (void)showNewToast:(NSString *)message {
    self.toastLabel.text = message;
    [self.toastLabel sizeToFit];
    
    // Show animation
    [UIView animateWithDuration:0.25 animations:^{
        self.toastView.alpha = 1.0;
    } completion:^(BOOL finished) {
        // Auto hide after 2 seconds
        [self performSelector:@selector(hideToast) withObject:nil afterDelay:2.0];
    }];
}

- (void)hideToast {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            self.toastView.alpha = 0.0;
        }];
    });
}

- (void)setupGuideView {
    // Main guide view container
    self.guideView = [[UIView alloc] init];
    self.guideView.backgroundColor = [UIColor whiteColor];
    self.guideView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.guideView];
    
    // Scroll view for content
    self.guideScrollView = [[UIScrollView alloc] init];
    self.guideScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.guideScrollView.showsVerticalScrollIndicator = NO;
    self.guideScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.guideView addSubview:self.guideScrollView];
    
    // Content view inside scroll view
    self.guideContentView = [[UIView alloc] init];
    self.guideContentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.guideScrollView addSubview:self.guideContentView];
    
    // Searching label
    self.searchingLabel = [[UILabel alloc] init];
    //self.searchingLabel.text = LocalizedString(@"ble.scan.searching");
    self.searchingLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightMedium];
    self.searchingLabel.textColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    self.searchingLabel.textAlignment = NSTextAlignmentCenter;
    self.searchingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.guideContentView addSubview:self.searchingLabel];
    
    // Step 1 container
    UIView *step1Container = [[UIView alloc] init];
    step1Container.backgroundColor = [UIColor whiteColor];
    step1Container.layer.cornerRadius = 16;
    step1Container.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.08].CGColor;
    step1Container.layer.shadowOffset = CGSizeMake(0, 2);
    step1Container.layer.shadowOpacity = 1;
    step1Container.layer.shadowRadius = 8;
    step1Container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.guideContentView addSubview:step1Container];
    
    // Step 1 header
    UIView *step1Header = [[UIView alloc] init];
    step1Header.translatesAutoresizingMaskIntoConstraints = NO;
    [step1Container addSubview:step1Header];
    
    // Step 1 icon
    UIView *step1Icon = [[UIView alloc] init];
    step1Icon.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    step1Icon.layer.cornerRadius = 20;
    step1Icon.translatesAutoresizingMaskIntoConstraints = NO;
    [step1Header addSubview:step1Icon];
    
    // Sun icon inside step1Icon
    UIImageView *sunIcon = [[UIImageView alloc] init];
    sunIcon.image = [UIImage systemImageNamed:@"sun.max.fill"];
    sunIcon.tintColor = [UIColor whiteColor];
    sunIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [step1Icon addSubview:sunIcon];
    
    // Step 1 text
    UILabel *step1Text = [[UILabel alloc] init];
    step1Text.text = LocalizedString(@"ble.scan.step1.instruction");
    step1Text.font = [UIFont systemFontOfSize:16];
    step1Text.textColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    step1Text.numberOfLines = 0;
    step1Text.translatesAutoresizingMaskIntoConstraints = NO;
    [step1Header addSubview:step1Text];
    
    // Container for the GIF to clip it
    UIView *gifContainer = [[UIView alloc] init];
    gifContainer.translatesAutoresizingMaskIntoConstraints = NO;
    gifContainer.clipsToBounds = YES;
    [step1Container addSubview:gifContainer];
    
    // Device image (gif animation)
    self.deviceImageView = [[UIImageView alloc] init];
    [self setupDeviceGifAnimation];
    self.deviceImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.deviceImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [gifContainer addSubview:self.deviceImageView];
    
    // Step 1 label
    UILabel *step1Label = [[UILabel alloc] init];
    step1Label.text = LocalizedString(@"ble.scan.step1.title");
    step1Label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    step1Label.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
    step1Label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.guideContentView addSubview:step1Label];
    
    // Step 2 container
    UIView *step2Container = [[UIView alloc] init];
    step2Container.backgroundColor = [UIColor whiteColor];
    step2Container.layer.cornerRadius = 16;
    step2Container.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.08].CGColor;
    step2Container.layer.shadowOffset = CGSizeMake(0, 2);
    step2Container.layer.shadowOpacity = 1;
    step2Container.layer.shadowRadius = 8;
    step2Container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.guideContentView addSubview:step2Container];
    
    // Step 2 header
    UIView *step2Header = [[UIView alloc] init];
    step2Header.translatesAutoresizingMaskIntoConstraints = NO;
    [step2Container addSubview:step2Header];
    
    // Step 2 icon
    UIView *step2Icon = [[UIView alloc] init];
    step2Icon.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    step2Icon.layer.cornerRadius = 20;
    step2Icon.translatesAutoresizingMaskIntoConstraints = NO;
    [step2Header addSubview:step2Icon];
    
    // Phone icon inside step2Icon
    UIImageView *phoneIcon = [[UIImageView alloc] init];
    phoneIcon.image = [UIImage systemImageNamed:@"iphone"];
    phoneIcon.tintColor = [UIColor whiteColor];
    phoneIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [step2Icon addSubview:phoneIcon];
    
    // Step 2 text
    UILabel *step2Text = [[UILabel alloc] init];
    step2Text.text = LocalizedString(@"ble.scan.step2.instruction");
    step2Text.font = [UIFont systemFontOfSize:16];
    step2Text.textColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    step2Text.numberOfLines = 0;
    step2Text.translatesAutoresizingMaskIntoConstraints = NO;
    [step2Header addSubview:step2Text];
    
    // Step 2 label
    UILabel *step2Label = [[UILabel alloc] init];
    step2Label.text = LocalizedString(@"ble.scan.step2.title");
    step2Label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    step2Label.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
    step2Label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.guideContentView addSubview:step2Label];
    
    // Help button
    self.helpButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.helpButton setTitle:LocalizedString(@"ble.scan.help.title") forState:UIControlStateNormal];
    [self.helpButton setTitleColor:[UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    self.helpButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [self.helpButton addTarget:self action:@selector(helpButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.helpButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.guideView addSubview:self.helpButton];
    
    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        // Guide view constraints
        [self.guideView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.guideView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.guideView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.guideView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        // Scroll view constraints
        [self.guideScrollView.topAnchor constraintEqualToAnchor:self.guideView.topAnchor],
        [self.guideScrollView.leadingAnchor constraintEqualToAnchor:self.guideView.leadingAnchor],
        [self.guideScrollView.trailingAnchor constraintEqualToAnchor:self.guideView.trailingAnchor],
        [self.guideScrollView.bottomAnchor constraintEqualToAnchor:self.guideView.bottomAnchor],
        
        // Content view constraints
        [self.guideContentView.topAnchor constraintEqualToAnchor:self.guideScrollView.topAnchor],
        [self.guideContentView.leadingAnchor constraintEqualToAnchor:self.guideScrollView.leadingAnchor],
        [self.guideContentView.trailingAnchor constraintEqualToAnchor:self.guideScrollView.trailingAnchor],
        [self.guideContentView.bottomAnchor constraintEqualToAnchor:self.guideScrollView.bottomAnchor],
        [self.guideContentView.widthAnchor constraintEqualToAnchor:self.guideScrollView.widthAnchor],
        
        // Searching label
        [self.searchingLabel.topAnchor constraintEqualToAnchor:self.guideContentView.topAnchor constant:40],
        [self.searchingLabel.centerXAnchor constraintEqualToAnchor:self.guideContentView.centerXAnchor],
        
        // Step 1 label
        [step1Label.topAnchor constraintEqualToAnchor:self.searchingLabel.bottomAnchor constant:40],
        [step1Label.leadingAnchor constraintEqualToAnchor:self.guideContentView.leadingAnchor constant:20],
        
        // Step 1 container
        [step1Container.topAnchor constraintEqualToAnchor:step1Label.bottomAnchor constant:12],
        [step1Container.leadingAnchor constraintEqualToAnchor:self.guideContentView.leadingAnchor constant:20],
        [step1Container.trailingAnchor constraintEqualToAnchor:self.guideContentView.trailingAnchor constant:-20],
        
        // Step 1 header
        [step1Header.topAnchor constraintEqualToAnchor:step1Container.topAnchor constant:20],
        [step1Header.leadingAnchor constraintEqualToAnchor:step1Container.leadingAnchor constant:20],
        [step1Header.trailingAnchor constraintEqualToAnchor:step1Container.trailingAnchor constant:-20],
        
        // Step 1 icon
        [step1Icon.leadingAnchor constraintEqualToAnchor:step1Header.leadingAnchor],
        [step1Icon.centerYAnchor constraintEqualToAnchor:step1Header.centerYAnchor],
        [step1Icon.widthAnchor constraintEqualToConstant:40],
        [step1Icon.heightAnchor constraintEqualToConstant:40],
        
        // Sun icon
        [sunIcon.centerXAnchor constraintEqualToAnchor:step1Icon.centerXAnchor],
        [sunIcon.centerYAnchor constraintEqualToAnchor:step1Icon.centerYAnchor],
        [sunIcon.widthAnchor constraintEqualToConstant:20],
        [sunIcon.heightAnchor constraintEqualToConstant:20],
        
        // Step 1 text
        [step1Text.leadingAnchor constraintEqualToAnchor:step1Icon.trailingAnchor constant:16],
        [step1Text.trailingAnchor constraintEqualToAnchor:step1Header.trailingAnchor],
        [step1Text.topAnchor constraintEqualToAnchor:step1Header.topAnchor],
        [step1Text.bottomAnchor constraintEqualToAnchor:step1Header.bottomAnchor],
        
        // Device image container
        [gifContainer.topAnchor constraintEqualToAnchor:step1Header.bottomAnchor constant:24],
        [gifContainer.centerXAnchor constraintEqualToAnchor:step1Container.centerXAnchor],
        [gifContainer.widthAnchor constraintEqualToConstant:200],
        [gifContainer.heightAnchor constraintEqualToConstant:135],
        [gifContainer.bottomAnchor constraintEqualToAnchor:step1Container.bottomAnchor constant:-24],

        // Device image view
        [self.deviceImageView.topAnchor constraintEqualToAnchor:gifContainer.topAnchor],
        [self.deviceImageView.centerXAnchor constraintEqualToAnchor:gifContainer.centerXAnchor],
        [self.deviceImageView.widthAnchor constraintEqualToConstant:200],
        [self.deviceImageView.heightAnchor constraintEqualToConstant:150],
        
        // Step 2 label
        [step2Label.topAnchor constraintEqualToAnchor:step1Container.bottomAnchor constant:32],
        [step2Label.leadingAnchor constraintEqualToAnchor:self.guideContentView.leadingAnchor constant:20],
        
        // Step 2 container
        [step2Container.topAnchor constraintEqualToAnchor:step2Label.bottomAnchor constant:12],
        [step2Container.leadingAnchor constraintEqualToAnchor:self.guideContentView.leadingAnchor constant:20],
        [step2Container.trailingAnchor constraintEqualToAnchor:self.guideContentView.trailingAnchor constant:-20],
        [step2Container.bottomAnchor constraintEqualToAnchor:self.guideContentView.bottomAnchor constant:-100],
        
        // Step 2 header
        [step2Header.topAnchor constraintEqualToAnchor:step2Container.topAnchor constant:20],
        [step2Header.leadingAnchor constraintEqualToAnchor:step2Container.leadingAnchor constant:20],
        [step2Header.trailingAnchor constraintEqualToAnchor:step2Container.trailingAnchor constant:-20],
        [step2Header.bottomAnchor constraintEqualToAnchor:step2Container.bottomAnchor constant:-20],
        
        // Step 2 icon
        [step2Icon.leadingAnchor constraintEqualToAnchor:step2Header.leadingAnchor],
        [step2Icon.centerYAnchor constraintEqualToAnchor:step2Header.centerYAnchor],
        [step2Icon.widthAnchor constraintEqualToConstant:40],
        [step2Icon.heightAnchor constraintEqualToConstant:40],
        
        // Phone icon
        [phoneIcon.centerXAnchor constraintEqualToAnchor:step2Icon.centerXAnchor],
        [phoneIcon.centerYAnchor constraintEqualToAnchor:step2Icon.centerYAnchor],
        [phoneIcon.widthAnchor constraintEqualToConstant:18],
        [phoneIcon.heightAnchor constraintEqualToConstant:20],
        
        // Step 2 text
        [step2Text.leadingAnchor constraintEqualToAnchor:step2Icon.trailingAnchor constant:16],
        [step2Text.trailingAnchor constraintEqualToAnchor:step2Header.trailingAnchor],
        [step2Text.topAnchor constraintEqualToAnchor:step2Header.topAnchor],
        [step2Text.bottomAnchor constraintEqualToAnchor:step2Header.bottomAnchor],
        
        // Help button
        [self.helpButton.centerXAnchor constraintEqualToAnchor:self.guideView.centerXAnchor],
        [self.helpButton.bottomAnchor constraintEqualToAnchor:self.guideView.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [self.helpButton.heightAnchor constraintGreaterThanOrEqualToConstant:44]
    ]];
}

- (void)helpButtonTapped {
    // Handle help button action - you can implement help/FAQ functionality here
    NSLog(@"Help button tapped");
    // Example: Show alert or navigate to help page
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LocalizedString(@"ble.scan.help.title")
                                                                   message:LocalizedString(@"ble.scan.help.message")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:LocalizedString(@"common.ok") style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)setupDeviceGifAnimation {
    // Try to load gif data from different scale versions
    NSString *gifPath = nil;
    NSArray *resourceNames = @[@"plaud_note_pin_guide@3x", @"plaud_note_pin_guide@2x", @"plaud_note_pin_guide"];
    
    for (NSString *resourceName in resourceNames) {
        gifPath = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"gif"];
        if (gifPath) {
            break;
        }
    }
    
    if (gifPath) {
        NSData *gifData = [NSData dataWithContentsOfFile:gifPath];
        if (gifData) {
            [self setGifData:gifData toImageView:self.deviceImageView];
            return;
        }
    }
    
    // Fallback to static image if gif loading fails or not found
    self.deviceImageView.image = [UIImage systemImageNamed:@"iphone"];
}

- (void)setGifData:(NSData *)gifData toImageView:(UIImageView *)imageView {
    if (!gifData) return;
    
    // Create image source from gif data
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)gifData, NULL);
    if (!source) return;
    
    size_t count = CGImageSourceGetCount(source);
    NSMutableArray *images = [NSMutableArray array];
    NSTimeInterval totalDuration = 0;
    
    for (size_t i = 0; i < count; i++) {
        CGImageRef image = CGImageSourceCreateImageAtIndex(source, i, NULL);
        if (image) {
            [images addObject:[UIImage imageWithCGImage:image]];
            CGImageRelease(image);
            
            // Get frame duration
            CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
            if (properties) {
                CFDictionaryRef gifDict = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
                if (gifDict) {
                    CFNumberRef delayTime = CFDictionaryGetValue(gifDict, kCGImagePropertyGIFUnclampedDelayTime);
                    if (!delayTime) {
                        delayTime = CFDictionaryGetValue(gifDict, kCGImagePropertyGIFDelayTime);
                    }
                    if (delayTime) {
                        double duration;
                        CFNumberGetValue(delayTime, kCFNumberDoubleType, &duration);
                        totalDuration += duration;
                    }
                }
                CFRelease(properties);
            }
        }
    }
    
    CFRelease(source);
    
    if (images.count > 0) {
        imageView.animationImages = images;
        imageView.animationDuration = totalDuration > 0 ? totalDuration : images.count * 0.1; // Default 0.1s per frame
        imageView.animationRepeatCount = 0; // Infinite loop
        [imageView startAnimating];
    }
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] init];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[DeviceCell class] forCellReuseIdentifier:@"DeviceCell"];
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)startScanning {
    [self.deviceAgent startScan];
}

- (void)stopScanning {
    [self.deviceAgent stopScan];
}

- (void)refreshButtonTapped {
    [self.devices removeAllObjects];
    [self.tableView reloadData];
    [self updateViewsVisibility];
    [self stopScanning];
    [self startScanning];
}

- (void)updateViewsVisibility {
    BOOL hasDevices = self.devices.count > 0;
    BOOL shouldShowGuide = !self.hasEverFoundDevices && !hasDevices;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.guideView.hidden = !shouldShowGuide;
        self.tableView.hidden = !hasDevices;
        [self updateTitleForGuideView:shouldShowGuide];
    });
}

-(void)onSdkFetchPermissionResultWithPass:(BOOL)pass tips:(NSString *)tips {
    if (pass && _autoRefresh) {
        [self startScanning];
        _autoRefresh = NO;
    }
}

- (void)bleScanResultWithBleDevices:(NSArray<BleDevice *> *)bleDevices {
    [self.devices removeAllObjects];
    
    // Sort devices by RSSI signal strength from highest to lowest
    NSArray<BleDevice *> *sortedDevices = [bleDevices sortedArrayUsingComparator:^NSComparisonResult(BleDevice *device1, BleDevice *device2) {
        // Higher RSSI values indicate stronger signal, so we sort in descending order
        if (device1.rssi > device2.rssi) {
            return NSOrderedAscending; // device1 comes first (higher RSSI)
        } else if (device1.rssi < device2.rssi) {
            return NSOrderedDescending; // device2 comes first (higher RSSI)
        } else {
            return NSOrderedSame; // same RSSI
        }
    }];
    
    [self.devices addObjectsFromArray:sortedDevices];
    [self.tableView reloadData];
    
    // Update flag if we found devices for the first time
    if (sortedDevices.count > 0 && !self.hasEverFoundDevices) {
        self.hasEverFoundDevices = YES;
    }
    
    // Show/hide guide view based on device count
    [self updateViewsVisibility];
}

- (void)bleConnectStateWithState:(NSInteger)state {
    NSString *message = @"";
    switch (state) {
        case 0:
            message = NSLocalizedString(@"device.state.disconnected", @"Device disconnected");
            break;
        case 1:
            //message = NSLocalizedString(@"device.state.connected", @"Device connected successfully");
            break;
        case 2:
            message = NSLocalizedString(@"device.state.connection.failed", @"Device connection failed");
            break;
        default:
            message = NSLocalizedString(@"device.state.unknown", @"Unknown connection status");
            break;
    }
    
    NSLog(@"bleConnectStateWithState, %@", message);
    
    if (message.length > 0) {
        [self showToastWithMessage:message];
    }
    
    if (state == 1) {
        [self showDeviceInfo:self.currentDevice];
    }
}

- (void)showDeviceInfo:(BleDevice *)device {
    if (!device) return;
    
    DeviceInfoViewController *infoVC = [[DeviceInfoViewController alloc] initWithDevice:device];
    [self.navigationController pushViewController:infoVC animated:YES];
}

-(void)bleBindWithSn:(NSString *)sn status:(NSInteger)status protVersion:(NSInteger)protVersion timezone:(NSInteger)timezone{
    
}

- (void)bleScanOverTime {
    [self.devices removeAllObjects];
    [self.tableView reloadData];
    [self updateViewsVisibility];
}

- (void)bleRecordStartWithSessionId:(NSInteger)sessionId start:(NSInteger)start status:(NSInteger)status scene:(NSInteger)scene startTime:(NSInteger)startTime
{
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.devices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DeviceCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DeviceCell" forIndexPath:indexPath];
    BleDevice *device = self.devices[indexPath.row];
    [cell configureWithDevice:device controller:self];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 140;
}

#pragma mark - Device Connection
- (void)connectToDevice:(BleDevice *)device {
    if (device) {
        
        //        if (device.bindCode != 0) {
        //            [self showToastWithMessage:@"Device already bound, cannot bind to new device"];
        //            return;
        //        }
        
        [self showToastWithMessage:NSLocalizedString(@"device.state.connecting", @"Device connecting")];
        self.currentDevice = device;
        [self.deviceAgent connectBleDeviceWithBleDevice:device];
    }
}

@end

