import PlaudDeviceBasicSDK
import PenWiFiSDK
import UIKit

// import FirebaseAnalytics

@objc class DeviceInfoViewController: UIViewController {
    // MARK: - Properties
    
    private let device: BleDevice
    private var deviceAgent = PlaudDeviceAgent.shared
    private var recordList = [BleFile]()
    private var downlodingFileInfo: BleFile? = nil
    private var downloadedFiles: [String: String] = [:]
    
    // Toast View
    private var toastView: UIView?
    private var toastLabel: UILabel?
    private var progressAlert: ProgressAlertController?
    private var wifiOpening = false
    private var manualGet: Bool = false
    
    // Firmware update properties
    // Note: currentVersionInfo removed - version info is now passed directly through method parameters
    
    // Basic information area
    private let infoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 1
        view.layer.shadowRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // USB disk access switch
    private let udiskAccessLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("device.info.udisk_access", comment: "")
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
        return label
    }()
    
    private let udiskAccessSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.onTintColor = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        return switchControl
    }()
    
    // New: USB disk access horizontal stack
    private lazy var udiskAccessStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [udiskAccessLabel, udiskAccessSwitch])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // USB disk mode warning label
    private let udiskModeWarningLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("device.warning.udisk_mode_active", comment: "")
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    private let deviceNameLabel = InfoItemView(title: NSLocalizedString("device.info.name", comment: ""))
    private let snLabel = InfoItemView(title: NSLocalizedString("device.info.sn", comment: ""))
    // Firmware info view with embedded update button
    private lazy var firmwareInfoView: FirmwareInfoView = {
        let view = FirmwareInfoView(title: NSLocalizedString("device.info.firmware", comment: ""))
        view.onUpdateButtonTapped = { [weak self] in
            self?.firmwareUpdateButtonTapped()
        }
        return view
    }()
    private let storageLabel = InfoItemView(title: NSLocalizedString("device.info.storage", comment: ""))
    private let batteryLabel = InfoItemView(title: NSLocalizedString("device.info.battery", comment: ""))
    
    // Action panel area
    private let actionContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 1
        view.layer.shadowRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let actionStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let horizontalStackView1: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let horizontalStackView2: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let horizontalStackView3: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let horizontalStackView4: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // New WiFi control stack view
    private let wifiControlStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // MARK: - Action Buttons
    
    private lazy var startRecordButton = createActionButton(title: NSLocalizedString("device.action.start_record", comment: ""), bgColor: UIColor(red: 39 / 255, green: 174 / 255, blue: 96 / 255, alpha: 1), textColor: .white)
    private lazy var pauseRecordButton = createActionButton(title: NSLocalizedString("device.action.pause_record", comment: ""), bgColor: UIColor(red: 243 / 255, green: 156 / 255, blue: 18 / 255, alpha: 1), textColor: .white)
    private lazy var resumeRecordButton = createActionButton(title: NSLocalizedString("device.action.resume_record", comment: ""), bgColor: UIColor(red: 41 / 255, green: 128 / 255, blue: 239 / 255, alpha: 1), textColor: .white)
    private lazy var stopRecordButton = createActionButton(title: NSLocalizedString("device.action.stop_record", comment: ""), bgColor: UIColor(red: 231 / 255, green: 76 / 255, blue: 60 / 255, alpha: 1), textColor: .white)
    private lazy var getFileListButton = createActionButton(title: NSLocalizedString("device.action.get_file_list", comment: ""))
    private lazy var syncFileButton = createActionButton(title: NSLocalizedString("device.action.sync_file", comment: ""))
    private lazy var deleteFileButton = createActionButton(title: NSLocalizedString("device.action.delete_file", comment: ""))
    private lazy var deleteAllFilesButton = createActionButton(title: NSLocalizedString("device.action.delete_all_files", comment: ""), bgColor: UIColor(red: 231 / 255, green: 76 / 255, blue: 60 / 255, alpha: 1), textColor: .white)
    private lazy var downloadTranscodedButton = createActionButton(title: NSLocalizedString("device.action.download_transcoded", comment: ""))
    
    // New area buttons
    private lazy var associateUserButton = createActionButton(title: NSLocalizedString("device.action.associate_user", comment: ""))
    private lazy var wifiSettingButton = createActionButton(title: NSLocalizedString("device.action.wifi_setting", comment: ""))
    
    // WiFi control buttons
    private lazy var openDeviceWifiButton = createActionButton(title: "⚡ " + NSLocalizedString("device.action.wifi_fast_transfer", comment: ""))
    private lazy var closeDeviceWifiButton = createActionButton(title: NSLocalizedString("device.action.device_name", comment: ""))
    
    // New audio player button
    //    private lazy var audioPlayerButton: UIButton = {
    //        let button = UIButton(type: .system)
    //        button.setTitle(NSLocalizedString("device.action.audio_player", comment: ""), for: .normal)
    //        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
    //        button.layer.cornerRadius = 8
    //        button.backgroundColor = .white
    //        button.layer.borderWidth = 1
    //        button.layer.borderColor = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0).cgColor
    //        button.setTitleColor(UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0), for: .normal)
    //        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
    //        button.addTarget(self, action: #selector(audioPlayerButtonTapped), for: .touchUpInside)
    //        return button
    //    }()
    
    // MARK: - Initialization
    
    @objc init(device: BleDevice) {
        self.device = device
        super.init(nibName: nil, bundle: nil)
        
        // Initialize switch state
        udiskAccessSwitch.isOn = device.privacy == 0
    }
    
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        deviceAgent.delegate = self
        setupUI()
        updateDeviceInfo()
        setupToastView()
        setupNavigationBarButtons()
        
        // deviceAgent.getChargingState()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.deviceAgent.getChargingState()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // If there's currently a Toast being displayed, let it complete its display
        if let toastView = toastView, toastView.alpha > 0 {
            // Cancel previous auto-hide operations
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideToast), object: nil)
            // Set new auto-hide time to ensure complete display
            perform(#selector(hideToast), with: nil, afterDelay: 2.5)
        } else {
            // If no Toast is displaying, clean up normally
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideToast), object: nil)
            hideToast()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if PlaudDeviceAgent.shared.delegate is DeviceInfoViewController == false {
            self.deviceAgent = PlaudDeviceAgent.shared
            self.deviceAgent.delegate = self
            
            self.deviceAgent.tryReconnectLastDevice()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if let navController = navigationController {
            let allViewControllers = navController.viewControllers
            if let topVC = navController.topViewController {
                let hasScanVC = topVC is ScanDeviceViewController
                if hasScanVC == true {
                    deviceAgent.disconnect()
                }
            }
        } else {
            deviceAgent.disconnect()
        }
    }
    
    // MARK: - UI Setup
    
    // Add scroll view for better content handling
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
        title = NSLocalizedString("device.info.title", comment: "")
        
        setupScrollView()
        setupInfoSection()
        setupActionSection()
        setupConstraints()
    }
    
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
    
    private func setupInfoSection() {
        contentView.addSubview(infoContainerView)
        
        let stackView = UIStackView(arrangedSubviews: [
            deviceNameLabel,
            snLabel,
            firmwareInfoView,
            storageLabel,
            batteryLabel,
            udiskAccessStackView,
            udiskModeWarningLabel,
        ])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        infoContainerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: infoContainerView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: infoContainerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: infoContainerView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: infoContainerView.bottomAnchor, constant: -16),
        ])
        
        // Add switch event handling
        udiskAccessSwitch.addTarget(self, action: #selector(udiskAccessSwitchChanged(_:)), for: .valueChanged)
    }
    
    private func setupActionSection() {
        contentView.addSubview(actionContainerView)
        actionContainerView.addSubview(actionStackView)
        
        // New horizontal stack view
        let horizontalStackView5: UIStackView = {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.spacing = 12
            stackView.translatesAutoresizingMaskIntoConstraints = false
            return stackView
        }()
        
        horizontalStackView5.addArrangedSubview(openDeviceWifiButton)
        horizontalStackView5.addArrangedSubview(wifiSettingButton)
        
        horizontalStackView1.addArrangedSubview(startRecordButton)
        horizontalStackView1.addArrangedSubview(pauseRecordButton)
        
        // Add WiFi control buttons to new stack view
        wifiControlStackView.addArrangedSubview(closeDeviceWifiButton)
        wifiControlStackView.addArrangedSubview(associateUserButton)
        
        horizontalStackView2.addArrangedSubview(stopRecordButton)
        horizontalStackView2.addArrangedSubview(resumeRecordButton)
        
        horizontalStackView3.addArrangedSubview(getFileListButton)
        horizontalStackView3.addArrangedSubview(deleteFileButton)
        
        horizontalStackView4.addArrangedSubview(downloadTranscodedButton)
        horizontalStackView4.addArrangedSubview(syncFileButton)
        
        // Add stack view for transcoding button
        let horizontalStackView6: UIStackView = {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.spacing = 12
            stackView.translatesAutoresizingMaskIntoConstraints = false
            return stackView
        }()
        
        horizontalStackView6.addArrangedSubview(deleteAllFilesButton)
        
        // Add all views to main stack
        actionStackView.addArrangedSubview(horizontalStackView5)
        actionStackView.addArrangedSubview(wifiControlStackView)
        actionStackView.addArrangedSubview(horizontalStackView1)
        actionStackView.addArrangedSubview(horizontalStackView2)
        actionStackView.addArrangedSubview(horizontalStackView3)
        actionStackView.addArrangedSubview(horizontalStackView4)
        actionStackView.addArrangedSubview(horizontalStackView6)
        
        NSLayoutConstraint.activate([
            actionStackView.topAnchor.constraint(equalTo: actionContainerView.topAnchor, constant: 16),
            actionStackView.leadingAnchor.constraint(equalTo: actionContainerView.leadingAnchor, constant: 16),
            actionStackView.trailingAnchor.constraint(equalTo: actionContainerView.trailingAnchor, constant: -16),
            actionStackView.bottomAnchor.constraint(equalTo: actionContainerView.bottomAnchor, constant: -16),
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            infoContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            infoContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            infoContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            actionContainerView.topAnchor.constraint(equalTo: infoContainerView.bottomAnchor, constant: 12),
            actionContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            actionContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            actionContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }
    
    // MARK: - Helper Methods
    
    private func createActionButton(title: String, bgColor: UIColor, textColor: UIColor = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 8
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        button.backgroundColor = bgColor
        button.setTitleColor(textColor, for: .normal)
        if bgColor == .white {
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0).cgColor
        }
        
        button.addTarget(self, action: #selector(actionButtonTapped(_:)), for: .touchUpInside)
        return button
    }
    
    private func createActionButton(title: String, textColor: UIColor = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)) -> UIButton {
        return createActionButton(title: title, bgColor: .white, textColor: textColor)
    }
    
    private func updateDeviceInfo() {
        deviceNameLabel.setValue(device.name)
        snLabel.setValue(device.serialNumber)
        firmwareInfoView.setValue(device.wholeVersion())
        storageLabel.setValue("-- GB / -- GB")
        batteryLabel.setValue("--")
    }
    
    // MARK: - Actions
    
    @objc private func actionButtonTapped(_ sender: UIButton) {
        switch sender {
        case startRecordButton:
            deviceAgent.startRecord()
        case pauseRecordButton:
            deviceAgent.pauseRecord()
        case resumeRecordButton:
            deviceAgent.resumeRecord()
        case stopRecordButton:
            deviceAgent.stopRecord()
        case getFileListButton:
            getFileList(button: sender)
        case syncFileButton:
            cloudSync(button: sender)
        case deleteFileButton:
            deleteFile(button: sender)
        case deleteAllFilesButton:
            deviceAgent.clearAllFiles()
        case associateUserButton:
            showAssociateUserDialog()
        case wifiSettingButton:
            goWifiSettingPage(button: sender)
        case downloadTranscodedButton:
            downloadTranscoded(button: sender)
        case openDeviceWifiButton:
            openDeviceWifi(button: sender)
        case closeDeviceWifiButton:
            showDeviceNameDialog(button: sender)
            //        case audioPlayerButton:
            //            audioPlayerButtonTapped()
        default:
            break
        }
    }
    
    @objc private func cloudSync(button _: UIButton) {
        let vc = CloudSyncViewController(device: device)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func getFileList(button _: UIButton) {
        guard !deviceAgent.checkIsRecording() else {
            showToastWithMessage(NSLocalizedString("device.error.recording_in_progress", comment: ""))
            return
        }
        
        manualGet = true
        deviceAgent.getFileList(startSessionId: 0)
    }
    
    @objc private func goWifiSettingPage(button _: UIButton) {
        let vc = PlaudWifiSettingPage()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func openDeviceWifi(button _: UIButton) {
        wifiOpening = true
        
        if PlaudWiFiAgent.shared.isConnected {
            // WiFi already connected, go directly to transfer page
            navigateToWiFiTransferPage()
        } else {
            // WiFi not connected, open device WiFi first
            if deviceAgent.isConnected() {
                deviceAgent.setDeviceWiFi(open: true)
            } else {
                navigateToWiFiTransferPage()
            }
        }
    }
    
    @objc private func closeDeviceWifi(button _: UIButton) {
        deviceAgent.setDeviceWiFi(open: false)
    }
    
    /// Check WiFi connection status convenience method
    private func checkWiFiConnectionStatus() {
        let statusDescription = PlaudWiFiAgent.shared.getConnectionStatusDescription()
        debugPrint("Current WiFi status: \(statusDescription)")
        showToastWithMessage(statusDescription)
    }
    
    /// Navigate to WiFi transfer page - unified method to avoid duplicate navigation
    private func navigateToWiFiTransferPage() {
        // Check if already on WiFi transfer page to avoid duplicate navigation
        if let topVC = navigationController?.topViewController, topVC is WiFiTransferTestViewController {
            debugPrint("Already on WiFi transfer page, skipping navigation")
            wifiOpening = false
            return
        }
        
        let wifiTestVC = WiFiTransferTestViewController(device: self.device)
        navigationController?.pushViewController(wifiTestVC, animated: true)
        wifiOpening = false
    }
    
    @objc private func downloadTranscoded(button _: UIButton) {
        guard !deviceAgent.checkIsRecording() else {
            showToastWithMessage(NSLocalizedString("device.error.recording_download_only", comment: ""))
            return
        }
        
        guard recordList.count > 0 else {
            showToastWithMessage(NSLocalizedString("device.error.get_file_list_first", comment: ""))
            return
        }
        
        let title = NSLocalizedString("device.dialog.file_count", comment: "").replacingOccurrences(of: "{count}", with: "\(recordList.count)")
        showRecordSelectDialog(title: title) { [weak self] bleFile in
            guard let `self` = self, let bleFile = bleFile else {
                return
            }
            
            // Show progress bar popup
            self.progressAlert = ProgressAlertController(title: NSLocalizedString("device.progress.downloading_transcoded", comment: ""))
            self.progressAlert?.onCancel = { [weak self] in
                self?.deviceAgent.stopDownloadFile()
            }
            self.progressAlert?.onUpload = { [weak self] in
                if PlaudFileUploader.shared.checkRecordingExist(sessionId: bleFile.sessionId) {
                    // First close current download progress popup
                    self?.progressAlert?.dismiss(animated: true) {
                        // Show upload progress popup after download popup is closed
                        PlaudFileUploader.shared.device = self?.device
                        
                        // Show upload progress popup
                        let uploadProgressAlert = UploadProgressAlertController(title: NSLocalizedString("upload.progress.title", comment: ""))
                        uploadProgressAlert.onCancel = {
                            // TODO: Need to call PlaudFileUploader's cancel upload method here
                            uploadProgressAlert.dismiss(animated: true)
                        }
                        self?.present(uploadProgressAlert, animated: true)
                        
                        PlaudFileUploader.shared.uploadRecording(
                            sn: bleFile.sn,
                            sessionId: bleFile.sessionId,
                            duration: Double(bleFile.duration()),
                            onProgress: { progress in
                                // Update upload progress
                                DispatchQueue.main.async {
                                    uploadProgressAlert.updateProgress(Float(progress))
                                }
                            },
                            onSuccess: { response in
                                DispatchQueue.main.async {
                                    // Upload successful
                                    uploadProgressAlert.updateProgress(1.0, text: NSLocalizedString("upload.progress.success", comment: ""))
                                    uploadProgressAlert.setActionButtonAsConfirm()
                                    uploadProgressAlert.onConfirm = {
                                        uploadProgressAlert.dismiss(animated: true)
                                    }
                                }
                            },
                            onFailure: { error in
                                DispatchQueue.main.async {
                                    uploadProgressAlert.updateProgress(0.0, text: NSLocalizedString("upload.progress.failed", comment: ""))
                                    uploadProgressAlert.setActionButtonAsConfirm()
                                    uploadProgressAlert.onConfirm = {
                                        uploadProgressAlert.dismiss(animated: true)
                                    }
                                }
                            }
                        )
                    }
                } else {
                    self?.showToastWithMessage(NSLocalizedString("device.error.audio_file_not_found", comment: ""))
                }
            }
            self.present(self.progressAlert!, animated: true)
            
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let fileName = "\(bleFile.sessionId)_download"
            let desiredTargetPath = (documentsPath as NSString).appendingPathComponent(fileName)
            self.deviceAgent.downloadFile(sessionId: bleFile.sessionId, desiredOutputPath: desiredTargetPath)
        }
    }
    
    @objc private func covertAudioMp3(button _: UIButton) {
        // PLBleFileManager.shared.convertAllFilesToMp3()
    }
    
    @objc private func deleteFile(button _: UIButton) {
        guard !deviceAgent.checkIsRecording() else {
            showToastWithMessage(NSLocalizedString("device.error.cannot_delete_while_recording", comment: ""))
            return
        }
        
        let title = NSLocalizedString("device.dialog.file_count", comment: "").replacingOccurrences(of: "{count}", with: "\(recordList.count)")
        showRecordSelectDialog(title: title) { [weak self] bleFile in
            guard let `self` = self, let bleFile = bleFile else {
                return
            }
            self.deviceAgent.deleteFile(sessionId: bleFile.sessionId)
        }
    }
    
    private func syncFile() {
        guard !deviceAgent.checkIsRecording() else {
            showToastWithMessage(NSLocalizedString("device.error.recording_sync_only", comment: ""))
            return
        }
        
        guard recordList.count > 0 else {
            showToastWithMessage(NSLocalizedString("device.error.get_file_list_first", comment: ""))
            return
        }
        
        let title = NSLocalizedString("device.dialog.file_count", comment: "").replacingOccurrences(of: "{count}", with: "\(recordList.count)")
        showRecordSelectDialog(title: title) { [weak self] bleFile in
            guard let `self` = self, let bleFile = bleFile else {
                return
            }
            
            self.progressAlert = ProgressAlertController(title: NSLocalizedString("device.progress.downloading_stream", comment: ""))
            self.progressAlert?.onCancel = { [weak self] in
                self?.deviceAgent.stopSyncFile()
            }
            self.present(self.progressAlert!, animated: true)
            
            var size = self.getCurrentFileSize(sessionId: bleFile.sessionId)
            self.deviceAgent.syncFile(sessionId: bleFile.sessionId, start: 0, end: 0)
        }
    }
    
    private func showRecordSelectDialog(title: String, callback: @escaping (BleFile?) -> Void) {
        let optionController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        var idx = 0
        for bleFile in recordList {
            let title = NSLocalizedString("device.dialog.file_item", comment: "")
                .replacingOccurrences(of: "{index}", with: "\(idx)")
                .replacingOccurrences(of: "{fileId}", with: "\(bleFile.sessionId)")
                .replacingOccurrences(of: "{size}", with: formatFileSize(bleFile.size))
            idx += 1
            
            let action = UIAlertAction(title: title, style: .default) { _ in
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
    
    private func showDownloadedSelectDialog(title: String, callback: @escaping (String, String) -> Void) {
        let optionController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        var idx = 0
        for (id, path) in downloadedFiles {
            let title = NSLocalizedString("device.dialog.downloaded_file_item", comment: "")
                .replacingOccurrences(of: "{index}", with: "\(idx)")
                .replacingOccurrences(of: "{fileId}", with: id)
                .replacingOccurrences(of: "{path}", with: path)
            idx += 1
            let action = UIAlertAction(title: title, style: .default) { _ in
                callback(id, path)
            }
            optionController.addAction(action)
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("common.cancel", comment: ""), style: .cancel) { _ in
            callback("", "")
        }
        optionController.addAction(cancelAction)
        
        present(optionController, animated: true, completion: nil)
    }
    
    // MARK: - Toast Methods
    
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
        toastLabel?.font = .systemFont(ofSize: 14) // Slightly smaller font for better readability
        toastLabel?.textAlignment = .center
        toastLabel?.numberOfLines = 0 // Allow unlimited lines
        toastLabel?.lineBreakMode = .byWordWrapping // Wrap by words for better readability
        toastLabel?.translatesAutoresizingMaskIntoConstraints = false
        toastView?.addSubview(toastLabel!)
        
        NSLayoutConstraint.activate([
            toastView!.centerXAnchor.constraint(equalTo: UIApplication.shared.keyWindow!.centerXAnchor),
            toastView!.centerYAnchor.constraint(equalTo: UIApplication.shared.keyWindow!.centerYAnchor),
            toastView!.widthAnchor.constraint(lessThanOrEqualToConstant: 320), // Increased from 280
            toastView!.leadingAnchor.constraint(greaterThanOrEqualTo: UIApplication.shared.keyWindow!.leadingAnchor, constant: 24), // Reduced margin from 40
            toastView!.trailingAnchor.constraint(lessThanOrEqualTo: UIApplication.shared.keyWindow!.trailingAnchor, constant: -24), // Reduced margin from 40
            
            toastLabel!.topAnchor.constraint(equalTo: toastView!.topAnchor, constant: 16), // Increased padding
            toastLabel!.leadingAnchor.constraint(equalTo: toastView!.leadingAnchor, constant: 20), // Increased padding
            toastLabel!.trailingAnchor.constraint(equalTo: toastView!.trailingAnchor, constant: -20), // Increased padding
            toastLabel!.bottomAnchor.constraint(equalTo: toastView!.bottomAnchor, constant: -16), // Increased padding
        ])
    }
    
    func showToastWithMessage(_ message: String) {
        guard !message.isEmpty else { return }
        
        // Optimize message for display
        let optimizedMessage = optimizeMessageForToast(message)
        
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
                    self.showNewToast(optimizedMessage)
                }
            } else {
                self.showNewToast(optimizedMessage)
            }
        }
    }
    
    /// Optimize message text for toast display
    private func optimizeMessageForToast(_ message: String) -> String {
        let maxLength = 120 // Maximum characters for optimal display
        
        // If message is short enough, return as is
        if message.count <= maxLength {
            return message
        }
        
        // For longer messages, try to find a good break point
        let truncated = String(message.prefix(maxLength))
        
        // Try to break at the last sentence or phrase
        if let lastPeriod = truncated.lastIndex(of: "."),
           truncated.distance(from: lastPeriod, to: truncated.endIndex) < 10 {
            return String(truncated[...lastPeriod])
        }
        
        // Try to break at the last comma
        if let lastComma = truncated.lastIndex(of: ","),
           truncated.distance(from: lastComma, to: truncated.endIndex) < 20 {
            return String(truncated[...lastComma])
        }
        
        // Try to break at the last space to avoid cutting words
        if let lastSpace = truncated.lastIndex(of: " "),
           truncated.distance(from: lastSpace, to: truncated.endIndex) < 15 {
            return String(truncated[..<lastSpace]) + "..."
        }
        
        // If no good break point, just truncate and add ellipsis
        return String(message.prefix(maxLength - 3)) + "..."
    }
    
    private func showNewToast(_ message: String) {
        toastLabel?.text = message
        
        // Calculate display duration based on text length
        let baseDisplayTime: TimeInterval = 2.0
        let extraTimePerCharacter: TimeInterval = 0.05
        let maxDisplayTime: TimeInterval = 6.0
        
        let textLength = message.count
        let calculatedDisplayTime = min(baseDisplayTime + TimeInterval(textLength) * extraTimePerCharacter, maxDisplayTime)
        
        // Show animation
        UIView.animate(withDuration: 0.25, animations: {
            self.toastView?.alpha = 1.0
        }) { _ in
            // Auto hide after calculated time
            self.perform(#selector(self.hideToast), with: nil, afterDelay: calculatedDisplayTime)
        }
    }
    
    @objc private func hideToast() {
        DispatchQueue.main.async { [weak self] in
            UIView.animate(withDuration: 0.25, animations: {
                self?.toastView?.alpha = 0.0
            })
        }
    }
    
    // MARK: - Navigation Bar Setup
    
    private func setupNavigationBarButtons() {
        // Set title
        let titleContainer = UIView()
        titleContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("device.info.title", comment: "")
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .black
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.addSubview(titleLabel)
        
        // Use auto layout constraints to ensure title is centered
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: titleContainer.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: titleContainer.trailingAnchor),
            titleContainer.widthAnchor.constraint(equalToConstant: 200),
            titleContainer.heightAnchor.constraint(equalToConstant: 44),
        ])
        
        navigationItem.titleView = titleContainer
        
        // Create vertical stack view
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .trailing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create disconnect button
        let disconnectButton = UIButton(type: .system)
        disconnectButton.setTitle(NSLocalizedString("device.action.disconnect", comment: ""), for: .normal)
        disconnectButton.setTitleColor(UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0), for: .normal)
        disconnectButton.titleLabel?.font = .systemFont(ofSize: 14)
        disconnectButton.addTarget(self, action: #selector(disconnectDeviceTapped), for: .touchUpInside)
        disconnectButton.contentHorizontalAlignment = .right
        
        // Create unbind button
        let unbindButton = UIButton(type: .system)
        unbindButton.setTitle(NSLocalizedString("device.action.unbind", comment: ""), for: .normal)
        unbindButton.setTitleColor(UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0), for: .normal)
        unbindButton.titleLabel?.font = .systemFont(ofSize: 14)
        unbindButton.addTarget(self, action: #selector(unbindDeviceTapped), for: .touchUpInside)
        unbindButton.contentHorizontalAlignment = .right
        
        // Add buttons to stack view
        stackView.addArrangedSubview(disconnectButton)
        stackView.addArrangedSubview(unbindButton)
        
        // Set button size constraints
        NSLayoutConstraint.activate([
            disconnectButton.heightAnchor.constraint(equalToConstant: 30),
            unbindButton.heightAnchor.constraint(equalToConstant: 30),
        ])
        
        // Create custom UIBarButtonItem
        let rightBarButton = UIBarButtonItem(customView: stackView)
        let spacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        spacer.width = -8 // Adjust right margin to make button closer to edge
        navigationItem.rightBarButtonItems = [spacer, rightBarButton]
    }
    
    // MARK: - Navigation Bar Actions
    
    @objc private func disconnectDeviceTapped() {
        let alert = UIAlertController(
            title: NSLocalizedString("device.dialog.disconnect.title", comment: ""),
            message: NSLocalizedString("device.dialog.disconnect.message", comment: ""),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("common.cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("common.confirm", comment: ""), style: .destructive) { [weak self] _ in
            self?.deviceAgent.disconnect()
            self?.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    @objc private func unbindDeviceTapped() {
        let alert = UIAlertController(
            title: NSLocalizedString("device.dialog.unbind.title", comment: ""),
            message: NSLocalizedString("device.dialog.unbind.message", comment: ""),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("common.cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("common.confirm", comment: ""), style: .destructive) { [weak self] _ in
            self?.deviceAgent.depair()
            self?.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Layout Management
    
    /// Update layout when warning visibility changes
    private func updateLayoutForWarningVisibility() {
        // Force layout recalculation
        view.setNeedsLayout()
        
        // Animate the layout change for smooth transition
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: { [weak self] in
            self?.view.layoutIfNeeded()
        }, completion: nil)
        
        // Ensure scroll view content size is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.scrollView.setNeedsLayout()
            self?.scrollView.layoutIfNeeded()
        }
    }
    
    // Add file size formatting method
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
    
    @objc private func udiskAccessSwitchChanged(_ sender: UISwitch) {
        // TODO: Handle USB disk access switch state change
        let isEnabled = sender.isOn
        
        deviceAgent.setUDiskMode(onOff: isEnabled)
        
        showToastWithMessage(NSLocalizedString("device.status.udisk_access_changed", comment: "").replacingOccurrences(of: "{status}", with: isEnabled ? NSLocalizedString("device.status.enabled", comment: "") : NSLocalizedString("device.status.disabled", comment: "")))
    }
    
    // New: Device name input dialog
    @objc private func showDeviceNameDialog(button _: UIButton) {
        let alert = UIAlertController(title: NSLocalizedString("device.dialog.device_name.title", comment: ""), message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = NSLocalizedString("device.dialog.device_name.placeholder", comment: "")
            textField.text = ""
        }
        
        let confirmAction = UIAlertAction(title: NSLocalizedString("common.confirm", comment: ""), style: .default) { [weak alert, weak self] _ in
            let userName = alert?.textFields?.first?.text ?? ""
            if !userName.isEmpty {
                self?.deviceAgent.setDeviceName(userName)
            } else {
                self?.showToastWithMessage(NSLocalizedString("device.dialog.device_name.empty_error", comment: ""))
            }
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("common.cancel", comment: ""), style: .cancel)
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
    
    // New: Associate user popup
    private func showAssociateUserDialog() {
        let alert = UIAlertController(title: NSLocalizedString("device.dialog.associate_user.title", comment: ""), message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = NSLocalizedString("device.dialog.associate_user.placeholder", comment: "")
            textField.text = "plaud_sdk_ios"
        }
        
        let associateAction = UIAlertAction(title: NSLocalizedString("device.dialog.associate_user.associate", comment: ""), style: .default) { [weak alert, weak self] _ in
            let userId = alert?.textFields?.first?.text ?? ""
            
            PlaudFileUploader.shared.bindDevice(ownerId: userId, sn: self?.device.serialNumber ?? "") { result in
                DispatchQueue.main.async {
                    switch result {
                    case let .success(str):
                        self?.showToastWithMessage(NSLocalizedString("device.dialog.associate_user.associate_success", comment: ""))
                    case let .failure(error):
                        self?.showToastWithMessage(NSLocalizedString("device.dialog.associate_user.associate_fail", comment: "") + " " + ((error as? NSError)?.userInfo.description ?? ""))
                    }
                }
            }
        }
        
        let dissociateAction = UIAlertAction(title: NSLocalizedString("device.dialog.associate_user.dissociate", comment: ""), style: .destructive) { [weak alert, weak self] _ in
            let userId = alert?.textFields?.first?.text ?? ""
            
            PlaudFileUploader.shared.unbindDevice(ownerId: userId, sn: self?.device.serialNumber ?? "") { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.showToastWithMessage(NSLocalizedString("device.dialog.associate_user.dissociate_success", comment: ""))
                    case let .failure(error):
                        self?.showToastWithMessage(NSLocalizedString("device.dialog.associate_user.dissociate_fail", comment: "") + " " + ((error as? NSError)?.userInfo.description ?? ""))
                    }
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("common.cancel", comment: ""), style: .cancel)
        alert.addAction(associateAction)
        alert.addAction(dissociateAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
    
    // MARK: - Firmware Update
    
    /// Firmware installation validation result
    private struct FirmwareValidationResult {
        let isValid: Bool
        let errorMessage: String
    }
    
    /// Validate conditions required for firmware installation
    /// - Returns: Validation result with success flag and error message
    private func validateFirmwareInstallationConditions() -> FirmwareValidationResult {
        debugPrint("[DeviceInfo] Validating firmware installation conditions")
        
        // 1. Check battery level (must be higher than 40%)
        let batteryLevel = device.power
        debugPrint("[DeviceInfo] Battery level: \(batteryLevel)%")
        if batteryLevel < 40 {
            let message = String(format: "Battery level too low (%d%%). Please charge to at least 40%% before updating firmware.", batteryLevel)
            debugPrint("[DeviceInfo] ❌ Battery level too low: \(batteryLevel)%")
            return FirmwareValidationResult(isValid: false, errorMessage: message)
        }
        
        // 2. Check if device is in U-disk mode
        let isInUDiskMode = device.uDisk == 1
        debugPrint("[DeviceInfo] U-disk mode: \(isInUDiskMode)")
        if isInUDiskMode {
            let message = "Cannot update firmware while device is in U-disk mode. Please disable U-disk mode first."
            debugPrint("[DeviceInfo] ❌ Device is in U-disk mode")
            return FirmwareValidationResult(isValid: false, errorMessage: message)
        }
        
        // 3. Check if device is recording
        let isRecording = deviceAgent.checkIsRecording()
        debugPrint("[DeviceInfo] Is recording: \(isRecording)")
        if isRecording {
            let message = "Cannot update firmware while device is recording. Please stop recording first."
            debugPrint("[DeviceInfo] ❌ Device is currently recording")
            return FirmwareValidationResult(isValid: false, errorMessage: message)
        }
        
        // 4. Check if device is syncing files
        let isSyncing = deviceAgent.checkIsDownloading()
        debugPrint("[DeviceInfo] Is syncing: \(isSyncing)")
        if isSyncing {
            let message = "Cannot update firmware while device is syncing files. Please wait for sync to complete."
            debugPrint("[DeviceInfo] ❌ Device is currently syncing files")
            return FirmwareValidationResult(isValid: false, errorMessage: message)
        }
        
        debugPrint("[DeviceInfo] ✅ All firmware installation conditions are met")
        return FirmwareValidationResult(isValid: true, errorMessage: "")
    }
    
    @objc private func firmwareUpdateButtonTapped() {
        checkForFirmwareUpdate()
    }
    
    private func checkForFirmwareUpdate() {
        // Show checking update status
        firmwareInfoView.setUpdateButtonTitle(NSLocalizedString("device.status.checking_update", comment: ""))
        firmwareInfoView.setUpdateButtonEnabled(false)
        firmwareInfoView.setUpdateButtonLoading(true)
        
        let model = String(device.projectCode)
        let snType = PlaudFileUploader.calculateSnType(sn: device.serialNumber)
        
        let versionType = "V"
        
        //        #if DEBUG
        //        #if DISABLE_CUSTOM_DOMAIN
        //        #else
        //        versionType = "T"
        //        #endif
        //        #endif
        
        // Use checkLatestVersion to only check for updates, not download
        PlaudDeviceAgent.shared.checkLatestVersion(model: model, snType: snType, versionType: versionType) { [weak self] status in
            DispatchQueue.main.async {
                self?.handleUpdateCheckResult(status)
            }
        }
    }
    
    private func handleUpdateCheckResult(_ status: UpdateStatus) {
        // Restore button status
        firmwareInfoView.setUpdateButtonTitle(NSLocalizedString("device.action.check_update", comment: ""))
        firmwareInfoView.setUpdateButtonEnabled(true)
        firmwareInfoView.setUpdateButtonLoading(false)
        
        switch status {
        case .checking:
            // Checking status is already displayed on UI
            break
            
        case .available(let versionInfo):
            showUpdateAvailableDialog(versionInfo: versionInfo)
            
        case .notAvailable:
            showToastWithMessage(NSLocalizedString("device.update.no_update_available", comment: ""))
            
        case .downloading(let progress):
            // This should not directly go to download state, but handle for completeness
            let progressPercent = Int(progress * 100)
            let progressMessage = String(format: NSLocalizedString("device.update.downloading_progress", comment: ""), progressPercent)
            showToastWithMessage(progressMessage)
            
        case .downloaded(let localPath):
            // This should not occur when only checking for updates
            debugPrint("[DeviceInfo] ⚠️ Unexpected .downloaded status in update check result")
            showToastWithMessage(NSLocalizedString("device.update.unexpected_downloaded_state", comment: ""))
            
        case .failed(let error):
            showToastWithMessage(NSLocalizedString("device.update.check_failed", comment: "") + ": \(error.localizedDescription)")
        }
    }
    
    private func showUpdateAvailableDialog(versionInfo: LatestVersionResponse) {
        let title = NSLocalizedString("device.update.available_title", comment: "")
        let message = String(format: NSLocalizedString("device.update.available_message", comment: ""),
                             versionInfo.version_number,
                             versionInfo.version_description)
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let downloadAction = UIAlertAction(title: NSLocalizedString("device.update.download", comment: ""), style: .default) { [weak self] _ in
            self?.startFirmwareDownload(versionInfo: versionInfo)
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("common.cancel", comment: ""), style: .cancel)
        
        alert.addAction(downloadAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
    
    private func startFirmwareDownload(versionInfo: LatestVersionResponse) {
        // Show initial download message
        showToastWithMessage(NSLocalizedString("device.update.downloading", comment: ""))
        
        // Track last progress to avoid too frequent updates
        var lastProgressPercent = -1
        firmwareInfoView.setUpdateButtonEnabled(false)
        firmwareInfoView.setUpdateButtonLoading(true)
        firmwareInfoView.setUpdateStatus(prefix: NSLocalizedString("device.status.downloading", comment: ""))
        
        // Start download
        PlaudDeviceAgent.shared.downloadUpdate(versionInfo: versionInfo) { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .downloading(let progress):
                    let progressPercent = Int(progress * 100)
                    
                    debugPrint("[DeviceInfo] downloading firmware progress \(progressPercent)%")
                    
                    // Show toast every 1% progress or at 100%
                    if progressPercent > lastProgressPercent {
                        lastProgressPercent = progressPercent
                        let progressMessage = String(format: NSLocalizedString("device.update.downloading_progress", comment: ""), progressPercent)
                        //self?.showToastWithMessage(progressMessage)
                        self?.firmwareInfoView.setUpdateProgress(percent: progressPercent)
                    }
                    
                case .downloaded(let localPath):
                    self?.showToastWithMessage(NSLocalizedString("device.update.download_complete", comment: ""))
                    self?.firmwareInfoView.setUpdateButtonLoading(false)
                    self?.firmwareInfoView.setUpdateButtonEnabled(true)
                    self?.firmwareInfoView.setUpdateButtonTitle(NSLocalizedString("device.update.install", comment: ""))
                    // Wait a moment before showing the install dialog
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.showUpdateDownloadedDialog(localPath: localPath, versionInfo: versionInfo)
                    }
                    
                case .failed(let error):
                    // Use SDK bundle localized string to avoid missing key display
                    let prefix = "device.update.download_failed".plaudLocalized
                    self?.showToastWithMessage("\(prefix): \(error.localizedDescription)")
                    self?.firmwareInfoView.setUpdateButtonLoading(false)
                    self?.firmwareInfoView.setUpdateButtonEnabled(true)
                    self?.firmwareInfoView.setUpdateButtonTitle(NSLocalizedString("device.action.check_update", comment: ""))
                    
                default:
                    break
                }
            }
        }
    }
    
    private func showUpdateDownloadedDialog(localPath: String, versionInfo: LatestVersionResponse) {
        let title = NSLocalizedString("device.update.ready_title", comment: "")
        let message = NSLocalizedString("device.update.ready_message", comment: "")
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let installAction = UIAlertAction(title: NSLocalizedString("device.update.install", comment: ""), style: .default) { [weak self] _ in
            self?.installFirmwareUpdate(localPath: localPath, versionInfo: versionInfo)
        }
        
        let laterAction = UIAlertAction(title: NSLocalizedString("device.update.install_later", comment: ""), style: .cancel)
        
        alert.addAction(installAction)
        alert.addAction(laterAction)
        present(alert, animated: true)
    }
    
    private func installFirmwareUpdate(localPath: String, versionInfo: LatestVersionResponse) {
        // Construct target version string
        let toVersion = "\(versionInfo.version_code)"
        
        debugPrint("[DeviceInfo] Installing firmware update")
        debugPrint("[DeviceInfo] Local path: \(localPath)")
        debugPrint("[DeviceInfo] Target version: \(toVersion)")
        debugPrint("[DeviceInfo] Version info: \(versionInfo)")
        
        // Validate firmware installation conditions     before proceeding
        let validationResult = validateFirmwareInstallationConditions()
        if !validationResult.isValid {
            showToastWithMessage(validationResult.errorMessage)
            return
        }
        
        // Show installation progress dialog
        let installProgressAlert = ProgressAlertController(title: "Installing Firmware")
        
        // Hide upload button for firmware installation
        installProgressAlert.hideUploadButton()
        
        // Set initial progress
        installProgressAlert.updateProgress(0.0, text: "Preparing installation...")
        
        installProgressAlert.onCancel = { [weak self] in
            
            PlaudDeviceAgent.shared.cancelFirmwareInstallation()
            
            // Reset firmware info view state
            self?.firmwareInfoView.setUpdateButtonLoading(false)
            self?.firmwareInfoView.setUpdateButtonEnabled(true)
            self?.firmwareInfoView.setUpdateButtonTitle("Check for Update")
            
            // Note: ProgressAlertController already calls dismiss() before this callback
        }
        present(installProgressAlert, animated: true)
        
        // Show initial toast instructions
        //showToastWithMessage("Installing firmware update. Please keep device connected.")
        firmwareInfoView.setUpdateButtonEnabled(false)
        firmwareInfoView.setUpdateButtonLoading(true)
        firmwareInfoView.setUpdateStatus(prefix: "Installing")
        
        // Use the backward compatible firmware installation method with progress callback
        PlaudDeviceAgent.shared.installFirmwareUpdate(
            path: localPath,
            toVersion: toVersion,
            device: device,
            progressCallback: { [weak self] progress in
                DispatchQueue.main.async {
                    // Update installation progress dialog
                    let progressText = String(format: "Installing firmware... %d%%", progress)
                    
                    // Update the progress alert dialog
                    if let progressAlert = self?.presentedViewController as? ProgressAlertController {
                        progressAlert.updateProgress(Float(progress) / 100.0, text: progressText)
                    }
                    
                    // Also update firmware info view progress
                    self?.firmwareInfoView.setUpdateProgress(percent: progress, prefix: "Installing")
                    
                    // Show toast for major progress milestones
                    if progress % 25 == 0 && progress > 0 {
                        //self?.showToastWithMessage(progressText)
                    }
                }
            },
            completion: { [weak self] success, errorMessage in
                DispatchQueue.main.async {
                    // Dismiss the progress dialog
                    if let progressAlert = self?.presentedViewController as? ProgressAlertController {
                        progressAlert.dismiss(animated: true)
                    }
                    
                    if success {
                        self?.showToastWithMessage("Firmware installation completed successfully")
                        self?.firmwareInfoView.setUpdateButtonLoading(false)
                        self?.firmwareInfoView.setUpdateButtonEnabled(true)
                        self?.firmwareInfoView.setUpdateButtonTitle(NSLocalizedString("device.action.check_update", comment: ""))
                    } else {
                        let errorMsg = errorMessage ?? "Unknown error"
                        let formattedMessage = "Firmware installation failed: \(errorMsg)"
                        self?.showToastWithMessage(formattedMessage)
                        self?.firmwareInfoView.setUpdateButtonLoading(false)
                        self?.firmwareInfoView.setUpdateButtonEnabled(true)
                        self?.firmwareInfoView.setUpdateButtonTitle(NSLocalizedString("device.action.check_update", comment: ""))
                    }
                }
            }
        )
        
    }
    
    private func showDownloadProgress(_ progress: Float) {
        let progressPercent = Int(progress * 100)
        
        // Update button text to show download progress
        let progressText = String(format: "%.1f%%", progress * 100)
        firmwareInfoView.setUpdateButtonTitle(progressText)
        
        // Also show toast for significant progress updates
        if progressPercent % 20 == 0 || progressPercent == 100 {
            let progressMessage = String(format: NSLocalizedString("device.update.downloading_progress", comment: ""), progressPercent)
            //showToastWithMessage(progressMessage)
        }
    }
}

// MARK: - InfoItemView

class InfoItemView: UIView {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    
    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setupUI()
    }
    
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(titleLabel)
        addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    func setValue(_ value: String) {
        valueLabel.text = value
    }
}

// MARK: - FirmwareInfoView

class FirmwareInfoView: UIView {
    var onUpdateButtonTapped: (() -> Void)?
    private var statusPrefix: String = ""
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    
    private let updateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("device.action.check_update", comment: ""), for: .normal)
        button.setTitleColor(UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        button.contentHorizontalAlignment = .right
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.lineBreakMode = .byTruncatingHead
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        return button
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        indicator.transform = CGAffineTransform(scaleX: 1.35, y: 1.35)
        indicator.hidesWhenStopped = true
        indicator.isHidden = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.layer.shadowColor = UIColor.black.withAlphaComponent(0.12).cgColor
        indicator.layer.shadowOpacity = 1.0
        indicator.layer.shadowRadius = 1.5
        indicator.layer.shadowOffset = CGSize(width: 0, height: 1)
        return indicator
    }()
    
    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setupUI()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(updateButton)
        
        ///updateButton.isHidden = true
        
        // Place the activity indicator inside the button so it sits close to the title text
        updateButton.addSubview(activityIndicator)
        
        // Ensure the button text never gets truncated by the value label
        updateButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        updateButton.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        updateButton.addTarget(self, action: #selector(updateButtonTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            // Title label at the top
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: updateButton.leadingAnchor, constant: -8),
            
            // Value label below title
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.trailingAnchor.constraint(lessThanOrEqualTo: updateButton.leadingAnchor, constant: -8),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Update button aligned with value label
            updateButton.centerYAnchor.constraint(equalTo: valueLabel.centerYAnchor),
            updateButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            updateButton.heightAnchor.constraint(equalToConstant: 24),
            updateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])
        
        // Pin the indicator to the left of the button title to avoid excessive spacing
        if let titleLabel = updateButton.titleLabel {
            NSLayoutConstraint.activate([
                activityIndicator.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
                activityIndicator.trailingAnchor.constraint(equalTo: titleLabel.leadingAnchor, constant: -6)
            ])
        } else {
            NSLayoutConstraint.activate([
                activityIndicator.centerYAnchor.constraint(equalTo: updateButton.centerYAnchor),
                activityIndicator.trailingAnchor.constraint(equalTo: updateButton.leadingAnchor, constant: -6)
            ])
        }
    }
    
    @objc private func updateButtonTapped() {
        onUpdateButtonTapped?()
    }
    
    func setValue(_ value: String) {
        valueLabel.text = value
    }
    
    func setUpdateButtonTitle(_ title: String) {
        updateButton.setTitle(title, for: .normal)
    }
    
    func setUpdateButtonEnabled(_ enabled: Bool) {
        updateButton.isEnabled = enabled
    }
    
    func setUpdateButtonLoading(_ loading: Bool) {
        if loading {
            activityIndicator.isHidden = false
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }
    
    func setUpdateStatus(prefix: String) {
        statusPrefix = prefix
        updateButton.setTitle(prefix, for: .normal)
    }
    
    func setUpdateProgress(percent: Int, prefix: String? = nil) {
        let clamped = max(0, min(100, percent))
        let textPrefix = (prefix ?? statusPrefix)
        let title = textPrefix.isEmpty ? String(format: "%d%%", clamped) : String(format: "%@ %d%%", textPrefix, clamped)
        updateButton.setTitle(title, for: .normal)
        pulseUpdateButton()
    }
    
    private func pulseUpdateButton() {
        UIView.animate(withDuration: 0.08, animations: {
            self.updateButton.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }) { _ in
            UIView.animate(withDuration: 0.08) {
                self.updateButton.transform = .identity
            }
        }
    }
}

extension DeviceInfoViewController: PlaudDeviceAgentProtocol {
    func bleMicGain(_: Int) {}
    
    func bleDepair(_ status: Int) {
        // Parameter status: 0 success; 1 working; 2 upgrading
        if status == 0 {
            showToastWithMessage(NSLocalizedString("device.status.unbind_success", comment: ""))
        }
        
        if status == 2 {
            showToastWithMessage(NSLocalizedString("device.error.unbind_failed_working", comment: ""))
        }
        
        if status == 2 {
            showToastWithMessage(NSLocalizedString("device.error.unbind_failed_upgrading", comment: ""))
        }
    }
    
    func bleDownloadFileStop() {}
    
    func bleDownloadFile(sessionId: Int, desiredOutputPath: String, status: Int, progress: Int, tips: String) {
        debugPrint("DeviceInfoViewController - bleDownloadFile sessionId=\(sessionId) outputPath=\(desiredOutputPath) status=\(status) progress=\(progress) tips=\(tips)")
        
        if progress == 100 {
            downloadedFiles["\(sessionId)"] = desiredOutputPath
        }
        
        // Update progress bar
        DispatchQueue.main.async { [weak self] in
            self?.progressAlert?.updateProgress(Float(progress) / 100.0, text: tips)
            if progress == 100 {
                self?.progressAlert?.setCancelButtonTitle(NSLocalizedString("device.action.view", comment: ""))
                self?.progressAlert?.onCancel = { [weak self] in
                    if PlaudFileUploader.shared.checkRecordingExist(sessionId: sessionId) {
                        let vc = PlaudAudioPlayerViewController(sessionId: sessionId)
                        self?.navigationController?.pushViewController(vc, animated: true)
                    } else {
                        self?.showToastWithMessage(NSLocalizedString("device.error.audio_file_not_found", comment: ""))
                    }
                }
            }
        }
    }
    
    func bleSyncFileHead(sessionId: Int, status: Int) {
        debugPrint("DeviceInfoViewController - bleSyncFileHead  sessionId=\(sessionId) status=\(status)")
    }
    
    func bleSyncFileTail(sessionId: Int, crc: Int) {
        debugPrint("DeviceInfoViewController - bleSyncFileTail: sessionId=\(sessionId), crc=\(crc)")
        
        downlodingFileInfo = nil
        
        // Get documents directory path
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let fileName = "\(sessionId).dat"
        
        // Use BleFileManager to save data
        PLBleFileManager.shared.closeFile(filePath: documentsPath, fileName: fileName)
    }
    
    private func getCurrentFileSize(sessionId: Int) -> Int {
        if let downlodingFileInfo = downlodingFileInfo {
            return downlodingFileInfo.size
        }
        
        for file in recordList {
            if file.sessionId == sessionId {
                downlodingFileInfo = file
                return file.size
            }
        }
        
        return -1
    }
    
    func bleData(sessionId: Int, start: Int, data: Data) {
        debugPrint("DeviceInfoViewController - bleData: sessionId=\(sessionId), start=\(start), dataSize=\(data.count)")
        
        if let downloading = downlodingFileInfo {
            // Update progress bar
            let size = getCurrentFileSize(sessionId: sessionId)
            let ratio = Float(start + data.count) * 100.0 / Float(size)
            DispatchQueue.main.async { [weak self] in
                var tip = NSLocalizedString("device.status.downloading", comment: "")
                if Int(ratio) == 100 {
                    tip = NSLocalizedString("device.status.download_complete", comment: "")
                }
                self?.progressAlert?.updateProgress(ratio / 100.0, text: tip)
                self?.updatePopBtnClk(progress: Int(ratio))
            }
        }
        
        // Get documents directory path
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let fileName = "\(sessionId).dat"
        
        // Use BleFileManager to save data
        PLBleFileManager.shared.saveBleFile(
            filePath: documentsPath,
            fileName: fileName,
            start: start,
            data: data
        )
    }
    
    func updatePopBtnClk(progress: Int) {
        if progress == 100 {
            progressAlert?.setCancelButtonTitle(NSLocalizedString("device.action.transcode", comment: ""))
            progressAlert?.onCancel = { [weak self] in
            }
        }
    }
    
    func blePcmData(sessionId: Int, millsec: Int, pcmData: Data, isMusic: Bool) {
        debugPrint("DeviceInfoViewController - blePcmData: sessionId=\(sessionId), millsec=\(millsec), dataSize=\(pcmData.count), isMusic=\(isMusic)")
    }
    
    func bleDecodeFail(start: Int) {
        debugPrint("DeviceInfoViewController - bleDecodeFail: start=\(start)")
    }
    
    func bleSyncFileStop() {
        downlodingFileInfo = nil
        debugPrint("DeviceInfoViewController - bleSyncFileStop")
    }
    
    func bleRecordStop(sessionId: Int, reason: Int, fileExist: Bool, fileSize: Int) {
        debugPrint("DeviceInfoViewController - bleRecordStop: sessionId=\(sessionId), reason=\(reason), fileExist=\(fileExist), fileSize=\(fileSize)")
        ///      1.MMI_REC_STOP_FROM_DEV    /// Device-side stop recording
        ///      2.MMI_REC_STOP_FROM_APP    /// App-side stop recording
        ///      3.MMI_REC_STOP_BY_SPLIT        /// Auto-time slice stop recording
        ///      4.MMI_REC_STOP_BY_SWITCH   ///  Switch toggle stop recording
        let reasonStr = NSLocalizedString("device.status.record_stop_reason.\(reason)", comment: "")
        showToastWithMessage(NSLocalizedString("device.status.record_stopped", comment: "").replacingOccurrences(of: "{reason}", with: reasonStr))
    }
    
    func bleRecordPause(sessionId: Int, reason: Int, fileExist: Bool, fileSize: Int) {
        debugPrint("DeviceInfoViewController - bleRecordPause: sessionId=\(sessionId), reason=\(reason), fileExist=\(fileExist), fileSize=\(fileSize)")
        showToastWithMessage(NSLocalizedString("device.status.record_paused", comment: ""))
    }
    
    func bleRecordResume(sessionId: Int, start: Int, status: Int, scene: Int, startTime: Int) {
        debugPrint("DeviceInfoViewController - bleRecordResume: sessionId=\(sessionId), start=\(start), status=\(status), scene=\(scene), startTime=\(startTime)")
        showToastWithMessage(NSLocalizedString("device.status.record_resumed", comment: ""))
    }
    
    func bleStopRecord(status: Int) {
        debugPrint("DeviceInfoViewController - bleStopRecord: status=\(status)")
    }
    
    func blePenState(state: Int, privacy: Int, keyState: Int, uDisk: Int, findMyToken: Int, hasSndpKey: Int, deviceAccessToken: Int) {
        debugPrint("DeviceInfoViewController - blePenState: state=\(state), privacy=\(privacy), keyState=\(keyState), uDisk=\(uDisk), findMyToken=\(findMyToken), hasSndpKey=\(hasSndpKey), deviceAccessToken=\(deviceAccessToken)")
        
        // Update switch state
        udiskAccessSwitch.isOn = privacy == 0
        
        // Control USB disk mode warning display
        let shouldShowWarning = uDisk == 1
        let wasHidden = udiskModeWarningLabel.isHidden
        udiskModeWarningLabel.isHidden = !shouldShowWarning
        
        // Force layout update when warning visibility changes
        if wasHidden != udiskModeWarningLabel.isHidden {
            DispatchQueue.main.async { [weak self] in
                self?.updateLayoutForWarningVisibility()
            }
        }
    }
    
    func bleRecordStart(sessionId: Int, start: Int, status: Int, scene: Int, startTime: Int, reason: Int) {
        debugPrint("DeviceInfoViewController - bleRecordStart: sessionId=\(sessionId), start=\(start), status=\(status), scene=\(scene), startTime=\(startTime)")
        
        let reasonStr = NSLocalizedString("device.status.record_start_reason.\(reason)", comment: "")
        
        showToastWithMessage(NSLocalizedString("device.status.record_started", comment: "").replacingOccurrences(of: "{id}", with: "\(sessionId)") + " " + reasonStr)
    }
    
    func onCommonMsgChannel(type _: Int, value _: Int, tips: String) {
        showToastWithMessage(tips)
    }
    
    func bleScanResult(bleDevices: [PenBleSDK.BleDevice]) {
        debugPrint("DeviceInfoViewController - bleScanResult: devices=\(bleDevices)")
    }
    
    func bleScanOverTime() {
        debugPrint("DeviceInfoViewController - bleScanOverTime")
    }
    
    func bleConnectState(state: Int) {
        debugPrint("DeviceInfoViewController - bleConnectState: state=\(state)")
        
        // For unbound devices, bleConnectState returns 1 first, then 0, popup first
        if state == 0  && !wifiOpening  && PlaudDeviceAgent.shared.delegate is DeviceInfoViewController == true {
            if let topViewController = navigationController?.topViewController, topViewController is DeviceInfoViewController {
                showToastWithMessage(NSLocalizedString("device.error.connection_failed", comment: ""))
                navigationController?.popViewController(animated: true)
            }
        }
    }
    
    func bleBind(sn: String?, status: Int, protVersion: Int, timezone: Int) {
        debugPrint("DeviceInfoViewController - bleBind: sn=\(sn ?? "nil"), status=\(status), protVersion=\(protVersion), timezone=\(timezone)")
        
        if status == 0 {
            showToastWithMessage(NSLocalizedString("device.status.connection_success", comment: ""))
        } else {
            showToastWithMessage(NSLocalizedString("device.error.connection_failed", comment: ""))
        }
    }
    
    func bleStorage(total: Int, free: Int, duration: Int) {
        debugPrint("DeviceInfoViewController - bleStorage: total=\(total), free=\(free), duration=\(duration)")
        
        //        let totalMB = Double(total) / (1024 * 1024 * 1024)
        //        let freeMB = Double(free) /  (1024 * 1024 * 1024)
        let totalMB = Double(total) / (1000 * 1000 * 1000)
        let freeMB = Double(free) / (1000 * 1000 * 1000)
        storageLabel.setValue(String(format: "%.2f GB / %.2f GB", freeMB, totalMB))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.deviceAgent.getFileList(startSessionId: 0)
        }
    }
    
    func blePowerChange(power: Int, oldPower: Int) {
        debugPrint("DeviceInfoViewController - blePowerChange: power=\(power), oldPower=\(oldPower)")
        // showToastWithMessage("blePowerChange")
    }
    
    func bleChargingState(isCharging: Bool, level: Int) {
        debugPrint("DeviceInfoViewController - bleChargingState: isCharging=\(isCharging), level=\(level)")
        
        let charging = isCharging ?
        NSLocalizedString("device.status.charging", comment: "") :
        NSLocalizedString("device.status.not_charging", comment: "")
        
        batteryLabel.setValue("\(level)% - \(charging)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.deviceAgent.getStorage()
        }
    }
    
    func bleFileList(bleFiles: [BleFile]) {
        debugPrint("DeviceInfoViewController - bleFileList: count=\(bleFiles.count)")
        recordList.removeAll()
        recordList.append(contentsOf: bleFiles)
        
        if manualGet {
            showToastWithMessage(NSLocalizedString("device.status.file_list_success", comment: "").replacingOccurrences(of: "{count}", with: "\(bleFiles.count)"))
            manualGet = false
        }
    }
    
    func bleDataComplete() {
        debugPrint("DeviceInfoViewController - bleDataComplete")
        downlodingFileInfo = nil
        
        PLBleFileManager.shared.closeAllFiles()
        PLBleFileManager.shared.convertAllFilesToPcm()
        
        //        // Get documents directory path
        //        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        //        let fileName = "\(sessionId).dat"
        //
        //        // Use BleFileManager to save data
        //        BleFileManager.shared.saveBleFile(
        //            filePath: documentsPath,
        //            fileName: fileName,
        //            start: start,
        //            data: data
        //        )
    }
    
    func bleSyncFileHead(sessionId: Int, size: Int, start: Int, end: Int) {
        debugPrint("DeviceInfoViewController - bleSyncFileHead: sessionId=\(sessionId), size=\(size), start=\(start), end=\(end)")
    }
    
    func bleSyncFileData(sessionId: Int, data: Data, offset: Int) {
        debugPrint("DeviceInfoViewController - bleSyncFileData: sessionId=\(sessionId), dataSize=\(data.count), offset=\(offset)")
    }
    
    //    func bleSyncFileComplete(sessionId: Int, status: Int) {
    //        debugPrint("DeviceInfoViewController - bleSyncFileComplete: sessionId=\(sessionId), status=\(status)")
    //    }
    //
    //    func bleSyncFileError(sessionId: Int, error: Int) {
    //        debugPrint("DeviceInfoViewController - bleSyncFileError: sessionId=\(sessionId), error=\(error)")
    //    }
    
    func bleDeleteFile(sessionId: Int, status: Int) {
        debugPrint("DeviceInfoViewController - bleDeleteFile: sessionId=\(sessionId), status=\(status)")
        
        ///   - sessionId: Protocol version 7 support
        ///   - status: Status, 0: Delete success; 1: Recording in progress, deletion not allowed; 2: Favorited, deletion not allowed; 3: Playing, deletion not allowed
        ///
        ///
        var reasonStr = ""
        if status == 0 {
            reasonStr = NSLocalizedString("device.delete.success", comment: "")
        } else if status == 1 {
            reasonStr = NSLocalizedString("device.delete.error.recording", comment: "")
        } else if status == 2 {
            reasonStr = NSLocalizedString("device.delete.error.favorite", comment: "")
        } else if status == 3 {
            reasonStr = NSLocalizedString("device.delete.error.playing", comment: "")
        }
        showToastWithMessage(reasonStr)
    }
    
    func bleClearAllFiles(status: Int) {
        debugPrint("DeviceInfoViewController - bleClearAllFiles: status=\(status)")
    }
    
    func bleStartRecord(status: Int) {
        debugPrint("DeviceInfoViewController - bleStartRecord: status=\(status)")
    }
    
    func blePauseRecord(status: Int) {
        debugPrint("DeviceInfoViewController - blePauseRecord: status=\(status)")
    }
    
    func bleResumeRecord(status: Int) {
        debugPrint("DeviceInfoViewController - bleResumeRecord: status=\(status)")
    }
    
    //------
    func bleWiFiOpen(_ status: Int, _ wifiName: String, _ wholeName: String, _ wifiPass: String) {
        if status == 0 {
            PlaudWiFiAgent.shared.bleDevice = BleAgent.shared.bleDevice
        }
        self.onWiFiOpen(status, wifiName, wholeName, wifiPass)
    }
    
    func onWiFiOpen(_ status: Int, _ wifiName: String, _ wholeName: String, _ wifiPass: String) {
        debugPrint("onWiFiOpen status:\(status)")
        switch status {
        case 0:
            // WiFi opened successfully, navigate to transfer page and connect
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.connectToWiFi(wifiName, wifiPass)
                self.navigateToWiFiTransferPage()
            }
        case 1:
            showToastWithMessage(NSLocalizedString("wifi.error.recording_in_progress", comment: ""))
            wifiOpening = false
        case 2:
            showToastWithMessage(NSLocalizedString("wifi.error.udisk_mode_active", comment: ""))
            wifiOpening = false
        default:
            wifiOpening = false
            break
        }
    }
    
    /// Connect to WiFi
    private func connectToWiFi(_ wifiName: String, _ wifiPass: String) {
        debugPrint("connectToWiFi name:\(wifiName), pass:\(wifiPass)")
        
        // Note: wifiOpening should be set to false in navigateToWiFiTransferPage after navigation completes
        
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
}

