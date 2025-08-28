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
    
    // Modern container with enhanced shadow and styling
    self.containerView = [[UIView alloc] init];
    self.containerView.backgroundColor = [UIColor whiteColor];
    self.containerView.layer.cornerRadius = 16;
    
    // Enhanced shadow with multiple layers for depth
    self.containerView.layer.shadowColor = [UIColor colorWithRed:0.15 green:0.25 blue:0.4 alpha:0.08].CGColor;
    self.containerView.layer.shadowOffset = CGSizeMake(0, 4);
    self.containerView.layer.shadowOpacity = 1;
    self.containerView.layer.shadowRadius = 12;
    
    // Add subtle border
    self.containerView.layer.borderWidth = 0.5;
    self.containerView.layer.borderColor = [UIColor colorWithRed:0.9 green:0.92 blue:0.95 alpha:1.0].CGColor;
    
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.containerView];
    
    // Status indicator background
    UIView *statusBar = [[UIView alloc] init];
    statusBar.layer.cornerRadius = 16;
    statusBar.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    statusBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:statusBar];
    
    // Device icon container
    UIView *deviceIconContainer = [[UIView alloc] init];
    deviceIconContainer.backgroundColor = [UIColor colorWithRed:0.25 green:0.53 blue:0.96 alpha:0.1];
    deviceIconContainer.layer.cornerRadius = 24;
    deviceIconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:deviceIconContainer];
    
    // Device icon
    UIImageView *deviceIcon = [[UIImageView alloc] init];
    deviceIcon.image = [UIImage systemImageNamed:@"headphones"];
    deviceIcon.tintColor = [UIColor colorWithRed:0.25 green:0.53 blue:0.96 alpha:1.0];
    deviceIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [deviceIconContainer addSubview:deviceIcon];
    
    // Name Label with improved typography
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.nameLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.nameLabel];
    
    // Info Label with subtle styling
    self.infoLabel = [[UILabel alloc] init];
    self.infoLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.infoLabel.textColor = [UIColor colorWithRed:0.4 green:0.5 blue:0.6 alpha:1.0];
    self.infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.infoLabel];
    
    // SN Label with improved readability
    self.snLabel = [[UILabel alloc] init];
    self.snLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightMedium];
    self.snLabel.textColor = [UIColor colorWithRed:0.5 green:0.55 blue:0.65 alpha:1.0];
    self.snLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.snLabel.numberOfLines = 1;
    self.snLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.containerView addSubview:self.snLabel];
    
    // Bind Status with pill-shaped container
    UIView *bindStatusContainer = [[UIView alloc] init];
    bindStatusContainer.layer.cornerRadius = 12;
    bindStatusContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:bindStatusContainer];
    
    // Bind Status Label
    self.bindStatusLabel = [[UILabel alloc] init];
    self.bindStatusLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    self.bindStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [bindStatusContainer addSubview:self.bindStatusLabel];
    
    // Bind Status Icon View (dot indicator)
    self.bindStatusIconView = [[UIView alloc] init];
    self.bindStatusIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bindStatusIconView.layer.cornerRadius = 4;
    [bindStatusContainer addSubview:self.bindStatusIconView];
    
    // Modern Connect Button with solid background to prevent flickering
    self.connectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.connectButton setTitle:LocalizedString(@"common.connect") forState:UIControlStateNormal];
    [self.connectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    // Use solid background color instead of gradient to prevent flickering
    self.connectButton.backgroundColor = [UIColor colorWithRed:0.25 green:0.53 blue:0.96 alpha:1.0];
    
    self.connectButton.layer.cornerRadius = 12;
    self.connectButton.layer.shadowColor = [UIColor colorWithRed:0.25 green:0.53 blue:0.96 alpha:0.3].CGColor;
    self.connectButton.layer.shadowOffset = CGSizeMake(0, 3);
    self.connectButton.layer.shadowOpacity = 1;
    self.connectButton.layer.shadowRadius = 6;
    
    self.connectButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.connectButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.connectButton addTarget:self action:@selector(connectButtonAction) forControlEvents:UIControlEventTouchUpInside];
    
    // Disable all animations on the button to prevent flickering
    self.connectButton.layer.actions = @{
        @"backgroundColor": [NSNull null],
        @"opacity": [NSNull null],
        @"transform": [NSNull null],
        @"bounds": [NSNull null],
        @"frame": [NSNull null]
    };
    
    [self.containerView addSubview:self.connectButton];
    
    [NSLayoutConstraint activateConstraints:@[
        // Container constraints with improved margins
        [self.containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        
        // Device icon container
        [deviceIconContainer.topAnchor constraintEqualToAnchor:self.containerView.topAnchor constant:20],
        [deviceIconContainer.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor constant:20],
        [deviceIconContainer.widthAnchor constraintEqualToConstant:48],
        [deviceIconContainer.heightAnchor constraintEqualToConstant:48],
        
        // Device icon
        [deviceIcon.centerXAnchor constraintEqualToAnchor:deviceIconContainer.centerXAnchor],
        [deviceIcon.centerYAnchor constraintEqualToAnchor:deviceIconContainer.centerYAnchor],
        [deviceIcon.widthAnchor constraintEqualToConstant:24],
        [deviceIcon.heightAnchor constraintEqualToConstant:24],
        
        // Name label
        [self.nameLabel.topAnchor constraintEqualToAnchor:deviceIconContainer.topAnchor constant:2],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:deviceIconContainer.trailingAnchor constant:16],
        [self.nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.connectButton.leadingAnchor constant:-12],
        
        // Info label
        [self.infoLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:4],
        [self.infoLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.infoLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.connectButton.leadingAnchor constant:-12],
        
        // SN label
        [self.snLabel.topAnchor constraintEqualToAnchor:self.infoLabel.bottomAnchor constant:8],
        [self.snLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.snLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.connectButton.leadingAnchor constant:-12],
        
        // Bind status container
        [bindStatusContainer.topAnchor constraintEqualToAnchor:self.snLabel.bottomAnchor constant:8],
        [bindStatusContainer.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [bindStatusContainer.heightAnchor constraintEqualToConstant:24],
        [bindStatusContainer.bottomAnchor constraintLessThanOrEqualToAnchor:self.containerView.bottomAnchor constant:-20],
        
        // Bind status icon
        [self.bindStatusIconView.leadingAnchor constraintEqualToAnchor:bindStatusContainer.leadingAnchor constant:8],
        [self.bindStatusIconView.centerYAnchor constraintEqualToAnchor:bindStatusContainer.centerYAnchor],
        [self.bindStatusIconView.widthAnchor constraintEqualToConstant:8],
        [self.bindStatusIconView.heightAnchor constraintEqualToConstant:8],
        
        // Bind status label
        [self.bindStatusLabel.leadingAnchor constraintEqualToAnchor:self.bindStatusIconView.trailingAnchor constant:6],
        [self.bindStatusLabel.centerYAnchor constraintEqualToAnchor:bindStatusContainer.centerYAnchor],
        [self.bindStatusLabel.trailingAnchor constraintEqualToAnchor:bindStatusContainer.trailingAnchor constant:-8],
        
        // Connect button with improved positioning
        [self.connectButton.centerYAnchor constraintEqualToAnchor:self.containerView.centerYAnchor],
        [self.connectButton.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-20],
        [self.connectButton.widthAnchor constraintEqualToConstant:88],
        [self.connectButton.heightAnchor constraintEqualToConstant:36]
    ]];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // No gradient layer management needed anymore - using solid background color
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
    
    // Find the bind status container
    UIView *bindStatusContainer = self.bindStatusLabel.superview;
    
    if (isUnbound) {
        // Unbound device - green success style
        self.bindStatusIconView.backgroundColor = [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1.0];
        self.bindStatusLabel.textColor = [UIColor colorWithRed:0.15 green:0.6 blue:0.28 alpha:1.0];
        bindStatusContainer.backgroundColor = [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:0.15];
        
        // Remove animations to prevent button flickering
        [self stopBreathingAnimation];
    } else {
        // Bound device - neutral style
        self.bindStatusIconView.backgroundColor = [UIColor colorWithRed:0.6 green:0.65 blue:0.7 alpha:1.0];
        self.bindStatusLabel.textColor = [UIColor colorWithRed:0.5 green:0.55 blue:0.6 alpha:1.0];
        bindStatusContainer.backgroundColor = [UIColor colorWithRed:0.94 green:0.95 blue:0.96 alpha:1.0];
        
        // Stop any animations
        [self stopBreathingAnimation];
    }
    
    self.bindStatusIconView.hidden = NO;
    
    // Ensure all animations are stopped to prevent flickering
    [self stopBreathingAnimation];
    
    [self.snLabel sizeToFit];
    self.controller = controller;
}

