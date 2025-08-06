import UIKit
import PlaudDeviceBasicSDK

class WiFiTransferTestViewController: UIViewController {
    
    private var toastView: UIView?
    private var toastLabel: UILabel?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        PlaudWiFiAgent.shared.delegate = self
        PlaudDeviceAgent.shared.delegate = self
    }
    
    // MARK: - UI Components
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("wifi.transfer.status", comment: "")
        label.font = .systemFont(ofSize: 16, weight: .semibold) // Slightly smaller font to avoid overflow
        label.textColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) // Darker color
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true // Allow font scaling to fit width
        label.minimumScaleFactor = 0.8 // Minimum scaling factor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // WiFi connection status label
    private let connectionStatusLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("wifi.transfer.connection_status", comment: "")
        label.font = .systemFont(ofSize: 14, weight: .medium) // Slightly smaller font
        label.textColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true // Allow font scaling to fit width
        label.minimumScaleFactor = 0.8 // Minimum scaling factor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // WiFi connection status indicator - modern design
    private let connectionStatusIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .systemRed // Initial state: disconnected (red)
        view.layer.cornerRadius = 7 // Slightly larger indicator
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 3
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Container for status label and indicator - enhanced spacing
    private let statusHeaderStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 16 // Moderate spacing
        stackView.alignment = .center
        stackView.distribution = .fill // Changed to fill distribution for natural content layout
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let logTextView: UITextView = {
        let textView = UITextView()
        textView.isScrollEnabled = true
        textView.font = .systemFont(ofSize: 13) // Slightly smaller font
        textView.backgroundColor = UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0)
        textView.textColor = UIColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0) // Optimized text color
        textView.layer.cornerRadius = 12
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        // Adjust inner padding to align with title
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.textContainer.lineFragmentPadding = 0
        
        // Add border
        textView.layer.borderWidth = 0.5
        textView.layer.borderColor = UIColor(red: 0.9, green: 0.92, blue: 0.95, alpha: 1.0).cgColor
        
        return textView
    }()
    
    private let statusDisplayLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("wifi.transfer.initial_status", comment: "")
        label.font = .systemFont(ofSize: 15, weight: .medium) // Optimized font size
        label.textColor = UIColor(red: 0.25, green: 0.35, blue: 0.45, alpha: 1.0) // Darker text color
        label.backgroundColor = UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1.0) // Cleaner background color
        label.layer.cornerRadius = 14 // Consistent with button corner radius
        label.textAlignment = .center
        label.numberOfLines = 3 // Allow more lines for display
        label.lineBreakMode = .byWordWrapping // Word wrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subtle border and padding
        label.layer.borderWidth = 0.5
        label.layer.borderColor = UIColor(red: 0.88, green: 0.90, blue: 0.92, alpha: 1.0).cgColor
        
        return label
    }()
    
    private lazy var buttonsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16 // Reduce vertical spacing to save space
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var connectWiFiButton = createButton(title: NSLocalizedString("wifi.connection.connect", comment: ""))
    private lazy var disconnectWiFiButton = createButton(title: NSLocalizedString("wifi.connection.disconnect", comment: ""))
    private lazy var rateTestButton = createButton(title: NSLocalizedString("wifi.rate.start_test", comment: ""))
    private lazy var stopRateTestButton = createButton(title: NSLocalizedString("wifi.rate.stop_test", comment: ""))
    private lazy var getLogsButton = createButton(title: NSLocalizedString("wifi.device.get_logs", comment: ""))
    private lazy var getCurrentWiFiButton = createButton(title: NSLocalizedString("wifi.device.get_current_wifi", comment: ""))
    private lazy var fileListButton = createButton(title: NSLocalizedString("wifi.file.get_list", comment: ""), bgColor: UIColor(red: 0.41, green: 0.53, blue: 0.85, alpha: 1.0))
    private lazy var deleteFileButton = createButton(title: NSLocalizedString("wifi.file.delete", comment: ""))
    private lazy var startDownloadAllButton = createButton(title: NSLocalizedString("wifi.download.start_batch", comment: ""), bgColor: UIColor(red: 0.20, green: 0.68, blue: 0.43, alpha: 1.0)) // Modern green color
    private lazy var stopDownloadAllButton = createButton(title: NSLocalizedString("wifi.download.stop_batch", comment: ""), bgColor: UIColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1.0)) // Modern red color
    private lazy var clearLogsButton = createButton(title: NSLocalizedString("wifi.logs.clear", comment: "")/*, bgColor: UIColor(red: 0.95, green: 0.61, blue: 0.07, alpha: 1.0)*/) // Modern orange color
    
    // MARK: - Properties
    
    private let device: BleDevice
    private var fileList: [BleFile] = []
    
    // Log management
    private var logMessages: [String] = []
    private let maxLogCount = 200
    private var logUpdateTimer: Timer?
    private var pendingLogs: [String] = []
    private let logQueue = DispatchQueue(label: "com.plaud.log.queue", qos: .utility)
    
    // Time control properties for WiFi callbacks
    private var lastSyncLogTime: Date = Date()
    private var syncDataCounter = 0
    private var lastRateLogTime: Date = Date()
    
    // MARK: - Initialization
    
    init(device: BleDevice) {
        self.device = device
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        setupLogSystem()
        PlaudWiFiAgent.shared.delegate = self
        
        // Add initial logs
        appendLog(NSLocalizedString("wifi.transfer.starting_interface", comment: ""))
        appendLog(String(format: NSLocalizedString("wifi.transfer.device_info", comment: ""), device.name))
        
        // Set initial state to disconnected (only update indicator, keep original status text)
        updateConnectionStatusIndicator(connected: false, updateStatusText: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cleanupLogSystem()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Apply modern SaaS style background color
        view.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        
        // Setup custom navigation bar title
        setupNavigationBar()
        
        setupScrollView()
        setupStatusSection()
        setupLogSection()
        setupActionSection()
        setupConstraints()
    }
    
    private func setupNavigationBar() {
        // Clear default title
        title = ""
        navigationItem.title = ""
        
        // Setup navigation bar style
        navigationController?.navigationBar.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        navigationController?.navigationBar.barTintColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.shadowImage = UIImage()
        
        // Create custom title view
        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("wifi.transfer.title", comment: "")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold) // Slightly smaller font
        titleLabel.textColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) // Dark text color
        titleLabel.textAlignment = .center
        
        // Create container view
        let titleContainer = UIView()
        titleContainer.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: titleContainer.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: titleContainer.trailingAnchor),
            titleContainer.widthAnchor.constraint(equalToConstant: 200),
            titleContainer.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        navigationItem.titleView = titleContainer
    }
    
    // MARK: - Saas Style UI Components
    
    // Scroll view
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0) // More modern background color
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Status info container - enhanced SaaS style
    private let statusContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16 // Larger corner radius
        
        // Enhanced shadow effect
        view.layer.shadowColor = UIColor(red: 0.15, green: 0.25, blue: 0.4, alpha: 0.08).cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowOpacity = 1
        view.layer.shadowRadius = 12
        
        // Subtle border
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor(red: 0.9, green: 0.92, blue: 0.95, alpha: 1.0).cgColor
        
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Log container - modern design
    private let logContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
        
        // Enhanced shadow effect
        view.layer.shadowColor = UIColor(red: 0.15, green: 0.25, blue: 0.4, alpha: 0.08).cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowOpacity = 1
        view.layer.shadowRadius = 12
        
        // Subtle border
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor(red: 0.9, green: 0.92, blue: 0.95, alpha: 1.0).cgColor
        
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Log title - improved font
    private let logTitleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("wifi.transfer.logs_title", comment: "")
        label.font = .systemFont(ofSize: 17, weight: .semibold) // Larger font and weight
        label.textColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) // Darker color
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Action button container - SaaS style
    private let actionContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
        
        // Enhanced shadow effect
        view.layer.shadowColor = UIColor(red: 0.15, green: 0.25, blue: 0.4, alpha: 0.08).cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowOpacity = 1
        view.layer.shadowRadius = 12
        
        // Subtle border
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor(red: 0.9, green: 0.92, blue: 0.95, alpha: 1.0).cgColor
        
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupStatusSection() {
        contentView.addSubview(statusContainerView)
        
        // Create horizontal layout for WiFi connection status
        let connectionStatusStackView = UIStackView()
        connectionStatusStackView.axis = .horizontal
        connectionStatusStackView.spacing = 8 // Moderate spacing
        connectionStatusStackView.alignment = .center
        connectionStatusStackView.translatesAutoresizingMaskIntoConstraints = false
        
        connectionStatusStackView.addArrangedSubview(connectionStatusLabel)
        connectionStatusStackView.addArrangedSubview(connectionStatusIndicator)
        
        // Setup horizontal layout for status title and connection status
        statusHeaderStackView.addArrangedSubview(statusLabel)
        statusHeaderStackView.addArrangedSubview(connectionStatusStackView)
        
        // Setup constraints to ensure correct layout
        NSLayoutConstraint.activate([
            // Indicator size constraints
            connectionStatusIndicator.widthAnchor.constraint(equalToConstant: 14),
            connectionStatusIndicator.heightAnchor.constraint(equalToConstant: 14),
            
            // Set max width for connection status component to avoid squeezing left title
            connectionStatusStackView.widthAnchor.constraint(lessThanOrEqualToConstant: 180),
            
            // Ensure left status label has enough space
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
        
        let stackView = UIStackView(arrangedSubviews: [statusHeaderStackView, statusDisplayLabel])
        stackView.axis = .vertical
        stackView.spacing = 16 // Increase spacing between status title and status display
        stackView.translatesAutoresizingMaskIntoConstraints = false
        statusContainerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: statusContainerView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: statusContainerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: statusContainerView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: statusContainerView.bottomAnchor, constant: -20),
            
            statusDisplayLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 48) // Reduce minimum height to save space
        ])
    }
    
    private func setupLogSection() {
        contentView.addSubview(logContainerView)
        
        // Add title separately, then add log view separately to ensure alignment
        logContainerView.addSubview(logTitleLabel)
        logContainerView.addSubview(logTextView)
        
        NSLayoutConstraint.activate([
            // Title constraints
            logTitleLabel.topAnchor.constraint(equalTo: logContainerView.topAnchor, constant: 20),
            logTitleLabel.leadingAnchor.constraint(equalTo: logContainerView.leadingAnchor, constant: 20),
            logTitleLabel.trailingAnchor.constraint(equalTo: logContainerView.trailingAnchor, constant: -20),
            
            // Log view constraints - left aligned with title
            logTextView.topAnchor.constraint(equalTo: logTitleLabel.bottomAnchor, constant: 12),
            logTextView.leadingAnchor.constraint(equalTo: logContainerView.leadingAnchor, constant: 20),
            logTextView.trailingAnchor.constraint(equalTo: logContainerView.trailingAnchor, constant: -20),
            logTextView.bottomAnchor.constraint(equalTo: logContainerView.bottomAnchor, constant: -20),
            logTextView.heightAnchor.constraint(equalToConstant: 160) // Reduce log area height to make room for bottom buttons
        ])
    }
    
    private func setupActionSection() {
        contentView.addSubview(actionContainerView)
        actionContainerView.addSubview(buttonsStackView)
        
        // Create button groups with consistent layout
        let rateButtonsRow = createHorizontalButtonStack(leftButton: rateTestButton, rightButton: stopRateTestButton)
        let wifiInfoRow = createHorizontalButtonStack(leftButton: getCurrentWiFiButton, rightButton: fileListButton)
        let fileManageRow = createHorizontalButtonStack(leftButton: deleteFileButton, rightButton: clearLogsButton)
        let downloadRow = createHorizontalButtonStack(leftButton: startDownloadAllButton, rightButton: stopDownloadAllButton)
        
        // Add all button rows to main stack view with better organization
        [rateButtonsRow, wifiInfoRow, fileManageRow, downloadRow].forEach {
            buttonsStackView.addArrangedSubview($0)
        }
        
        NSLayoutConstraint.activate([
            buttonsStackView.topAnchor.constraint(equalTo: actionContainerView.topAnchor, constant: 20), // Reduce padding to save space
            buttonsStackView.leadingAnchor.constraint(equalTo: actionContainerView.leadingAnchor, constant: 20),
            buttonsStackView.trailingAnchor.constraint(equalTo: actionContainerView.trailingAnchor, constant: -20),
            buttonsStackView.bottomAnchor.constraint(equalTo: actionContainerView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            statusContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12), // Further reduce top spacing
            statusContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            logContainerView.topAnchor.constraint(equalTo: statusContainerView.bottomAnchor, constant: 12), // Reduce spacing
            logContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            logContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            actionContainerView.topAnchor.constraint(equalTo: logContainerView.bottomAnchor, constant: 12), // Reduce spacing
            actionContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            actionContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            actionContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24) // Increase bottom spacing to ensure safe area
        ])
    }
    
    private func createButton(title: String, bgColor: UIColor = .systemBlue) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold) // Further reduce font to ensure consistent display
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.6 // Larger scaling range to ensure long text fits
        button.titleLabel?.numberOfLines = 2 // Uniformly allow two lines display
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.lineBreakMode = .byCharWrapping // Change to character wrapping for better text distribution
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16) // Optimized padding
        button.layer.cornerRadius = 16 // Maintain modern corner radius
        button.heightAnchor.constraint(equalToConstant: 66).isActive = true // Slightly reduce height to optimize layout
        
        // Apply modern SaaS style
        if bgColor == .systemBlue {
            // Default button style: white background, blue border and text
            button.backgroundColor = .white
            button.setTitleColor(UIColor(red: 0.25, green: 0.53, blue: 0.96, alpha: 1.0), for: .normal)
            button.layer.borderWidth = 2.0 // More prominent border
            button.layer.borderColor = UIColor(red: 0.25, green: 0.53, blue: 0.96, alpha: 1.0).cgColor
            
            // Optimized shadow effect
            button.layer.shadowColor = UIColor(red: 0.25, green: 0.53, blue: 0.96, alpha: 0.12).cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 6)
            button.layer.shadowOpacity = 1
            button.layer.shadowRadius = 16
            
            // Subtle inner highlight
            button.layer.masksToBounds = false
        } else {
            // Colored buttons: richer visual effects
            button.backgroundColor = bgColor
            button.setTitleColor(.white, for: .normal)
            
            // Enhanced shadow effect for better layering
            button.layer.shadowColor = bgColor.withAlphaComponent(0.4).cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 8)
            button.layer.shadowOpacity = 1
            button.layer.shadowRadius = 20
            
            // Subtle inner highlight effect
            button.layer.borderWidth = 1.0
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
            button.layer.masksToBounds = false
        }
        
        // Optimized click effect
        button.setTitleColor(UIColor.lightGray.withAlphaComponent(0.6), for: .highlighted)
        
        // Add touch animation effect
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        // Special optimization for long text buttons
        DispatchQueue.main.async {
            self.optimizeButtonTextLayout(button)
        }
        
        return button
    }
    
    // Helper method for optimizing button text layout
    private func optimizeButtonTextLayout(_ button: UIButton) {
        guard let titleLabel = button.titleLabel,
              let text = titleLabel.text else { return }
        
        // Check if text needs line break
        let maxWidth = button.frame.width - button.contentEdgeInsets.left - button.contentEdgeInsets.right
        let singleLineSize = text.size(withAttributes: [.font: titleLabel.font!])
        
        if singleLineSize.width > maxWidth && maxWidth > 0 {
            // Case needing line wrapping, ensure text is centered
            titleLabel.numberOfLines = 2
            titleLabel.lineBreakMode = .byCharWrapping
            titleLabel.textAlignment = .center
        } else {
            // Single line display is sufficient
            titleLabel.numberOfLines = 1
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.textAlignment = .center
        }
    }
    
    // Button animation effects
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.allowUserInteraction], animations: {
            sender.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            sender.alpha = 0.85
        })
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.allowUserInteraction], animations: {
            sender.transform = CGAffineTransform.identity
            sender.alpha = 1.0
        })
    }
    
    private func createHorizontalButtonStack(leftButton: UIButton, rightButton: UIButton) -> UIStackView {
        let horizontalStack = UIStackView()
        horizontalStack.axis = .horizontal
        horizontalStack.distribution = .fillEqually
        horizontalStack.spacing = 16 // Moderate button spacing to save space
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false
        
        horizontalStack.addArrangedSubview(leftButton)
        horizontalStack.addArrangedSubview(rightButton)
        
        return horizontalStack
    }
    
    private func setupActions() {
        connectWiFiButton.addTarget(self, action: #selector(connectWiFiTapped), for: .touchUpInside)
        disconnectWiFiButton.addTarget(self, action: #selector(disconnectWiFiTapped), for: .touchUpInside)
        rateTestButton.addTarget(self, action: #selector(startRateTestTapped), for: .touchUpInside)
        stopRateTestButton.addTarget(self, action: #selector(stopRateTestTapped), for: .touchUpInside)
        getLogsButton.addTarget(self, action: #selector(getLogsTapped), for: .touchUpInside)
        getCurrentWiFiButton.addTarget(self, action: #selector(getCurrentWiFiTapped), for: .touchUpInside)
        fileListButton.addTarget(self, action: #selector(getFileListTapped), for: .touchUpInside)
        deleteFileButton.addTarget(self, action: #selector(deleteFileTapped), for: .touchUpInside)
        startDownloadAllButton.addTarget(self, action: #selector(startDownloadAllTapped), for: .touchUpInside)
        stopDownloadAllButton.addTarget(self, action: #selector(stopDownloadAllTapped), for: .touchUpInside)
        clearLogsButton.addTarget(self, action: #selector(clearLogs), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    //self.deviceAgent.tryReconnectLastDevice()
    
    @objc private func connectWiFiTapped() {
        // Check Bluetooth connection status
        guard PlaudDeviceAgent.shared.isConnected() else {
            showToastWithMessage(NSLocalizedString("wifi.transfer.bluetooth_not_connected", comment: ""))
            appendLog("❌ " + NSLocalizedString("wifi.transfer.bluetooth_not_connected", comment: ""))
            return
        }
        
        appendLog("🔵 " + NSLocalizedString("wifi.transfer.bluetooth_connected_opening_wifi", comment: ""))
        PlaudDeviceAgent.shared.setDeviceWiFi(open: true)
    }
    
    @objc private func disconnectWiFiTapped() {
        appendLog(NSLocalizedString("wifi.transfer.disconnecting_wifi", comment: ""))
        
        updateStatusDisplay(NSLocalizedString("wifi.transfer.disconnecting_wifi", comment: ""))
        
        PlaudWiFiAgent.shared.disconnect()
        
        // Delay a bit before updating to final state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateConnectionStatusIndicator(connected: false)
        }
        
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
        //            PlaudDeviceAgent.shared.tryReconnectLastDevice()
        //        }
    }
    
    @objc private func startRateTestTapped() {
        // Check WiFi connection status, try to reconnect if disconnected
        checkWiFiConnectionAndReconnectIfNeeded { [weak self] in
            PlaudWiFiAgent.shared.startRateTest(true, 1024 * 5)
            self?.appendLog(NSLocalizedString("wifi.transfer.speed_test_starting", comment: ""))
            self?.updateStatusDisplay(NSLocalizedString("wifi.transfer.speed_test_starting_status", comment: ""))
        }
    }
    
    @objc private func stopRateTestTapped() {
        // Check WiFi connection status, try to reconnect if disconnected
        checkWiFiConnectionAndReconnectIfNeeded { [weak self] in
            PlaudWiFiAgent.shared.startRateTest(false, 1024 * 5)
            self?.appendLog(NSLocalizedString("wifi.transfer.speed_test_stopping", comment: ""))
            self?.updateStatusDisplay(NSLocalizedString("wifi.transfer.speed_test_stopped_status", comment: ""))
        }
    }
    
    @objc private func getLogsTapped() {
        // Check WiFi connection status, try to reconnect if disconnected
        checkWiFiConnectionAndReconnectIfNeeded { [weak self] in
            PlaudWiFiAgent.shared.getDeviceLogs(true)
            self?.appendLog("Getting device logs...")
        }
    }
    
    @objc private func getCurrentWiFiTapped() {
        appendLog(NSLocalizedString("wifi.transfer.getting_wifi_info", comment: ""))
        
        if let currentWiFi = PlaudWiFiAgent.shared.getCurrentWiFiName() {
            appendLog("📶 " + String(format: NSLocalizedString("wifi.transfer.current_wifi_name", comment: ""), currentWiFi))
            updateStatusDisplay(String(format: NSLocalizedString("wifi.transfer.current_wifi_name", comment: ""), currentWiFi))
        } else {
            appendLog("❌ " + NSLocalizedString("wifi.transfer.not_connected_to_wifi", comment: ""))
            updateStatusDisplay(NSLocalizedString("wifi.transfer.wifi_not_connected", comment: ""))
        }
        
        //        // Get connection status description
        //        let statusDescription = PlaudWiFiAgent.shared.getConnectionStatusDescription()
        //        appendLog("📋 " + String(format: NSLocalizedString("wifi.transfer.connection_status_description", comment: ""), statusDescription))
        //
        //        // Check if connected to device WiFi
        //        let deviceWiFiName = device.name
        //        let isConnectedToDevice = PlaudWiFiAgent.shared.isConnectedTo(deviceWiFiName)
        //        let yesNo = isConnectedToDevice ? NSLocalizedString("wifi.transfer.yes", comment: "") : NSLocalizedString("wifi.transfer.no", comment: "")
        //        appendLog("🔗 " + String(format: NSLocalizedString("wifi.transfer.connected_to_device_wifi", comment: ""), deviceWiFiName, yesNo))
        
        // Check WebSocket connection status
        let isWebSocketConnected = PlaudWiFiAgent.shared.isWebSocketConnected()
        let connectedStatus = isWebSocketConnected ? NSLocalizedString("wifi.transfer.connected", comment: "") : NSLocalizedString("wifi.transfer.not_connected", comment: "")
        appendLog("🌐 " + String(format: NSLocalizedString("wifi.transfer.websocket_status", comment: ""), connectedStatus))
    }
    
    @objc private func getFileListTapped() {
        // Check WiFi connection status, try to reconnect if disconnected
        checkWiFiConnectionAndReconnectIfNeeded { [weak self] in
            PlaudWiFiAgent.shared.getFileList(Int(Date().timeIntervalSince1970), 0)
            self?.appendLog("Getting file list...")
        }
    }
    
    @objc private func deleteFileTapped() {
        // Check WiFi connection status, try to reconnect if disconnected
        checkWiFiConnectionAndReconnectIfNeeded { [weak self] in
            guard let self = self else { return }
            
            guard self.fileList.count > 0 else {
                self.appendLog(NSLocalizedString("wifi.transfer.file_list_empty_getting", comment: ""))
                PlaudWiFiAgent.shared.getFileList(Int(Date().timeIntervalSince1970), 0)
                return
            }
            
            self.showFileSelectDialog(title: String(format: NSLocalizedString("wifi.transfer.select_file_to_delete", comment: ""), self.fileList.count)) { [weak self] bleFile in
                guard let self = self, let bleFile = bleFile else {
                    return
                }
                PlaudWiFiAgent.shared.deleteFile(bleFile.sessionId)
                self.appendLog(String(format: NSLocalizedString("wifi.transfer.delete_file_start", comment: ""), bleFile.sessionId))
            }
        }
    }
    
    @objc private func syncFileTapped() {
        // Check WiFi connection status, try to reconnect if disconnected
        checkWiFiConnectionAndReconnectIfNeeded { [weak self] in
            guard let self = self else { return }
            
            guard self.fileList.count > 0 else {
                self.appendLog(NSLocalizedString("wifi.transfer.file_list_empty_getting", comment: ""))
                PlaudWiFiAgent.shared.getFileList(Int(Date().timeIntervalSince1970), 0)
                return
            }
            
            self.showFileSelectDialog(title: String(format: NSLocalizedString("wifi.transfer.select_file_to_sync", comment: ""), self.fileList.count)) { [weak self] bleFile in
                guard let self = self, let bleFile = bleFile else {
                    return
                }
                PlaudWiFiAgent.shared.syncFile(bleFile.sessionId, 0)
                self.appendLog(String(format: NSLocalizedString("wifi.transfer.sync_file_start", comment: ""), bleFile.sessionId))
            }
        }
    }
    
    @objc private func stopSyncFileTapped() {
        // Check WiFi connection status, try to reconnect if disconnected
        checkWiFiConnectionAndReconnectIfNeeded { [weak self] in
            guard let self = self else { return }
            
            guard self.fileList.count > 0 else {
                self.appendLog(NSLocalizedString("wifi.transfer.file_list_empty_getting", comment: ""))
                PlaudWiFiAgent.shared.getFileList(Int(Date().timeIntervalSince1970), 0)
                return
            }
            
            self.showFileSelectDialog(title: String(format: NSLocalizedString("wifi.transfer.select_file_to_stop_sync", comment: ""), self.fileList.count)) { [weak self] bleFile in
                guard let self = self, let bleFile = bleFile else {
                    return
                }
                PlaudWiFiAgent.shared.stopSyncFile(bleFile.sessionId)
                self.appendLog(String(format: NSLocalizedString("wifi.transfer.stop_sync_file", comment: ""), bleFile.sessionId))
            }
        }
    }
    
    @objc private func startDownloadAllTapped() {
        // Check WiFi connection status, try to reconnect if disconnected
        checkWiFiConnectionAndReconnectIfNeeded { [weak self] in
            guard let self = self else { return }
            
            // Check if already in batch download
            guard !PlaudWiFiAgent.shared.isDownloadingAll else {
                self.appendLog("⚠️ " + NSLocalizedString("wifi.transfer.already_batch_downloading", comment: ""))
                self.updateStatusDisplay(NSLocalizedString("wifi.transfer.batch_downloading_status", comment: ""))
                return
            }
            
            // Check if other downloads are in progress
            guard !PlaudWiFiAgent.shared.isDownloading else {
                self.appendLog("⚠️ " + NSLocalizedString("wifi.transfer.other_download_in_progress", comment: ""))
                self.updateStatusDisplay(NSLocalizedString("wifi.transfer.other_download_status", comment: ""))
                return
            }
            
            self.appendLog("🚀 " + NSLocalizedString("wifi.transfer.start_batch_download", comment: ""))
            self.updateStatusDisplay(NSLocalizedString("wifi.transfer.preparing_batch_download", comment: ""))
            PlaudWiFiAgent.shared.startDownloadAll()
        }
    }
    
    @objc private func stopDownloadAllTapped() {
        // Check WiFi connection status, try to reconnect if disconnected
        checkWiFiConnectionAndReconnectIfNeeded { [weak self] in
            guard let self = self else { return }
            
            guard PlaudWiFiAgent.shared.isDownloadingAll else {
                self.appendLog("⚠️ " + NSLocalizedString("wifi.transfer.not_batch_downloading", comment: ""))
                self.updateStatusDisplay(NSLocalizedString("wifi.transfer.not_batch_downloading_status", comment: ""))
                return
            }
            
            self.appendLog("🛑 " + NSLocalizedString("wifi.transfer.stopping_batch_download", comment: ""))
            self.updateStatusDisplay(NSLocalizedString("wifi.transfer.stopping_batch_download_status", comment: ""))
            PlaudWiFiAgent.shared.stopDownloadAll()
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateStatusDisplay(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusDisplayLabel.text = status
        }
    }
    
    /// Check WiFi connection status, try to reconnect if disconnected
    /// - Parameter completion: Callback after WiFi connection is ready
    /// - Returns: Whether WiFi is currently connected
    @discardableResult
    private func checkWiFiConnectionAndReconnectIfNeeded(completion: (() -> Void)? = nil) -> Bool {
        // Check if WiFi is already connected
        if PlaudWiFiAgent.shared.isConnected {
            appendLog("✅ " + NSLocalizedString("wifi.transfer.wifi_connected_continue", comment: ""))
            completion?()
            return true
        }
        
        appendLog("❌ " + NSLocalizedString("wifi.transfer.wifi_not_connected_reconnecting", comment: ""))
        updateStatusDisplay(NSLocalizedString("wifi.transfer.wifi_not_connected_reconnecting_status", comment: ""))
        
        // Check Bluetooth connection status
        guard PlaudDeviceAgent.shared.isConnected() else {
            appendLog("🔵 " + NSLocalizedString("wifi.transfer.bluetooth_not_connected_trying_reconnect", comment: ""))
            updateStatusDisplay(NSLocalizedString("wifi.transfer.bluetooth_not_connected_reconnecting_status", comment: ""))
            
            // Try to reconnect Bluetooth
            PlaudDeviceAgent.shared.tryReconnectLastDevice()
            
            // Try to enable WiFi after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.attemptWiFiConnection(completion: completion)
            }
            return false
        }
        
        // Bluetooth is connected, directly try to enable WiFi
        attemptWiFiConnection(completion: completion)
        return false
    }
    
    private func attemptWiFiConnection(completion: (() -> Void)? = nil) {
        appendLog("🔵 " + NSLocalizedString("wifi.transfer.bluetooth_connected_opening_wifi", comment: ""))
        updateStatusDisplay(NSLocalizedString("wifi.transfer.bluetooth_connected_opening_wifi_status", comment: ""))
        
        // Save callback to execute after WiFi connection succeeds
        if let completion = completion {
            self.pendingWiFiCompletion = completion
        }
        
        PlaudDeviceAgent.shared.setDeviceWiFi(open: true)
    }
    
    // Store pending WiFi connection success callback
    private var pendingWiFiCompletion: (() -> Void)?
    
    private func updateConnectionStatusIndicator(connected: Bool, updateStatusText: Bool = true) {
        DispatchQueue.main.async { [weak self] in
            UIView.animate(withDuration: 0.3) {
                self?.connectionStatusIndicator.backgroundColor = connected ? .systemGreen : .systemRed
            }
            
            // Update status text when connection state changes (optional)
            if updateStatusText && !connected {
                self?.statusDisplayLabel.text = NSLocalizedString("wifi.transfer.wifi_disconnected", comment: "")
            }
        }
    }
    
    private func showFileSelectDialog(title: String, callback: @escaping (BleFile?) -> Void) {
        let optionController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        
        for (index, bleFile) in fileList.enumerated() {
            let fileTitle = String(format: NSLocalizedString("wifi.file.file_list_item", comment: ""), index + 1, bleFile.sessionId, formatFileSize(bleFile.size))
            let action = UIAlertAction(title: fileTitle, style: .default) { _ in
                callback(bleFile)
            }
            optionController.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("common.cancel", comment: ""), style: .cancel) { _ in
            callback(nil)
        }
        optionController.addAction(cancelAction)
        
        present(optionController, animated: true, completion: nil)
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let gb = mb * 1024.0
        
        let bytesDouble = Double(bytes)
        
        if bytesDouble >= gb {
            return String(format: "%.2f GB", bytesDouble / gb)
        } else if bytesDouble >= mb {
            return String(format: "%.2f MB", bytesDouble / mb)
        } else if bytesDouble >= kb {
            return String(format: "%.2f KB", bytesDouble / kb)
        } else {
            return "\(bytes) B"
        }
    }
    
    // MARK: - Log System
    
    private func setupLogSystem() {
        // Start timer to batch update UI every 0.5 seconds
        logUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.flushPendingLogs()
        }
    }
    
    private func cleanupLogSystem() {
        logUpdateTimer?.invalidate()
        logUpdateTimer = nil
        flushPendingLogs() // Final flush
    }
    
    private func appendLog(_ message: String) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let logMessage = "[\(timestamp)] \(message)"
            
            // Add to pending queue
            self.pendingLogs.append(logMessage)
            
            // If there are too many pending logs, flush immediately
            if self.pendingLogs.count >= 10 {
                self.flushPendingLogs()
            }
        }
    }
    
    private func flushPendingLogs() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Get pending logs
            let logsToAdd = self.pendingLogs
            self.pendingLogs.removeAll()
            
            guard !logsToAdd.isEmpty else { return }
            
            // Add to log array
            self.logMessages.append(contentsOf: logsToAdd)
            
            // Limit log count
            if self.logMessages.count > self.maxLogCount {
                let excessCount = self.logMessages.count - self.maxLogCount
                self.logMessages.removeFirst(excessCount)
            }
            
            // Update UI
            DispatchQueue.main.async {
                self.updateLogDisplay()
            }
        }
    }
    
    private func updateLogDisplay() {
        // Create copy of log array to avoid multi-threading access conflicts
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Safely get log copy in log queue
            let logMessagesCopy = Array(self.logMessages)
            let logCount = logMessagesCopy.count
            
            DispatchQueue.main.async {
                // Update UI on main thread
                let fullText = logMessagesCopy.joined(separator: "\n")
                self.logTextView.text = fullText
                
                // Scroll to bottom (using more efficient method)
                if !fullText.isEmpty {
                    let bottom = NSMakeRange(fullText.count - 1, 1)
                    self.logTextView.scrollRangeToVisible(bottom)
                }
                
                // Update log count display
                self.updateLogCountInStatus(logCount: logCount)
            }
        }
    }
    
    private func updateLogCountInStatus(logCount: Int? = nil) {
        // Get log count, prioritize using passed parameter to avoid multi-threading access issues
        let count: Int
        if let logCount = logCount {
            count = logCount
        } else {
            // If no parameter passed, safely get count in log queue
            logQueue.async { [weak self] in
                guard let self = self else { return }
                let safeCount = self.logMessages.count
                DispatchQueue.main.async {
                    self.updateLogCountInStatus(logCount: safeCount)
                }
            }
            return
        }
        
        // Only update log count when status display is still in default state
        let readyStatus = NSLocalizedString("wifi.transfer.ready_status", comment: "")
        if statusDisplayLabel.text?.contains(readyStatus) == true && count > 5 {
            statusDisplayLabel.text = String(format: NSLocalizedString("wifi.transfer.log_count_status", comment: ""), count, maxLogCount)
        }
    }
    
    @objc private func clearLogs() {
        logQueue.async { [weak self] in
            self?.logMessages.removeAll()
            self?.pendingLogs.removeAll()
            
            DispatchQueue.main.async {
                self?.logTextView.text = ""
                self?.appendLog(NSLocalizedString("wifi.transfer.logs_cleared", comment: ""))
            }
        }
    }
    
    private func showWiFiSettingsAlert(wifiName: String, wifiPass: String) {
        let message = NSLocalizedString("wifi.setup.message", comment: "").replacingOccurrences(of: "{wifiName}", with: wifiName).replacingOccurrences(of: "{wifiPass}", with: wifiPass)
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("common.cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("wifi.setup.go_to_settings", comment: ""), style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - PlaudWiFiAgentProtocol

extension WiFiTransferTestViewController: PlaudWiFiAgentProtocol, PlaudDeviceAgentProtocol {
    func blePenState(state: Int, privacy: Int, keyState: Int, uDisk: Int, findMyToken: Int, hasSndpKey: Int, deviceAccessToken: Int) {
        
    }
    
    func wifiConnectionStatus(_ ssid: String, _ connected: Bool) {
        let status = connected ? NSLocalizedString("wifi.transfer.connection_success_status", comment: "") : NSLocalizedString("wifi.transfer.connection_failed_status", comment: "")
        appendLog(String(format: NSLocalizedString("wifi.transfer.connection_failed", comment: ""), ssid, status))
        updateConnectionStatusIndicator(connected: connected)
        if connected {
            updateStatusDisplay(String(format: NSLocalizedString("wifi.transfer.wifi_connected_status", comment: ""), ssid))
        } else {
            // Status text on disconnect is already set in updateConnectionStatusIndicator
            // No need to repeat setting here, maintain consistency
        }
    }
    
    func wifiCommonErr(_ cmd: Int, _ status: Int) {
        appendLog(String(format: NSLocalizedString("wifi.transfer.wifi_error", comment: ""), cmd, status))
    }
    
    func wifiHandshake(_ status: Int) {
        appendLog(String(format: NSLocalizedString("wifi.transfer.wifi_handshake_result", comment: ""), status))
        updateConnectionStatusIndicator(connected: status == 0)
        if status == 0 {
            updateStatusDisplay(NSLocalizedString("wifi.transfer.wifi_handshake_success", comment: ""))
            // Execute pending operations
            if let completion = pendingWiFiCompletion {
                appendLog("🎯 " + NSLocalizedString("wifi.transfer.wifi_handshake_pending", comment: ""))
                pendingWiFiCompletion = nil // Clear immediately to prevent accidental repeated execution
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completion()
                }
            }
        } else {
            // Status text on handshake failure is already set in updateConnectionStatusIndicator
            // Maintain status text consistency
        }
    }
    
    func wifiPower(_ power: Int, _ voltage: Int) {
        appendLog(String(format: NSLocalizedString("wifi.transfer.wifi_power", comment: ""), power, voltage))
    }
    
    func wifiFileListFail(_ status: Int) {
        appendLog(String(format: NSLocalizedString("wifi.transfer.file_list_failed", comment: ""), status))
    }
    
    func wifiFileList(_ files: [BleFile]) {
        debugPrint("wifiFileList - count: \(files.count)")
        
        // Save file list
        fileList = files
        
        appendLog(String(format: NSLocalizedString("wifi.transfer.file_list_received", comment: ""), files.count))
        for (index, file) in files.enumerated() {
            appendLog(String(format: NSLocalizedString("wifi.transfer.file_info", comment: ""), index + 1, file.sessionId, formatFileSize(file.size)))
        }
        
        if files.isEmpty {
            appendLog(NSLocalizedString("wifi.transfer.no_files_in_device", comment: ""))
            updateStatusDisplay(NSLocalizedString("wifi.transfer.no_files_status", comment: ""))
        } else {
            updateStatusDisplay(String(format: NSLocalizedString("wifi.transfer.files_available", comment: ""), files.count))
        }
    }
    
    func wifiSyncFile(_ sessionId: Int, _ status: Int) {
        appendLog(String(format: NSLocalizedString("wifi.transfer.sync_file_status_log", comment: ""), sessionId, status))
        if status == 0 {
            updateStatusDisplay(String(format: NSLocalizedString("wifi.transfer.syncing_file_status", comment: ""), sessionId))
            // Reset counter when starting new sync
            syncDataCounter = 0
        } else {
            updateStatusDisplay(String(format: NSLocalizedString("wifi.transfer.sync_file_failed_status", comment: ""), sessionId))
        }
    }
    
    func wifiSyncFileData(_ sessionId: Int, _ offset: Int, _ count: Int, _ binData: Data) {
        syncDataCounter += 1
        let now = Date()
        
        // Log every 50 data packets or every 2 seconds to avoid excessive logging
        if syncDataCounter % 50 == 0 || now.timeIntervalSince(lastSyncLogTime) > 2.0 {
            let progress = String(format: "%.2f", Double(offset) / 1024.0 / 1024.0)
            appendLog(String(format: NSLocalizedString("wifi.transfer.sync_file_data_received", comment: ""), sessionId, progress))
            
            // Update status display with speed info, split into two lines
            let speedInfo = PlaudWiFiAgent.shared.getFormattedDownloadSpeed()
            let line1 = String(format: NSLocalizedString("wifi.transfer.downloading_file_id", comment: ""), sessionId)
            let line2 = String(format: NSLocalizedString("wifi.transfer.file_data_with_speed", comment: ""), progress, speedInfo)
            updateStatusDisplay("\(line1)\n\(line2)")
            
            lastSyncLogTime = now
        }
        
        // Get temporary directory path (consistent with CloudSyncViewController)
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(sessionId).dat")
        let documentsPath = tempDir.path
        let fileName = "\(sessionId).dat"
        
        PLBleFileManager.shared.saveBleFile(
            filePath: documentsPath,
            fileName: fileName,
            start: offset,
            data: binData
        )
        
        // Only log file save path on first write
        if offset == 0 {
            appendLog("📁 " + String(format: NSLocalizedString("wifi.transfer.file_save_path_log", comment: ""), fileURL.path))
        }
    }
    
    func wifiDataComplete() {
        appendLog(NSLocalizedString("wifi.transfer.data_complete", comment: ""))
        
        // Check if batch downloading is in progress
        if PlaudWiFiAgent.shared.isDownloadingAll {
            // Batch downloading in progress, no popup, just update status
            let line1 = NSLocalizedString("wifi.transfer.current_file_complete", comment: "")
            let line2 = NSLocalizedString("wifi.transfer.continue_batch", comment: "")
            updateStatusDisplay("\(line1)\n\(line2)")
        } else {
            // Single file download complete, show completion status and popup
            let line1 = NSLocalizedString("wifi.transfer.file_complete", comment: "")
            let line2 = NSLocalizedString("wifi.transfer.saved_locally", comment: "")
            updateStatusDisplay("\(line1)\n\(line2)")
            
            // Show success message, guide user to cloud sync interface to view files
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showFileDownloadCompleteAlert()
            }
        }
        
        // Reset counter
        syncDataCounter = 0
    }
    
    /// Show file download completion alert
    private func showFileDownloadCompleteAlert() {
        let alert = UIAlertController(
            title: NSLocalizedString("wifi.transfer.download_complete_title", comment: ""),
            message: NSLocalizedString("wifi.transfer.download_complete_message", comment: ""),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("wifi.transfer.view_later", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("wifi.transfer.go_view", comment: ""), style: .default) { [weak self] _ in
            self?.navigateToCloudSync()
        })
        
        present(alert, animated: true)
    }
    
    /// Navigate to cloud sync interface
    private func navigateToCloudSync() {
        guard let navigationController = navigationController else { return }
        
        // Check if CloudSyncViewController already exists in navigation stack
        for viewController in navigationController.viewControllers {
            if let cloudSyncVC = viewController as? CloudSyncViewController {
                navigationController.popToViewController(cloudSyncVC, animated: true)
                return
            }
        }
        
        // If none exists, create new CloudSyncViewController
        let cloudSyncVC = CloudSyncViewController(device: device)
        navigationController.pushViewController(cloudSyncVC, animated: true)
    }
    
    func wifiSyncFileStop(_ status: Int) {
        appendLog("Sync File Stopped - status: \(status)")
    }
    
    func wifiFileDelete(_ sessionId: Int, _ status: Int) {
        appendLog(String(format: NSLocalizedString("wifi.transfer.delete_file_result_log", comment: ""), sessionId, status))
        if status == 0 {
            updateStatusDisplay(String(format: NSLocalizedString("wifi.transfer.file_delete_success_status", comment: ""), sessionId))
            // Remove deleted file from local list
            fileList.removeAll { $0.sessionId == sessionId }
        } else {
            updateStatusDisplay(String(format: NSLocalizedString("wifi.transfer.file_delete_failed_status", comment: ""), sessionId))
        }
    }
    
    func wifiClientFail() {
        appendLog("WiFi Client Failed")
        updateConnectionStatusIndicator(connected: false)
    }
    
    func wifiClose(_ status: Int) {
        appendLog("WiFi Closed - status: \(status)")
        updateConnectionStatusIndicator(connected: false)
    }
    
    func wifiRateFail(_ status: Int) {
        appendLog(String(format: NSLocalizedString("wifi.transfer.rate_test_failed", comment: ""), status))
        updateStatusDisplay(NSLocalizedString("wifi.transfer.speed_test_failed_status", comment: ""))
    }
    
    func wifiRate(_ instantRate: Int, _ averageRate: Int, _ lossRate: Double) {
        debugPrint("onWiFiRate, instantRate:\(instantRate), averageRate:\(averageRate), lossRate:\(lossRate)")
        
        let now = Date()
        let instant = Double(instantRate) / 1024.0
        let average = Double(averageRate) / 1024.0
        
        // Update status display with real-time speed info
        let line1 = NSLocalizedString("wifi.transfer.speed_test_running", comment: "")
        let line2 = String(format: NSLocalizedString("wifi.transfer.speed_test_result", comment: ""), instant, average, lossRate)
        updateStatusDisplay("\(line1)\n\(line2)")
        
        // Log rate test results every 2 seconds to avoid log spam
        if now.timeIntervalSince(lastRateLogTime) > 2.0 {
            appendLog(String(format: NSLocalizedString("wifi.transfer.rate_test_result_log", comment: ""), instant, average, lossRate))
            lastRateLogTime = now
        }
    }
    
    func wifiLogsFail(_ status: Int) {
        appendLog("Get Logs Failed - status: \(status)")
    }
    
    func wifiLogs(_ logData: Data?) {
        if let data = logData {
            appendLog("Received Logs - size: \(data.count) bytes")
        } else {
            appendLog("Received Empty Logs")
        }
    }
    
    func wifiTips(_ tips: Int) {
        switch tips {
        case 1:
            appendLog(String(format: NSLocalizedString("wifi.transfer.wifi_tips_no_recording", comment: ""), tips))
        default:
            break
        }
    }
    
    // MARK: - Batch Download Delegate Methods
    func wifiDownloadAllProgress(_ totalFiles: Int, _ currentFileIndex: Int, _ currentFile: BleFile?, _ totalProgress: Double) {
        let progressPercentage = Int(totalProgress * 100)
        let speedInfo = PlaudWiFiAgent.shared.getFormattedDownloadSpeed()
        
        if let file = currentFile {
            let fileSize = formatFileSize(file.size)
            appendLog(String(format: NSLocalizedString("wifi.transfer.batch_progress_log", comment: ""), progressPercentage, currentFileIndex, totalFiles, file.sessionId, fileSize))
            // Split into two lines: first line shows basic info, second line shows progress and speed
            let line1 = String(format: NSLocalizedString("wifi.transfer.downloading_file_progress", comment: ""), currentFileIndex, totalFiles, file.sessionId)
            let line2 = String(format: NSLocalizedString("wifi.transfer.total_progress_with_speed", comment: ""), progressPercentage, speedInfo)
            updateStatusDisplay("\(line1)\n\(line2)")
        } else {
            appendLog(String(format: NSLocalizedString("wifi.transfer.batch_progress_log", comment: ""), progressPercentage, currentFileIndex, totalFiles, 0, ""))
            // Split into two lines: first line shows basic info, second line shows progress and speed
            let line1 = String(format: NSLocalizedString("wifi.transfer.batch_progress_only", comment: ""), currentFileIndex, totalFiles)
            let line2 = String(format: NSLocalizedString("wifi.transfer.total_progress_speed_only", comment: ""), progressPercentage, speedInfo)
            updateStatusDisplay("\(line1)\n\(line2)")
        }
        
        // Add detailed progress info, but control frequency to avoid excessive logging
        if progressPercentage % 10 == 0 { // Log detailed progress every 10%
            appendLog(String(format: NSLocalizedString("wifi.transfer.detail_progress_log", comment: ""), totalFiles, currentFileIndex, totalProgress * 100))
        }
    }
    
    func wifiDownloadAllCompleted(_ completedFiles: Int, _ failedFiles: Int) {
        let totalFiles = completedFiles + failedFiles
        appendLog("🎉 " + NSLocalizedString("wifi.transfer.batch_download_complete_log", comment: ""))
        appendLog("✅ " + String(format: NSLocalizedString("wifi.transfer.download_success_count", comment: ""), completedFiles))
        
        if failedFiles > 0 {
            appendLog("❌ " + String(format: NSLocalizedString("wifi.transfer.download_failed_count", comment: ""), failedFiles))
            let line1 = String(format: NSLocalizedString("wifi.transfer.batch_complete_mixed_status", comment: ""), completedFiles, failedFiles)
            let line2 = NSLocalizedString("wifi.transfer.saved_locally", comment: "")
            updateStatusDisplay("\(line1)\n\(line2)")
        } else {
            appendLog("🚀 " + NSLocalizedString("wifi.transfer.all_files_success_log", comment: ""))
            let line1 = String(format: NSLocalizedString("wifi.transfer.batch_complete_success_status", comment: ""), completedFiles)
            let line2 = NSLocalizedString("wifi.transfer.saved_locally", comment: "")
            updateStatusDisplay("\(line1)\n\(line2)")
        }
        
        // Statistics
        let successRate = totalFiles > 0 ? String(format: "%.1f", Double(completedFiles) / Double(totalFiles) * 100) : "0"
        appendLog("📊 " + String(format: NSLocalizedString("wifi.transfer.download_statistics", comment: ""), totalFiles, Float(successRate) ?? 0.0))
        
        // Show batch download completion alert
        if completedFiles > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showBatchDownloadCompleteAlert(completedFiles: completedFiles, failedFiles: failedFiles)
            }
        }
        
        // Refresh file list
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.appendLog(NSLocalizedString("wifi.transfer.refreshing_file_list", comment: ""))
            PlaudWiFiAgent.shared.getFileList(Int(Date().timeIntervalSince1970), 0)
        }
    }
    
    /// Show batch download completion alert
    private func showBatchDownloadCompleteAlert(completedFiles: Int, failedFiles: Int) {
        let title = NSLocalizedString("wifi.transfer.batch_complete_title", comment: "")
        let message: String
        
        if failedFiles > 0 {
            message = String(format: NSLocalizedString("wifi.transfer.batch_complete_partial_message", comment: ""), completedFiles, failedFiles)
        } else {
            message = String(format: NSLocalizedString("wifi.transfer.batch_complete_success_message", comment: ""), completedFiles)
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("wifi.transfer.view_later", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("wifi.transfer.go_view", comment: ""), style: .default) { [weak self] _ in
            self?.navigateToCloudSync()
        })
        
        present(alert, animated: true)
    }
    
    func bleWiFiOpen(_ status: Int, _ wifiName: String, _ wholeName: String, _ wifiPass: String) {
        if status == 0 {
            PlaudWiFiAgent.shared.bleDevice = BleAgent.shared.bleDevice
        }
        self.onWiFiOpen(status, wifiName, wholeName, wifiPass)
    }
    
    func onWiFiOpen(_ status: Int, _ wifiName: String, _ wholeName: String, _ wifiPass: String) {
        debugPrint("onWiFiOepn status:\(status)")
        switch status {
        case 0:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.connectToWiFi(wifiName, wifiPass)
            }
        case 1:
            showToastWithMessage(NSLocalizedString("wifi.error.recording_in_progress", comment: ""))
        case 2:
            showToastWithMessage(NSLocalizedString("wifi.error.udisk_mode_active", comment: ""))
        default:
            break
        }
    }
    
    private func connectToWiFi(_ wifiName: String, _ wifiPass: String) {
        debugPrint("connectToWiFi name:\(wifiName), pass:\(wifiPass)")
        
        if #available(iOS 11.0, *) {
            PlaudWiFiAgent.shared.connectWifi(wifiName, wifiPass, 60)
            //            PlaudWiFiAgent.shared.listenPort(wifiName, 30)
        } else {
            PlaudWiFiAgent.shared.listenPort(wifiName, 30)
            // Guide user to system settings to connect to recording pen's WiFi
            let message = NSLocalizedString("wifi.setup.message", comment: "").replacingOccurrences(of: "{wifiName}", with: wifiName).replacingOccurrences(of: "{wifiPass}", with: wifiPass)
            showNormalAlert(title: nil, message: message, cancelTitle: NSLocalizedString("common.cancel", comment: ""), cancelHandler: { (_) in
                
            }, okTitle: NSLocalizedString("wifi.setup.go_to_settings", comment: "")) { (_) in
                let settingUrl = URL(string: UIApplication.openSettingsURLString)!
                if UIApplication.shared.canOpenURL(settingUrl) {
                    UIApplication.shared.open(settingUrl, options: [:], completionHandler: nil)
                }
            }
        }
    }
    
    private func setupToastView() {
        if let toastView = toastView {
            toastView.removeFromSuperview()
            self.toastView = nil
        }
        
        toastView = UIView()
        toastView?.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastView?.layer.cornerRadius = 10
        toastView?.clipsToBounds = true
        toastView?.translatesAutoresizingMaskIntoConstraints = false
        toastView?.alpha = 0
        
        if let window = UIApplication.shared.keyWindow {
            window.addSubview(toastView!)
        }
        
        toastLabel = UILabel()
        toastLabel?.textColor = .white
        toastLabel?.font = .systemFont(ofSize: 15)
        toastLabel?.textAlignment = .center
        toastLabel?.numberOfLines = 0
        toastLabel?.translatesAutoresizingMaskIntoConstraints = false
        toastView?.addSubview(toastLabel!)
        
        NSLayoutConstraint.activate([
            toastView!.centerXAnchor.constraint(equalTo: UIApplication.shared.keyWindow!.centerXAnchor),
            toastView!.centerYAnchor.constraint(equalTo: UIApplication.shared.keyWindow!.centerYAnchor),
            toastView!.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            toastView!.leadingAnchor.constraint(greaterThanOrEqualTo: UIApplication.shared.keyWindow!.leadingAnchor, constant: 40),
            toastView!.trailingAnchor.constraint(lessThanOrEqualTo: UIApplication.shared.keyWindow!.trailingAnchor, constant: -40),
            
            toastLabel!.topAnchor.constraint(equalTo: toastView!.topAnchor, constant: 12),
            toastLabel!.leadingAnchor.constraint(equalTo: toastView!.leadingAnchor, constant: 16),
            toastLabel!.trailingAnchor.constraint(equalTo: toastView!.trailingAnchor, constant: -16),
            toastLabel!.bottomAnchor.constraint(equalTo: toastView!.bottomAnchor, constant: -12),
        ])
    }
    
    
    func showToastWithMessage(_ message: String) {
        guard !message.isEmpty else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Cancel previous show and hide operations
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.hideToast), object: nil)
            
            // Ensure toastView is initialized
            if self.toastView == nil {
                self.setupToastView()
            }
            
            // If currently showing animation, complete current animation first
            if self.toastView?.alpha ?? 0 > 0 {
                UIView.animate(withDuration: 0.15, animations: {
                    self.toastView?.alpha = 0.0
                }) { _ in
                    self.showNewToast(message)
                }
            } else {
                self.showNewToast(message)
            }
        }
    }
    
    private func showNewToast(_ message: String) {
        toastLabel?.text = message
        toastLabel?.sizeToFit()
        
        // Show animation
        UIView.animate(withDuration: 0.25, animations: {
            self.toastView?.alpha = 1.0
        }) { _ in
            // Auto hide after 2 seconds
            self.perform(#selector(self.hideToast), with: nil, afterDelay: 2.0)
        }
    }
    
    @objc private func hideToast() {
        DispatchQueue.main.async { [weak self] in
            UIView.animate(withDuration: 0.25, animations: {
                self?.toastView?.alpha = 0.0
            })
        }
    }
    
    func showNormalAlert(title: String? = nil, message: String, cancelTitle: String = "",
                         cancelHandler: ((UIAlertAction) -> Void)? = nil, okTitle: String = "",
                         okHandler: ((UIAlertAction) -> Void)? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        if cancelHandler == nil && okHandler == nil {
            let okAction = UIAlertAction(title: okTitle, style: .default, handler: nil)
            alertController.addAction(okAction)
        } else {
            if cancelHandler != nil {
                let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel, handler: cancelHandler)
                cancelAction.setValue(UIColor.gray, forKey: "titleTextColor")
                alertController.addAction(cancelAction)
            }
            if okHandler != nil {
                let okAction = UIAlertAction(title: okTitle, style: .default, handler: okHandler)
                alertController.addAction(okAction)
            }
        }
        self.present(alertController, animated: true, completion: nil)
    }
    
    public func bleConnectState(state: Int) {
        // Test disconnect and reconnect
        if state == 0 {
            updateStatusDisplay(NSLocalizedString("wifi.transfer.bluetooth_disconnected", comment: ""))
        }
        
        if state == 1 {
            updateStatusDisplay(NSLocalizedString("wifi.transfer.bluetooth_connected_success", comment: ""))
        }
    }
}