// MARK: - PlaudWiFiAgentProtocol
extension DeviceInfoViewController: PlaudWiFiAgentProtocol {
    func wifiCommonErr(_ cmd: Int, _ status: Int) {
        debugPrint("DeviceInfoViewController - wifiCommonErr cmd:\(cmd), status:\(status)")
    }
    
    func wifiHandshake(_ status: Int) {
        debugPrint("DeviceInfoViewController - wifiHandshake status:\(status)")
    }
    
    func wifiPower(_ power: Int, _ voltage: Int) {
        debugPrint("DeviceInfoViewController - wifiPower:\(power), voltage:\(voltage)")
    }
    
    func wifiFileListFail(_ status: Int) {
        debugPrint("DeviceInfoViewController - wifiFileListFail:\(status)")
    }
    
    func wifiFileList(_ files: [BleFile]) {
        debugPrint("DeviceInfoViewController - wifiFileList count:\(files.count)")
    }
    
    func wifiSyncFile(_ sessionId: Int, _ status: Int) {
        debugPrint("DeviceInfoViewController - wifiSyncFile:\(sessionId), status:\(status)")
    }
    
    func wifiSyncFileData(_ sessionId: Int, _ offset: Int, _ count: Int, _ binData: Data) {
        debugPrint("DeviceInfoViewController - wifiSyncFileData:\(sessionId), offset:\(offset), count:\(count)")
    }
    