- (void)startEnhancedBreathingAnimation {
    // Remove any existing animations to prevent flickering
    [self.bindStatusIconView.layer removeAllAnimations];
    
    // Disable all animations to prevent button flickering
    // No animations will be added
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
    // Remove any existing animations to prevent flickering
    [self.bindStatusIconView.layer removeAllAnimations];
    
    // Disable breathing animation to prevent button flickering
    // No animations will be added
}

- (void)stopBreathingAnimation {
    [self.bindStatusIconView.layer removeAllAnimations];
    
    // Also ensure the connect button has no animations
    [self.connectButton.layer removeAllAnimations];
    
    // Set final state values to prevent any residual animation effects
    self.bindStatusIconView.layer.opacity = 1.0;
    self.bindStatusIconView.transform = CGAffineTransformIdentity;
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

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    // Update gradient background frame
    if (self.view.layer.sublayers.count > 0) {
        CALayer *firstLayer = self.view.layer.sublayers.firstObject;
        if ([firstLayer isKindOfClass:[CAGradientLayer class]]) {
            firstLayer.frame = self.view.bounds;
        }
    }
}

- (void)updateTitleForGuideView:(BOOL)isGuideVisible {
    NSString *titleText =  LocalizedString(@"ble.scan.title");
    
    // Set navigation bar title style with modern typography
    UIView *titleContainer = [[UIView alloc] init];
    titleContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = titleText;
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold]; // Slightly smaller for modern look
    titleLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0]; // Darker for better contrast
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [titleContainer addSubview:titleLabel];
    
    // Add subtle shadow for depth
    titleLabel.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.05].CGColor;
    titleLabel.layer.shadowOffset = CGSizeMake(0, 1);
    titleLabel.layer.shadowOpacity = 1;
    titleLabel.layer.shadowRadius = 2;
    
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
    // Modern gradient background
    self.view.backgroundColor = [UIColor colorWithRed:0.96 green:0.97 blue:0.99 alpha:1.0];
    
    // Create gradient background layer
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.96 green:0.97 blue:0.99 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.94 green:0.96 blue:0.98 alpha:1.0].CGColor
    ];
    gradientLayer.startPoint = CGPointMake(0, 0);
    gradientLayer.endPoint = CGPointMake(1, 1);
    gradientLayer.frame = self.view.bounds;
    [self.view.layer insertSublayer:gradientLayer atIndex:0];
    
    [self updateTitleForGuideView:NO];
    
    // Modern refresh button with enhanced styling
    UIButton *refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
    
    // Create refresh icon with subtle background
    UIView *refreshContainer = [[UIView alloc] init];
    refreshContainer.backgroundColor = [UIColor colorWithRed:0.25 green:0.53 blue:0.96 alpha:0.1];
    refreshContainer.layer.cornerRadius = 18;
    refreshContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIImageView *refreshIcon = [[UIImageView alloc] init];
    refreshIcon.image = [UIImage systemImageNamed:@"arrow.clockwise"];
    refreshIcon.tintColor = [UIColor colorWithRed:0.25 green:0.53 blue:0.96 alpha:1.0];
    refreshIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [refreshContainer addSubview:refreshIcon];
    
    UILabel *refreshLabel = [[UILabel alloc] init];
    refreshLabel.text = LocalizedString(@"common.refresh");
    refreshLabel.textColor = [UIColor colorWithRed:0.25 green:0.53 blue:0.96 alpha:1.0];
    refreshLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    refreshLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [refreshButton addSubview:refreshContainer];
    [refreshButton addSubview:refreshLabel];
    [refreshButton addTarget:self action:@selector(refreshButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    // Set button constraints
    refreshButton.frame = CGRectMake(0, 0, 100, 44);
    
    [NSLayoutConstraint activateConstraints:@[
        [refreshContainer.centerYAnchor constraintEqualToAnchor:refreshButton.centerYAnchor],
        [refreshContainer.leadingAnchor constraintEqualToAnchor:refreshButton.leadingAnchor],
        [refreshContainer.widthAnchor constraintEqualToConstant:36],
        [refreshContainer.heightAnchor constraintEqualToConstant:36],
        
        [refreshIcon.centerXAnchor constraintEqualToAnchor:refreshContainer.centerXAnchor],
        [refreshIcon.centerYAnchor constraintEqualToAnchor:refreshContainer.centerYAnchor],
        [refreshIcon.widthAnchor constraintEqualToConstant:18],
        [refreshIcon.heightAnchor constraintEqualToConstant:18],
        
        [refreshLabel.centerYAnchor constraintEqualToAnchor:refreshButton.centerYAnchor],
        [refreshLabel.leadingAnchor constraintEqualToAnchor:refreshContainer.trailingAnchor constant:8],
        [refreshLabel.trailingAnchor constraintEqualToAnchor:refreshButton.trailingAnchor]
    ]];
    
    UIBarButtonItem *refreshBarButton = [[UIBarButtonItem alloc] initWithCustomView:refreshButton];
    self.navigationItem.rightBarButtonItem = refreshBarButton;
    
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
    // Main guide view container with modern background
    self.guideView = [[UIView alloc] init];
    self.guideView.backgroundColor = [UIColor clearColor];
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
    
    // Modern header section
    UIView *headerSection = [[UIView alloc] init];
    headerSection.translatesAutoresizingMaskIntoConstraints = NO;
    [self.guideContentView addSubview:headerSection];
    
    // Header icon container
    UIView *headerIconContainer = [[UIView alloc] init];
    headerIconContainer.backgroundColor = [UIColor colorWithRed:0.25 green:0.53 blue:0.96 alpha:0.1];
    headerIconContainer.layer.cornerRadius = 32;
    headerIconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [headerSection addSubview:headerIconContainer];
    
    // Search icon
    UIImageView *searchIcon = [[UIImageView alloc] init];
    searchIcon.image = [UIImage systemImageNamed:@"wifi.circle"];
    searchIcon.tintColor = [UIColor colorWithRed:0.25 green:0.53 blue:0.96 alpha:1.0];
    searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [headerIconContainer addSubview:searchIcon];
    
    // Searching label with enhanced typography
    self.searchingLabel = [[UILabel alloc] init];
    self.searchingLabel.text = LocalizedString(@"ble.scan.searching");
    self.searchingLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    self.searchingLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    self.searchingLabel.textAlignment = NSTextAlignmentCenter;
    self.searchingLabel.numberOfLines = 0; // Allow multiple lines
    self.searchingLabel.lineBreakMode = NSLineBreakByWordWrapping; // Better word wrapping
    self.searchingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [headerSection addSubview:self.searchingLabel];
    
    // Subtitle label
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = LocalizedString(@"ble.scan.subtitle");
    subtitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor colorWithRed:0.4 green:0.5 blue:0.6 alpha:1.0];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [headerSection addSubview:subtitleLabel];
    
    // Instructions container with modern card design
    UIView *instructionsContainer = [[UIView alloc] init];
    instructionsContainer.backgroundColor = [UIColor whiteColor];
    instructionsContainer.layer.cornerRadius = 20;
    instructionsContainer.layer.shadowColor = [UIColor colorWithRed:0.15 green:0.25 blue:0.4 alpha:0.06].CGColor;
    instructionsContainer.layer.shadowOffset = CGSizeMake(0, 8);
    instructionsContainer.layer.shadowOpacity = 1;
    instructionsContainer.layer.shadowRadius = 16;
    instructionsContainer.layer.borderWidth = 0.5;
    instructionsContainer.layer.borderColor = [UIColor colorWithRed:0.9 green:0.92 blue:0.95 alpha:1.0].CGColor;
    instructionsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.guideContentView addSubview:instructionsContainer];
    
    // Step 1 horizontal container (text left, device image right)
    UIView *step1HorizontalContainer = [[UIView alloc] init];
    step1HorizontalContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [instructionsContainer addSubview:step1HorizontalContainer];
    
    // Step 1 section (left side)
    UIView *step1Section = [[UIView alloc] init];
    step1Section.translatesAutoresizingMaskIntoConstraints = NO;
    [step1HorizontalContainer addSubview:step1Section];
    
    // Step number badge for step 1
    UIView *step1Badge = [[UIView alloc] init];
    step1Badge.backgroundColor = [UIColor colorWithRed:0.25 green:0.53 blue:0.96 alpha:1.0];
    step1Badge.layer.cornerRadius = 16;
    step1Badge.translatesAutoresizingMaskIntoConstraints = NO;
    [step1Section addSubview:step1Badge];
    
    UILabel *step1Number = [[UILabel alloc] init];
    step1Number.text = @"1";
    step1Number.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    step1Number.textColor = [UIColor whiteColor];
    step1Number.textAlignment = NSTextAlignmentCenter;
    step1Number.translatesAutoresizingMaskIntoConstraints = NO;
    [step1Badge addSubview:step1Number];
    
    // Step 1 content
    UIView *step1Content = [[UIView alloc] init];
    step1Content.translatesAutoresizingMaskIntoConstraints = NO;
    [step1Section addSubview:step1Content];
    
    UILabel *step1Title = [[UILabel alloc] init];
    step1Title.text = LocalizedString(@"ble.scan.step1.instruction");
    step1Title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    step1Title.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    step1Title.numberOfLines = 0;
    step1Title.lineBreakMode = NSLineBreakByWordWrapping; // Better word wrapping
    step1Title.translatesAutoresizingMaskIntoConstraints = NO;
    [step1Content addSubview:step1Title];
    
    // Step 1 description will be added separately to create text wrapping effect
    UILabel *step1Description = [[UILabel alloc] init];
    step1Description.text = LocalizedString(@"ble.scan.step1.description");
    step1Description.font = [UIFont systemFontOfSize:14];
    step1Description.textColor = [UIColor colorWithRed:0.5 green:0.55 blue:0.65 alpha:1.0];
    step1Description.numberOfLines = 0;
    step1Description.lineBreakMode = NSLineBreakByWordWrapping; // Better word wrapping
    step1Description.translatesAutoresizingMaskIntoConstraints = NO;
    [instructionsContainer addSubview:step1Description]; // Add to main container instead of step1Content
    
    // Device animation container (right side)
    UIView *animationContainer = [[UIView alloc] init];
    animationContainer.backgroundColor = [UIColor colorWithRed:0.98 green:0.99 blue:1.0 alpha:1.0];
    animationContainer.layer.cornerRadius = 16;
    animationContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [step1HorizontalContainer addSubview:animationContainer];
    
    // Device image (gif animation)
    self.deviceImageView = [[UIImageView alloc] init];
    [self setupDeviceGifAnimation];
    self.deviceImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.deviceImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [animationContainer addSubview:self.deviceImageView];
    
    // Visual separator
    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = [UIColor colorWithRed:0.94 green:0.95 blue:0.96 alpha:1.0];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    [instructionsContainer addSubview:separator];
    
    // Step 2 section
    UIView *step2Section = [[UIView alloc] init];
    step2Section.translatesAutoresizingMaskIntoConstraints = NO;
    [instructionsContainer addSubview:step2Section];
    
    // Step number badge for step 2
    UIView *step2Badge = [[UIView alloc] init];
    step2Badge.backgroundColor = [UIColor colorWithRed:0.25 green:0.53 blue:0.96 alpha:1.0];
    step2Badge.layer.cornerRadius = 16;
    step2Badge.translatesAutoresizingMaskIntoConstraints = NO;
    [step2Section addSubview:step2Badge];
    
    UILabel *step2Number = [[UILabel alloc] init];
    step2Number.text = @"2";
    step2Number.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    step2Number.textColor = [UIColor whiteColor];
    step2Number.textAlignment = NSTextAlignmentCenter;
    step2Number.translatesAutoresizingMaskIntoConstraints = NO;
    [step2Badge addSubview:step2Number];
    
    // Step 2 content
    UIView *step2Content = [[UIView alloc] init];
    step2Content.translatesAutoresizingMaskIntoConstraints = NO;
    [step2Section addSubview:step2Content];
    
    UILabel *step2Title = [[UILabel alloc] init];
    step2Title.text = LocalizedString(@"ble.scan.step2.instruction");
    step2Title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    step2Title.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    step2Title.numberOfLines = 0;
    step2Title.lineBreakMode = NSLineBreakByWordWrapping; // Better word wrapping
    step2Title.translatesAutoresizingMaskIntoConstraints = NO;
    [step2Content addSubview:step2Title];
    
    UILabel *step2Description = [[UILabel alloc] init];
    step2Description.text = LocalizedString(@"ble.scan.step2.description");
    step2Description.font = [UIFont systemFontOfSize:14];
    step2Description.textColor = [UIColor colorWithRed:0.5 green:0.55 blue:0.65 alpha:1.0];
    step2Description.numberOfLines = 0;
    step2Description.lineBreakMode = NSLineBreakByWordWrapping; // Better word wrapping
    step2Description.translatesAutoresizingMaskIntoConstraints = NO;
    [step2Content addSubview:step2Description];
    
    // Modern help button
    self.helpButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.helpButton setTitle:LocalizedString(@"ble.scan.help.title") forState:UIControlStateNormal];
    [self.helpButton setTitleColor:[UIColor colorWithRed:0.25 green:0.53 blue:0.96 alpha:1.0] forState:UIControlStateNormal];
    self.helpButton.backgroundColor = [UIColor colorWithRed:0.25 green:0.53 blue:0.96 alpha:0.08];
    self.helpButton.layer.cornerRadius = 12;
    self.helpButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [self.helpButton addTarget:self action:@selector(helpButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.helpButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.guideView addSubview:self.helpButton];
    
    // Setup constraints with improved spacing
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
        [self.guideScrollView.bottomAnchor constraintEqualToAnchor:self.helpButton.topAnchor constant:-24],
        
        // Content view constraints
        [self.guideContentView.topAnchor constraintEqualToAnchor:self.guideScrollView.topAnchor],
        [self.guideContentView.leadingAnchor constraintEqualToAnchor:self.guideScrollView.leadingAnchor],
        [self.guideContentView.trailingAnchor constraintEqualToAnchor:self.guideScrollView.trailingAnchor],
        [self.guideContentView.bottomAnchor constraintEqualToAnchor:self.guideScrollView.bottomAnchor],
        [self.guideContentView.widthAnchor constraintEqualToAnchor:self.guideScrollView.widthAnchor],
        
        // Header section
        [headerSection.topAnchor constraintEqualToAnchor:self.guideContentView.topAnchor constant:32],
        [headerSection.leadingAnchor constraintEqualToAnchor:self.guideContentView.leadingAnchor constant:24],
        [headerSection.trailingAnchor constraintEqualToAnchor:self.guideContentView.trailingAnchor constant:-24],
        
        // Header icon container
        [headerIconContainer.topAnchor constraintEqualToAnchor:headerSection.topAnchor],
        [headerIconContainer.centerXAnchor constraintEqualToAnchor:headerSection.centerXAnchor],
        [headerIconContainer.widthAnchor constraintEqualToConstant:64],
        [headerIconContainer.heightAnchor constraintEqualToConstant:64],
        
        // Search icon
        [searchIcon.centerXAnchor constraintEqualToAnchor:headerIconContainer.centerXAnchor],
        [searchIcon.centerYAnchor constraintEqualToAnchor:headerIconContainer.centerYAnchor],
        [searchIcon.widthAnchor constraintEqualToConstant:32],
        [searchIcon.heightAnchor constraintEqualToConstant:32],
        
        // Searching label
        [self.searchingLabel.topAnchor constraintEqualToAnchor:headerIconContainer.bottomAnchor constant:20],
        [self.searchingLabel.centerXAnchor constraintEqualToAnchor:headerSection.centerXAnchor],
        [self.searchingLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:headerSection.leadingAnchor],
        [self.searchingLabel.trailingAnchor constraintLessThanOrEqualToAnchor:headerSection.trailingAnchor],
        
        // Subtitle label
        [subtitleLabel.topAnchor constraintEqualToAnchor:self.searchingLabel.bottomAnchor constant:12],
        [subtitleLabel.centerXAnchor constraintEqualToAnchor:headerSection.centerXAnchor],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:headerSection.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:headerSection.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:headerSection.bottomAnchor],
        
        // Instructions container
        [instructionsContainer.topAnchor constraintEqualToAnchor:headerSection.bottomAnchor constant:40],
        [instructionsContainer.leadingAnchor constraintEqualToAnchor:self.guideContentView.leadingAnchor constant:24],
        [instructionsContainer.trailingAnchor constraintEqualToAnchor:self.guideContentView.trailingAnchor constant:-24],
        [instructionsContainer.bottomAnchor constraintEqualToAnchor:self.guideContentView.bottomAnchor constant:-32],
        
        // Step 1 horizontal container
        [step1HorizontalContainer.topAnchor constraintEqualToAnchor:instructionsContainer.topAnchor constant:28],
        [step1HorizontalContainer.leadingAnchor constraintEqualToAnchor:instructionsContainer.leadingAnchor constant:24],
        [step1HorizontalContainer.trailingAnchor constraintEqualToAnchor:instructionsContainer.trailingAnchor constant:-24],
        [step1HorizontalContainer.heightAnchor constraintGreaterThanOrEqualToConstant:100], // Reduced height since description is now separate
        [step1HorizontalContainer.bottomAnchor constraintGreaterThanOrEqualToAnchor:step1Content.bottomAnchor],
        
        // Step 1 section (left side)
        [step1Section.topAnchor constraintEqualToAnchor:step1HorizontalContainer.topAnchor],
        [step1Section.leadingAnchor constraintEqualToAnchor:step1HorizontalContainer.leadingAnchor],
        [step1Section.bottomAnchor constraintEqualToAnchor:step1Content.bottomAnchor],
        [step1Section.trailingAnchor constraintEqualToAnchor:animationContainer.leadingAnchor constant:-16],
        
        // Step 1 badge
        [step1Badge.leadingAnchor constraintEqualToAnchor:step1Section.leadingAnchor],
        [step1Badge.topAnchor constraintEqualToAnchor:step1Section.topAnchor],
        [step1Badge.widthAnchor constraintEqualToConstant:32],
        [step1Badge.heightAnchor constraintEqualToConstant:32],
        
        // Step 1 number
        [step1Number.centerXAnchor constraintEqualToAnchor:step1Badge.centerXAnchor],
        [step1Number.centerYAnchor constraintEqualToAnchor:step1Badge.centerYAnchor],
        
        // Step 1 content (now only contains title)
        [step1Content.leadingAnchor constraintEqualToAnchor:step1Badge.trailingAnchor constant:16],
        [step1Content.trailingAnchor constraintEqualToAnchor:step1Section.trailingAnchor],
        [step1Content.topAnchor constraintEqualToAnchor:step1Section.topAnchor],
        [step1Content.bottomAnchor constraintEqualToAnchor:step1Title.bottomAnchor],
        
        // Step 1 title
        [step1Title.topAnchor constraintEqualToAnchor:step1Content.topAnchor],
        [step1Title.leadingAnchor constraintEqualToAnchor:step1Content.leadingAnchor],
        [step1Title.trailingAnchor constraintEqualToAnchor:step1Content.trailingAnchor],
        [step1Title.bottomAnchor constraintEqualToAnchor:step1Content.bottomAnchor],
        
        // Step 1 description (positioned to align with title text for text wrapping effect)
        [step1Description.topAnchor constraintEqualToAnchor:step1HorizontalContainer.bottomAnchor constant:12],
        [step1Description.leadingAnchor constraintEqualToAnchor:step1Content.leadingAnchor],
        [step1Description.trailingAnchor constraintEqualToAnchor:instructionsContainer.trailingAnchor constant:-24],
        
        // Animation container (right side) - reduced by 10%
        [animationContainer.topAnchor constraintEqualToAnchor:step1HorizontalContainer.topAnchor],
        [animationContainer.trailingAnchor constraintEqualToAnchor:step1HorizontalContainer.trailingAnchor],
        [animationContainer.widthAnchor constraintEqualToConstant:144], // 160 * 0.9 = 144
        [animationContainer.heightAnchor constraintEqualToConstant:117], // 130 * 0.9 = 117
        [animationContainer.centerYAnchor constraintEqualToAnchor:step1HorizontalContainer.centerYAnchor],
        
        // Device image view - reduced by 10%
        [self.deviceImageView.centerXAnchor constraintEqualToAnchor:animationContainer.centerXAnchor],
        [self.deviceImageView.centerYAnchor constraintEqualToAnchor:animationContainer.centerYAnchor],
        [self.deviceImageView.widthAnchor constraintEqualToConstant:117], // 130 * 0.9 = 117
        [self.deviceImageView.heightAnchor constraintEqualToConstant:99], // 110 * 0.9 = 99
        
        // Separator
        [separator.topAnchor constraintEqualToAnchor:step1Description.bottomAnchor constant:32],
        [separator.leadingAnchor constraintEqualToAnchor:instructionsContainer.leadingAnchor constant:24],
        [separator.trailingAnchor constraintEqualToAnchor:instructionsContainer.trailingAnchor constant:-24],
        [separator.heightAnchor constraintEqualToConstant:1],
        
        // Step 2 section
        [step2Section.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:32],
        [step2Section.leadingAnchor constraintEqualToAnchor:instructionsContainer.leadingAnchor constant:24],
        [step2Section.trailingAnchor constraintEqualToAnchor:instructionsContainer.trailingAnchor constant:-24],
        [step2Section.bottomAnchor constraintEqualToAnchor:instructionsContainer.bottomAnchor constant:-32],
        
        // Step 2 badge
        [step2Badge.leadingAnchor constraintEqualToAnchor:step2Section.leadingAnchor],
        [step2Badge.topAnchor constraintEqualToAnchor:step2Section.topAnchor],
        [step2Badge.widthAnchor constraintEqualToConstant:32],
        [step2Badge.heightAnchor constraintEqualToConstant:32],
        
        // Step 2 number
        [step2Number.centerXAnchor constraintEqualToAnchor:step2Badge.centerXAnchor],
        [step2Number.centerYAnchor constraintEqualToAnchor:step2Badge.centerYAnchor],
        
        // Step 2 content
        [step2Content.leadingAnchor constraintEqualToAnchor:step2Badge.trailingAnchor constant:16],
        [step2Content.trailingAnchor constraintEqualToAnchor:step2Section.trailingAnchor],
        [step2Content.topAnchor constraintEqualToAnchor:step2Section.topAnchor],
        [step2Content.bottomAnchor constraintEqualToAnchor:step2Section.bottomAnchor],
        
        // Step 2 title
        [step2Title.topAnchor constraintEqualToAnchor:step2Content.topAnchor],
        [step2Title.leadingAnchor constraintEqualToAnchor:step2Content.leadingAnchor],
        [step2Title.trailingAnchor constraintEqualToAnchor:step2Content.trailingAnchor],
        
        // Step 2 description
        [step2Description.topAnchor constraintEqualToAnchor:step2Title.bottomAnchor constant:8],
        [step2Description.leadingAnchor constraintEqualToAnchor:step2Content.leadingAnchor],
        [step2Description.trailingAnchor constraintEqualToAnchor:step2Content.trailingAnchor],
        [step2Description.bottomAnchor constraintLessThanOrEqualToAnchor:step2Content.bottomAnchor],
        
        // Help button
        [self.helpButton.leadingAnchor constraintEqualToAnchor:self.guideView.leadingAnchor constant:24],
        [self.helpButton.trailingAnchor constraintEqualToAnchor:self.guideView.trailingAnchor constant:-24],
        [self.helpButton.bottomAnchor constraintEqualToAnchor:self.guideView.safeAreaLayoutGuide.bottomAnchor constant:-24],
        [self.helpButton.heightAnchor constraintEqualToConstant:48]
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
            // Add watermark overlay to hide the watermark in bottom left corner
            [self addWatermarkOverlayToImageView:self.deviceImageView];
            return;
        }
    }
    
    // Fallback to static image if gif loading fails or not found
    self.deviceImageView.image = [UIImage systemImageNamed:@"iphone"];
    // Add watermark overlay even for fallback image
    [self addWatermarkOverlayToImageView:self.deviceImageView];
}