    func wifiDataComplete() {
        debugPrint("DeviceInfoViewController - wifiDataComplete")
    }
    
    func wifiSyncFileStop(_ status: Int) {
        debugPrint("DeviceInfoViewController - wifiSyncFileStop:\(status)")
    }
    
    func wifiFileDelete(_ sessionId: Int, _ status: Int) {
        debugPrint("DeviceInfoViewController - wifiFileDelete:\(sessionId), status:\(status)")
    }
    
    func wifiClientFail() {
        debugPrint("DeviceInfoViewController - wifiClientFail")
    }
    
    func wifiClose(_ status: Int) {
        debugPrint("DeviceInfoViewController - wifiClose:\(status)")
        wifiOpening = false
    }
    
    func wifiRateFail(_ status: Int) {
        debugPrint("DeviceInfoViewController - wifiRateFail:\(status)")
    }
    
    func wifiRate(_ instantRate: Int, _ averageRate: Int, _ lossRate: Double) {
        debugPrint("DeviceInfoViewController - wifiRate instantRate:\(instantRate), averageRate:\(averageRate), lossRate:\(lossRate)")
    }
    
    func wifiLogsFail(_ status: Int) {
        debugPrint("DeviceInfoViewController - wifiLogsFail:\(status)")
    }
    
    func wifiLogs(_ logData: Data?) {
        debugPrint("DeviceInfoViewController - wifiLogs dataSize:\(logData?.count ?? 0)")
    }
    
    func wifiTips(_ tips: Int) {
        debugPrint("DeviceInfoViewController - wifiTips:\(tips)")
    }
    
    // New WiFi connection status callback
    func wifiConnectionStatus(_ ssid: String, _ connected: Bool) {
        debugPrint("DeviceInfoViewController - wifiConnectionStatus ssid:\(ssid), connected:\(connected)")
        
        DispatchQueue.main.async { [weak self] in
            if connected {
                let message = NSLocalizedString("wifi.connection.success", comment: "").replacingOccurrences(of: "{ssid}", with: ssid)
                self?.showToastWithMessage(message)
                self?.wifiOpening = false
                
                // WiFi connection successful - navigation should already be handled by onWiFiOpen
                // Just log the successful connection, don't navigate again
                debugPrint("WiFi connection successful, already navigated to transfer page")
            } else {
                let message = NSLocalizedString("wifi.connection.failed", comment: "").replacingOccurrences(of: "{ssid}", with: ssid)
                self?.showToastWithMessage(message)
                self?.wifiOpening = false
            }
        }
    }
}