- (void)addWatermarkOverlayToImageView:(UIImageView *)imageView {
    if (!imageView) {
        NSLog(@"Warning: imageView is nil, cannot add watermark mask");
        return;
    }
    
    // Schedule the mask creation after view layout is complete
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Create a mask to clip out the watermark area at the bottom
        CAShapeLayer *maskLayer = [CAShapeLayer layer];
        
        // Get the imageView bounds for the mask
        CGRect bounds = imageView.bounds;
        if (CGRectIsEmpty(bounds)) {
            // If bounds are empty, set a default size and try again later
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self addWatermarkOverlayToImageView:imageView];
            });
            return;
        }
        
        // Create a path that covers everything except the bottom watermark area
        UIBezierPath *maskPath = [UIBezierPath bezierPath];
        
                 // Cover the entire image except the bottom area where watermark appears
         CGFloat cropHeight = 15.0; // Reduced height to crop from bottom - just enough to hide watermark
         CGRect visibleRect = CGRectMake(0, 0, bounds.size.width, bounds.size.height - cropHeight);
        [maskPath appendPath:[UIBezierPath bezierPathWithRect:visibleRect]];
        
        // Set the mask path
        maskLayer.path = maskPath.CGPath;
        maskLayer.frame = bounds;
        
        // Apply the mask to the imageView
        imageView.layer.mask = maskLayer;
        
        // Also apply clipping to ensure everything is contained
        imageView.clipsToBounds = YES;
        
        NSLog(@"✅ Watermark mask applied to imageView, cropping bottom %f pixels", cropHeight);
    });
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
    self.tableView.contentInset = UIEdgeInsetsMake(16, 0, 16, 0);
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

- (void)bleRecordStartWithSessionId:(NSInteger)sessionId start:(NSInteger)start status:(NSInteger)status scene:(NSInteger)scene startTime:(NSInteger)startTime reason:(NSInteger)reason
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
    return 156; // Increased height for modern card design
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
        [self.deviceAgent connectBleDeviceWithBleDevice:device deviceToken:device.serialNumber];
    }
}

@end

