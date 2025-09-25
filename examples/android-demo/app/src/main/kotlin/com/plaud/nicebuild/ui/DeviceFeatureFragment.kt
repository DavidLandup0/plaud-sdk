package com.plaud.nicebuild.ui
import android.annotation.SuppressLint
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.activity.OnBackPressedCallback
import androidx.fragment.app.Fragment
import com.plaud.nicebuild.R
import com.google.android.material.button.MaterialButton
import android.widget.Toast
import androidx.lifecycle.ViewModelProvider
import com.plaud.nicebuild.viewmodel.MainViewModel
import android.widget.TextView
import com.plaud.nicebuild.ble.BleCore
import com.plaud.nicebuild.ble.BleManager
import sdk.penblesdk.entity.BleDevice
import androidx.navigation.fragment.findNavController
import androidx.core.content.ContextCompat
import org.json.JSONObject
import android.widget.ImageButton
import android.util.Log
import androidx.annotation.RequiresApi
import android.widget.LinearLayout
import android.os.Handler
import android.os.Looper
import sdk.penblesdk.Constants
import android.app.Dialog
import com.google.android.material.materialswitch.MaterialSwitch
import com.google.android.material.button.MaterialButton as MaterialButtonView
import sdk.penblesdk.TntAgent
import sdk.penblesdk.entity.bean.ble.response.FileDataCheckRsp
import sdk.penblesdk.entity.bean.ble.response.FileInfoSyncRsp
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine
import com.google.android.material.slider.Slider
import androidx.appcompat.widget.SwitchCompat
import android.widget.CompoundButton
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import sdk.NiceBuildSdk
import com.plaud.nicebuild.data.*
import com.plaud.nicebuild.manager.FirmwareUpdateManager
import com.plaud.nicebuild.ui.dialogs.FirmwareUpdateDialogs
import com.plaud.nicebuild.ui.dialogs.FirmwareUpdateProgressDialog
import com.google.android.material.appbar.MaterialToolbar
import android.content.Intent
import android.net.Uri
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import android.Manifest
import android.content.pm.PackageManager
import android.provider.Settings
import com.plaud.nicebuild.utils.PermissionUtils
import com.plaud.nicebuild.utils.WifiTransferPermissions
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.widget.Button

class DeviceFeatureFragment : Fragment() {
    private val TAG: String = "DeviceFeatureFragment"
    private lateinit var tvRecordStatus: TextView
    private lateinit var mainViewModel: MainViewModel
    private lateinit var bleManager: BleManager
    private lateinit var bleCore: BleCore
    private lateinit var currentdevice: BleDevice
    private var isRecording = false
    private var isPaused = false
    private var isExpanded = true
    private val timeoutHandler = Handler(Looper.getMainLooper())
    private var timeoutRunnable: Runnable? = null
    private var currentBatteryLevel: Int = 0

    // Views
    private lateinit var deviceInfoContent: View
    private lateinit var btnExpand: ImageButton
    private lateinit var tvSn: TextView
    private lateinit var tvFirmware: TextView
    private lateinit var tvBattery: TextView
    private lateinit var tvStorage: TextView
    private lateinit var layoutFileListEntry: View
    private lateinit var tvFileCountEntry: TextView
    private lateinit var deviceInfoTitleLayout: View
    private lateinit var layoutMicGain: View
    private lateinit var tvMicGainValue: TextView
    private lateinit var switchUdiskMode: SwitchCompat
    private lateinit var btnDisconnect: MaterialButton
    private lateinit var btnUnpair: MaterialButton
    private lateinit var btnRecordControl: MaterialButton
    private lateinit var btnPauseResume: MaterialButton
    private lateinit var btnGetState: MaterialButton
    private lateinit var btnGetFileList: MaterialButton
    private lateinit var btnSetWifiDomain: MaterialButton
    private lateinit var btnWifiCloud: MaterialButton
    private lateinit var btnWifiTransfer: MaterialButton
    private lateinit var btnBindCloud: MaterialButton
    private lateinit var btnUnbindCloud: MaterialButton
    private lateinit var btnCheckUpdate: MaterialButton
    private lateinit var btnTestCommonSettings: MaterialButton

    private var uDiskSwitchListener: CompoundButton.OnCheckedChangeListener? = null
    
    // 固件更新相关
    private lateinit var firmwareUpdateManager: FirmwareUpdateManager
    private var downloadProgressDialog: FirmwareUpdateProgressDialog? = null
    private var installProgressDialog: FirmwareUpdateProgressDialog? = null
    
    // Unified launcher for all permissions
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        // For legacy storage, check if they were granted
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            if (permissions.all { it.value }) {
                navigateToFileList()
            } else {
                Toast.makeText(requireContext(), getString(R.string.toast_storage_permission_required_to_save), Toast.LENGTH_LONG).show()
            }
        }
        // For modern storage, the check is handled in onResume after returning from settings
        // For WiFi permissions, the check is handled by PermissionUtils callback
    }

    // Launcher for modern storage settings (Android >= 11)
    private val requestManageStorageLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) {
        // The result is checked in onResume
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mainViewModel = ViewModelProvider(requireActivity()).get(MainViewModel::class.java)
        bleManager = BleManager.getInstance(requireContext())
        bleCore = BleCore.getInstance(requireContext())
        firmwareUpdateManager = FirmwareUpdateManager.getInstance(requireContext())
        // Handle physical back button
        requireActivity().onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                bleCore.disconnectDevice()
                mainViewModel.setCurrentDevice(null)
                findNavController().popBackStack()
            }
        })
        updateUiFromState(null)
    }

    @SuppressLint("MissingInflatedId")
    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?
    ): View? {
        val view = inflater.inflate(R.layout.fragment_device_feature, container, false)
        
        // Initialize views
        deviceInfoContent = view.findViewById(R.id.device_info_content)
        btnExpand = view.findViewById(R.id.btn_expand)
        deviceInfoTitleLayout = view.findViewById(R.id.device_info_title_layout)
        tvSn = view.findViewById(R.id.tv_sn)
        tvFirmware = view.findViewById(R.id.tv_firmware)
        btnCheckUpdate = view.findViewById(R.id.btn_check_update)
        tvBattery = view.findViewById(R.id.tv_battery)
        tvStorage = view.findViewById(R.id.tv_storage)
        tvRecordStatus = view.findViewById(R.id.tv_record_status)
        layoutFileListEntry = view.findViewById(R.id.layout_file_list_entry)
        tvFileCountEntry = view.findViewById(R.id.tv_file_count_entry)
        layoutMicGain = view.findViewById(R.id.layout_mic_gain)
        tvMicGainValue = view.findViewById(R.id.tv_mic_gain_value)
        switchUdiskMode = view.findViewById(R.id.switch_udisk_mode)
        
        // Initialize buttons
        btnDisconnect = view.findViewById(R.id.btn_disconnect)
        btnUnpair = view.findViewById(R.id.btn_unpair)
        btnRecordControl = view.findViewById(R.id.btn_record_control)
        btnPauseResume = view.findViewById(R.id.btn_pause_resume)
        btnGetState = view.findViewById(R.id.btn_get_state)
        btnGetFileList = view.findViewById(R.id.btn_get_file_list)
        btnSetWifiDomain = view.findViewById(R.id.btn_set_wifi_domain)
        btnWifiCloud = view.findViewById(R.id.btn_wifi_cloud)
        btnWifiTransfer = view.findViewById(R.id.btn_wifi_transfer)
        btnBindCloud = view.findViewById(R.id.btn_bind_cloud)
        btnUnbindCloud = view.findViewById(R.id.btn_unbind_cloud)
        btnTestCommonSettings = view.findViewById(R.id.btn_test_common_settings)
        
        return view
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Set status bar color
        activity?.window?.statusBarColor = ContextCompat.getColor(requireContext(), R.color.background_secondary)
        @Suppress("DEPRECATION")
        activity?.window?.decorView?.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR

        val toolbar = view.findViewById<MaterialToolbar>(R.id.toolbar)
        toolbar.setNavigationOnClickListener {
            activity?.onBackPressedDispatcher?.onBackPressed()
        }

        setupDeviceInfoCard()
        setupControls()
        loadDeviceInfo()
        observeViewModel()
    }

    private fun setupDeviceInfoCard() {
        // Create a reusable click listener
        val toggleClickListener = View.OnClickListener {
            isExpanded = !isExpanded
            deviceInfoContent.visibility = if (isExpanded) View.VISIBLE else View.GONE
            btnExpand.rotation = if (isExpanded) 0f else 180f
        }

        // Set listener to both title bar and button
        deviceInfoTitleLayout.setOnClickListener(toggleClickListener)
        btnExpand.setOnClickListener(toggleClickListener)

        // Set initial state
        isExpanded = true
        deviceInfoContent.visibility = View.VISIBLE
        btnExpand.rotation = 0f
    }

    private fun loadDeviceInfo() {
        // Set serial number
        mainViewModel.currentDevice.value?.let { device ->
            currentdevice = device
            tvSn.text = getString(R.string.fragment_device_feature_serial_label, device.serialNumber)
            val versionName = device.versionName ?: "--"
            tvFirmware.text = getString(R.string.fragment_device_feature_firmware_label, versionName)
        }

        // Get battery level
        bleCore.getBatteryState { batteryText ->
            requireActivity().runOnUiThread {
                tvBattery.text = getString(R.string.fragment_device_feature_battery_label, batteryText)
                Log.d(TAG, "Battery: $batteryText")
                
                try {
                    val regex = Regex("(\\d+)%")
                    val matchResult = regex.find(batteryText)
                    currentBatteryLevel = matchResult?.groupValues?.get(1)?.toInt() ?: 0
                    Log.d(TAG, "Parsed battery level: $currentBatteryLevel%")
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to parse battery level from: $batteryText", e)
                    currentBatteryLevel = 0
                }
            }
        }
        
        // Get storage space
        bleCore.getStorage(requireContext()) { storageText ->
            requireActivity().runOnUiThread {
                tvStorage.text = getString(R.string.fragment_device_feature_storage_label, storageText)
                Log.d(TAG, "Storage: $storageText")
            }
        }

        // Get file list
        bleCore.getFileList(0) { fileList ->
             if (fileList != null) {
                 mainViewModel.updateFileList(fileList)
             }
        }

        bleManager.getMICGain { gain ->
            activity?.runOnUiThread {
                tvMicGainValue.text = gain.toString()
            }
        }
    }

    private fun setupControls() {
        bleCore.setOnRecordingStateChangeListener { isRecording ->
            this.isRecording = isRecording
            if (!isRecording) {
                isPaused = false
            }
            requireActivity().runOnUiThread {
                updateButtonStates()
            }
        }

        btnDisconnect.setOnClickListener {
            bleCore.disconnectDevice()
            mainViewModel.setCurrentDevice(null)
            findNavController().popBackStack()
        }

        btnUnpair.setOnClickListener {
            bleManager.depairDevice { success ->
                requireActivity().runOnUiThread {
                    if (success) {
                        Toast.makeText(requireContext(), getString(R.string.toast_unbind_successful), Toast.LENGTH_SHORT).show()
                        mainViewModel.setCurrentDevice(null)
                        findNavController().popBackStack()
                    } else {
                        Toast.makeText(requireContext(), getString(R.string.toast_unbind_failed), Toast.LENGTH_SHORT).show()
                    }
                }
            }
        }

        btnRecordControl.setOnClickListener {
            if (isRecording) {
                bleManager.stopRecord { success ->
                    if (success) {
                        bleCore.getDeviceState { state ->
                            updateUiFromState(state)
                        }
                    }
                }
            } else {
                bleManager.startRecord { success ->
                    if (success) {
                        bleCore.getDeviceState { state ->
                            updateUiFromState(state)
                        }
                    }
                }
            }
        }

        btnPauseResume.setOnClickListener {
            val action: (((Boolean) -> Unit)) -> Unit = if (isPaused) {
                bleManager::resumeRecord
            } else {
                bleManager::pauseRecord
            }
            action { success ->
                if (success) {
                    // Refresh state without toast
                    bleCore.getDeviceState { state ->
                        updateUiFromState(state)
                    }
                }
            }
        }

        btnGetState.setOnClickListener {
            bleManager.getDeviceState { state ->
                requireActivity().runOnUiThread {
                    try {
                        val json = JSONObject(state)
                        val stateCode = json.getInt("state")
                        val isPaused = json.getBoolean("isPaused")
                        val sessionId = json.getLong("sessionId")

                        val stateText = when (stateCode.toLong()) {
                            Constants.DEVICE_STATUS_RECORD -> getString(R.string.device_status_idle)
                            Constants.DEVICE_STATUS_RECORDING -> getString(R.string.device_status_recording)
                            else -> getString(R.string.device_status_unknown, stateCode)
                        }

                        val formattedMessage = """
                            ${getString(R.string.dialog_status_label)}: $stateText
                            ${getString(R.string.dialog_paused_label)}: ${if (isPaused) getString(R.string.dialog_yes) else getString(R.string.dialog_no)}
                            ${getString(R.string.dialog_session_id_label)}: $sessionId
                        """.trimIndent()

                        showStatusDialog(formattedMessage)
                        

                    } catch (e: Exception) {
                        Toast.makeText(requireContext(), getString(R.string.toast_parse_state_failed, e.message), Toast.LENGTH_SHORT).show()
                    }
                    updateUiFromState(state)
                }
            }
        }

        btnGetFileList.setOnClickListener {
            bleCore.getFileList(0) { fileList ->
                 if (fileList != null) {
                     mainViewModel.updateFileList(fileList)
                 }
            }
        }

        layoutFileListEntry.setOnClickListener {
            checkAndRequestStoragePermission()
        }

        btnCheckUpdate.setOnClickListener {
            handleFirmwareUpdate()
        }

        btnSetWifiDomain.setOnClickListener {
            val domain = NiceBuildSdk.getWifiSyncDomain()
            bleManager.setWifiSyncDomain(domain) { success ->
                if (isAdded) { // Ensure fragment is still attached before updating UI
                    requireActivity().runOnUiThread {
                        if (success) {
                            Toast.makeText(
                                requireContext(),
                                getString(R.string.toast_domain_set_successfully),
                                Toast.LENGTH_SHORT
                            ).show()
                        } else {
                            Toast.makeText(
                                requireContext(),
                                getString(R.string.toast_failed_to_set_domain),
                                Toast.LENGTH_SHORT
                            ).show()
                        }
                    }
                }
            }
        }

        layoutMicGain.setOnClickListener {
            showMicGainDialog()
        }

        uDiskSwitchListener = CompoundButton.OnCheckedChangeListener { _, isChecked ->
            bleManager.setUDiskMode(isChecked) { success ->
                if (!success && isAdded) {
                    Toast.makeText(requireContext(), "Failed to set U-Disk Mode", Toast.LENGTH_SHORT)
                        .show()
                    // Revert on failure
                    requireActivity().runOnUiThread {
                        switchUdiskMode.setOnCheckedChangeListener(null)
                        switchUdiskMode.isChecked = !isChecked
                        switchUdiskMode.setOnCheckedChangeListener(uDiskSwitchListener)
                    }
                }
            }
        }
        switchUdiskMode.setOnCheckedChangeListener(uDiskSwitchListener)

        btnWifiCloud.setOnClickListener {
            findNavController().navigate(R.id.action_feature_to_wifiCloud)
        }

        btnWifiTransfer.setOnClickListener {
            handleWifiTransferRequest()
        }

        btnBindCloud.setOnClickListener {
            lifecycleScope.launch {
                try {
                     val result = NiceBuildSdk.bindDevice(
                         "test-001",
                         currentdevice.serialNumber,
                         "notepin"
                     )
                      if (isAdded) {
                         val message = if (result!=null) getString(R.string.toast_bind_successful) else getString(R.string.toast_bind_failed)
                          Toast.makeText(requireContext(), message, Toast.LENGTH_SHORT).show()
                      }
                } catch (e: Exception) {
                    if (isAdded) {
                        Toast.makeText(requireContext(), "${getString(R.string.toast_bind_failed)}: ${e.message}", Toast.LENGTH_SHORT).show()
                    }
                }
            }
        }

        btnUnbindCloud.setOnClickListener {
            lifecycleScope.launch {
                try {
                     val result = NiceBuildSdk.unbindDevice( "test-001",
                         currentdevice.serialNumber,
                         "notepin")
                      if (isAdded) {
                         val message = if (result!=null) getString(R.string.toast_unbind_successful) else getString(R.string.toast_unbind_failed)
                          Toast.makeText(requireContext(), message, Toast.LENGTH_SHORT).show()
 
                      }
                } catch (e: Exception) {
                    if (isAdded) {
                        Toast.makeText(requireContext(), "${getString(R.string.toast_unbind_failed)}: ${e.message}", Toast.LENGTH_SHORT).show()
                    }
                }
            }
        }

        btnTestCommonSettings.setOnClickListener {
            showCommonSettingsInputDialog()
        }
        
        // Set up real-time sync UI components (if they exist)
        setupRealTimeSyncUI()
    }
    
    /**
     * Set up real-time sync UI components and listeners
     */
    private fun setupRealTimeSyncUI() {
        // Real-time sync functionality is automatically triggered through SDK, UI part is commented out for now
        // Can add corresponding buttons in layout as needed
        
        /*
        view?.findViewById<MaterialButton>(R.id.btn_start_real_time_sync)?.setOnClickListener {
            // Need sessionId, can get from current recording status
        }
        
        view?.findViewById<MaterialButton>(R.id.btn_stop_real_time_sync)?.setOnClickListener {
            mainViewModel.stopRealTimeSync()
        }
        */
        
        Log.d(TAG, "Real-time sync functionality has been set up, will automatically start when device is recording")
    }

    @SuppressLint("SetTextI18n")
    private fun showMicGainDialog() {
        if (!isAdded) return

        val dialog = Dialog(requireContext())
        val view = LayoutInflater.from(requireContext()).inflate(R.layout.dialog_set_mic_gain, null)
        dialog.setContentView(view)
        dialog.window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        val slider = view.findViewById<Slider>(R.id.slider_dialog_mic_gain)
        val valueText = view.findViewById<TextView>(R.id.tv_dialog_mic_gain_value)
        val btnOk = view.findViewById<MaterialButton>(R.id.btn_dialog_ok)
        val btnCancel = view.findViewById<MaterialButton>(R.id.btn_dialog_cancel)

        val initialValue = tvMicGainValue.text.toString().toFloatOrNull() ?: 15f
        slider.value = initialValue
        valueText.text = initialValue.toInt().toString()

        slider.addOnChangeListener { _, value, _ ->
            valueText.text = value.toInt().toString()
        }

        btnCancel.setOnClickListener {
            dialog.dismiss()
        }

        btnOk.setOnClickListener {
            val finalGain = slider.value.toInt()
            bleManager.setMICGain(finalGain) { success ->
                if (isAdded) {
                    requireActivity().runOnUiThread {
                        if (success) {
                            tvMicGainValue.text = finalGain.toString()
                            Toast.makeText(requireContext(), "Mic Gain set to $finalGain", Toast.LENGTH_SHORT).show()
                        } else {
                            Toast.makeText(requireContext(), "Failed to set Mic Gain", Toast.LENGTH_SHORT).show()
                        }
                    }
                }
            }
            dialog.dismiss()
        }

        dialog.show()
    }

    private fun showStatusDialog(message: String) {
        if (!isAdded) return

        val dialog = Dialog(requireContext()).apply {
            setContentView(R.layout.dialog_device_status)
            window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            window?.setBackgroundDrawableResource(android.R.color.transparent)
        }

        val tvMessage = dialog.findViewById<TextView>(R.id.tv_dialog_message)
        val btnOk = dialog.findViewById<MaterialButtonView>(R.id.btn_dialog_ok)

        tvMessage.text = message
        btnOk.setOnClickListener {
            dialog.dismiss()
        }

        dialog.show()
    }

    private fun observeViewModel() {
        mainViewModel.currentDevice.observe(viewLifecycleOwner) { device ->
            device?.let {
                currentdevice = it
            }
        }
        
        mainViewModel.fileList.observe(viewLifecycleOwner) { fileList ->
            val count = fileList?.size ?: 0
            tvFileCountEntry.text = getString(R.string.fragment_device_feature_files_count, count)
        }
        

        mainViewModel.connectionStatus.observe(viewLifecycleOwner) { status ->
            Log.d(TAG, "Connection status: $status")
        }
        
        mainViewModel.recordingStatus.observe(viewLifecycleOwner) { status ->
            Log.d(TAG, "Recording status: $status")
        }
        
        mainViewModel.batteryLevel.observe(viewLifecycleOwner) { level ->
            // Update battery display
            tvBattery.text = "$level%"
            Log.d(TAG, "Battery level: $level%")
        }
        
    }
    

    private fun updateButtonStates() {
        if (isRecording) {
            btnRecordControl.text = getString(R.string.fragment_device_feature_stop_recording)
            btnPauseResume.visibility = View.VISIBLE
            btnPauseResume.isEnabled = true
            if (isPaused) {
                btnPauseResume.text = getString(R.string.fragment_device_feature_resume_recording)
                tvRecordStatus.text = getString(R.string.device_feature_status_paused_state)
                tvRecordStatus.setTextColor(ContextCompat.getColor(requireContext(), R.color.system_blue))
            } else {
                btnPauseResume.text = getString(R.string.fragment_device_feature_pause_recording)
                tvRecordStatus.text = getString(R.string.device_feature_status_recording_state)
                tvRecordStatus.setTextColor(ContextCompat.getColor(requireContext(), R.color.system_red))
            }
        } else {
            btnRecordControl.text = getString(R.string.fragment_device_feature_start_recording)
            btnPauseResume.visibility = View.GONE
            btnPauseResume.isEnabled = false
            tvRecordStatus.text = getString(R.string.device_feature_status_not_recording)
            tvRecordStatus.setTextColor(ContextCompat.getColor(requireContext(), R.color.text_secondary))
        }
    }

    private fun updateUiFromState(state: String?) {
        try {
            val json = state?.let { JSONObject(it) } ?: JSONObject()
            val isRecordingState = json.getInt("state").toLong() == Constants.DEVICE_STATUS_RECORDING
            val isPausedState = json.optBoolean("isPaused", false)
            val isUsbState = json.optInt("privacy", 0) == 0
            val sessionId = json.optLong("sessionId", 0)

            this.isRecording = isRecordingState
            this.isPaused = isPausedState
            

            if (isAdded) {
                switchUdiskMode.setOnCheckedChangeListener(null)
                switchUdiskMode.isChecked = isUsbState
                switchUdiskMode.setOnCheckedChangeListener(uDiskSwitchListener)
            }

            updateButtonStates()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse device state JSON", e)
        }
    }

    override fun onResume() {
        super.onResume()
        activity?.window?.statusBarColor = ContextCompat.getColor(requireContext(), R.color.background_secondary)
        @Suppress("DEPRECATION")
        activity?.window?.decorView?.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
        
        mainViewModel.currentDevice.value?.let {
            bleCore.getFileList(0) { fileList ->
                 if (fileList != null) {
                     mainViewModel.updateFileList(fileList)
                 }
            }
            
            bleCore.getBatteryState { batteryText ->
                requireActivity().runOnUiThread {
                    tvBattery.text = getString(R.string.fragment_device_feature_battery_label, batteryText)
                    
                    try {
                        val regex = Regex("(\\d+)%")
                        val matchResult = regex.find(batteryText)
                        currentBatteryLevel = matchResult?.groupValues?.get(1)?.toInt() ?: 0
                        Log.d(TAG, "Updated battery level in onResume: $currentBatteryLevel%")
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to parse battery level in onResume: $batteryText", e)
                        currentBatteryLevel = 0
                    }
                }
            }
            
            // Initial state sync without toast
            bleCore.getDeviceState { state ->
                requireActivity().runOnUiThread {
                    updateUiFromState(state)
                }
            }
        }

        // When returning from settings, re-check the "All files access" permission
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (Environment.isExternalStorageManager()) {
                 // We don't automatically navigate here, to avoid navigating just by switching apps.
                 // The user needs to click the button again to trigger the check.
                 // This applies to both file list access and WiFi transfer storage permission
            }
        }
    }



    override fun onDestroy() {
        super.onDestroy()
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun requestStoragePermission() {
        // ... existing code ...
    }

    // 1. Send file info
    private suspend fun syncAppFileInfoSuspend(type: Int, totalSize: Long): FileInfoSyncRsp? {
        return suspendCoroutine { continuation ->
            TntAgent.getInstant().bleAgent.syncAppFileInfo(type, totalSize, { req ->
                Log.d("DeviceFeatureFragment", "syncAppFileInfoSuspend command sent: [$req]")
            }) { infoRsp ->
                Log.d("DeviceFeatureFragment", "syncAppFileInfoSuspend response received: [$infoRsp]")
                continuation.resume(infoRsp)
            }
        }
    }

    // 2. Send file data
    private suspend fun syncAppFileDataSuspend(type: Int, offset: Long, size: Int, bytes: ByteArray): FileInfoSyncRsp? {
        return suspendCoroutine { continuation ->
            TntAgent.getInstant().bleAgent.syncAppFileData(type, offset, size, bytes, {
                Log.d("DeviceFeatureFragment","syncAppFileDataSuspend command sent: [$it]")
            }) {
                Log.d("DeviceFeatureFragment", "syncAppFileDataSuspend response received: [$it]")
                continuation.resume(it)
            }
        }
    }

    // 3. Send CRC verification
    private suspend fun fileDataCheckSuspend(type: Int, crc: Short): FileDataCheckRsp? {
        return suspendCoroutine { continuation ->
            TntAgent.getInstant().bleAgent.fileDataCheck(type, crc, {
                Log.d("DeviceFeatureFragment","fileDataCheckSuspend command sent: [$it]")
            }) {
                Log.d("DeviceFeatureFragment","fileDataCheckSuspend response received: [$it]")
                continuation.resume(it)
            }
        }
    }

    private fun checkAndRequestStoragePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (Environment.isExternalStorageManager()) {
                navigateToFileList()
            } else {
                showCustomPermissionDialog()
            }
        } else {
            // For legacy storage, use the new unified PermissionUtils
            val permissions = arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE)
            PermissionUtils.checkAndRequestPermissions(
                requireActivity(),
                permissions,
                requestPermissionLauncher,
                "storage_permissions",
                ::navigateToFileList
            )
        }
    }
    
    private fun showCustomPermissionDialog() {
        val dialog = Dialog(requireContext())
        dialog.setContentView(R.layout.dialog_custom_permission)
        dialog.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))

        val btnPositive = dialog.findViewById<Button>(R.id.btn_positive)
        val btnNegative = dialog.findViewById<Button>(R.id.btn_negative)

        btnPositive.setOnClickListener {
            dialog.dismiss()
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:${requireContext().packageName}"))
                requestManageStorageLauncher.launch(intent)
            } catch (e: Exception) {
                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                requestManageStorageLauncher.launch(intent)
            }
        }

        btnNegative.setOnClickListener {
            dialog.dismiss()
        }

        dialog.show()
    }



    
    /**
     * Handle WiFi transfer request with comprehensive permission and prerequisite checking
     */
    private fun handleWifiTransferRequest() {
        // Check all prerequisites
        val prerequisiteResult = WifiTransferPermissions.checkTransferPrerequisites(requireContext())
        val bleConnected = bleCore.isConnected()
        
        Log.i("DeviceFeatureFragment", "WiFi transfer prerequisite check:")
        Log.i("DeviceFeatureFragment", "  - Has all permissions: ${prerequisiteResult.hasAllPermissions}")
        Log.i("DeviceFeatureFragment", "  - WiFi enabled: ${prerequisiteResult.isWifiEnabled}")
        Log.i("DeviceFeatureFragment", "  - Location enabled: ${prerequisiteResult.isLocationEnabled}")
        Log.i("DeviceFeatureFragment", "  - Write settings permission: ${prerequisiteResult.hasWriteSettingsPermission}")
        Log.i("DeviceFeatureFragment", "  - BLE connected: $bleConnected")
        Log.i("DeviceFeatureFragment", "  - Can proceed: ${prerequisiteResult.canProceed && bleConnected}")
        
        if (!prerequisiteResult.hasAllPermissions) {
            val missingPermissions = WifiTransferPermissions.getMissingPermissions(requireContext())
            Log.i("DeviceFeatureFragment", "  - Missing permissions: ${missingPermissions.joinToString()}")
        }
        
        if (prerequisiteResult.canProceed && bleConnected) {
            // All prerequisites met, start transfer with auto download
            Log.i("DeviceFeatureFragment", "All prerequisites met, starting WiFi transfer with auto download")
            mainViewModel.startWifiTransfer(this@DeviceFeatureFragment)
            return
        }
        
        // Handle specific issues
        when {
            !prerequisiteResult.hasAllPermissions -> {
                Log.i("DeviceFeatureFragment", "Missing permissions, requesting via PermissionUtils")
                requestWifiPermissionsViaUtils()
            }
            
            !prerequisiteResult.isWifiEnabled -> {
                Log.i("DeviceFeatureFragment", "Showing WiFi settings dialog")
                showWifiSettingsDialog()
            }
            
            !prerequisiteResult.isLocationEnabled -> {
                Log.i("DeviceFeatureFragment", "Showing location settings dialog")
                showLocationSettingsDialog()
            }
            
            !prerequisiteResult.hasWriteSettingsPermission -> {
                Log.i("DeviceFeatureFragment", "Showing write settings permission dialog")
                showWriteSettingsPermissionDialog()
            }
            
            !bleConnected -> {
                Log.w("DeviceFeatureFragment", "BLE not connected")
                Toast.makeText(requireContext(), getString(R.string.wifi_transfer_device_not_connected), Toast.LENGTH_SHORT).show()
            }
            
            else -> {
                Log.w("DeviceFeatureFragment", "Unknown issue: ${prerequisiteResult.getErrorMessage()}")
                Toast.makeText(requireContext(), prerequisiteResult.getErrorMessage() ?: getString(R.string.wifi_transfer_not_available), Toast.LENGTH_LONG).show()
            }
        }
    }
    
    /**
     * Request WiFi transfer permissions using standard PermissionUtils pattern
     */
    private fun requestWifiPermissionsViaUtils() {
        Log.i("DeviceFeatureFragment", "Requesting WiFi transfer permissions")
        
        // First check if we need modern storage permission (Android 11+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !Environment.isExternalStorageManager()) {
            Log.i("DeviceFeatureFragment", "Need storage permission for Android 11+")
            showCustomPermissionDialog()
            return
        }
        
        // Build permission array based on Android version
        val permissionsToRequest = mutableListOf<String>().apply {
            // Location permissions (always required for WiFi scanning)
            add(Manifest.permission.ACCESS_FINE_LOCATION)
            add(Manifest.permission.ACCESS_COARSE_LOCATION)
            
            // Legacy storage permission (Android 10 and below)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
            }
            
            // Android 13+ WiFi device permission
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                try {
                    add(Manifest.permission.NEARBY_WIFI_DEVICES)
                } catch (e: Exception) {
                    Log.w("DeviceFeatureFragment", "NEARBY_WIFI_DEVICES permission not available: ${e.message}")
                }
            }
        }.toTypedArray()
        
        Log.i("DeviceFeatureFragment", "Requesting permissions: ${permissionsToRequest.joinToString()}")
        
        // Use standard PermissionUtils pattern (same as scan and file list)
        PermissionUtils.checkAndRequestPermissions(
            requireActivity(),
            permissionsToRequest,
            requestPermissionLauncher,
            "wifi_transfer_permissions"
        ) {
            Log.i("DeviceFeatureFragment", "All WiFi transfer permissions granted, retrying transfer")
            handleWifiTransferRequest()
        }
    }
    
    /**
     * Show WiFi settings dialog
     */
    private fun showWifiSettingsDialog() {
        AlertDialog.Builder(requireContext())
            .setTitle(getString(R.string.wifi_transfer_wifi_required_title))
            .setMessage(getString(R.string.wifi_transfer_wifi_required_message))
            .setPositiveButton(getString(R.string.wifi_transfer_open_settings)) { _, _ ->
                WifiTransferPermissions.openWifiSettings(requireContext())
            }
            .setNegativeButton(getString(R.string.wifi_transfer_cancel_permissions), null)
            .show()
    }
    
    /**
     * Show location settings dialog
     */
    private fun showLocationSettingsDialog() {
        AlertDialog.Builder(requireContext())
            .setTitle(getString(R.string.wifi_transfer_location_required_title))
            .setMessage(getString(R.string.wifi_transfer_location_required_message))
            .setPositiveButton(getString(R.string.wifi_transfer_open_settings)) { _, _ ->
                WifiTransferPermissions.openLocationSettings(requireContext())
            }
            .setNegativeButton(getString(R.string.wifi_transfer_cancel_permissions), null)
            .show()
    }
    
    /**
     * Show write settings permission dialog
     */
    private fun showWriteSettingsPermissionDialog() {
        AlertDialog.Builder(requireContext())
            .setTitle(getString(R.string.wifi_transfer_write_settings_required_title))
            .setMessage(getString(R.string.wifi_transfer_write_settings_required_message))
            .setPositiveButton(getString(R.string.wifi_transfer_open_settings)) { _, _ ->
                WifiTransferPermissions.openWriteSettingsPermission(requireContext())
            }
            .setNegativeButton(getString(R.string.wifi_transfer_cancel_permissions), null)
            .show()
    }

    private fun navigateToFileList() {
        findNavController().navigate(R.id.action_deviceFeature_to_fileList)
    }
    
    /**
     * 处理固件更新流程
     */
    private fun handleFirmwareUpdate() {
        val device = mainViewModel.currentDevice.value
        if (device == null) {
            Toast.makeText(requireContext(), getString(R.string.firmware_update_device_not_connected), Toast.LENGTH_SHORT).show()
            return
        }
        
        // 显示检查更新的提示
        btnCheckUpdate.text = getString(R.string.firmware_update_checking)
        btnCheckUpdate.isEnabled = false
        
        // 检查固件更新
        firmwareUpdateManager.checkForUpdate(device, object : SimpleFirmwareUpdateCallback() {
            override fun onUpdateCheckResult(result: Result<FirmwareUpdateInfo>) {
                if (!isAdded) return
                
                requireActivity().runOnUiThread {
                    // 恢复按钮状态
                    btnCheckUpdate.text = getString(R.string.action_check_update)
                    btnCheckUpdate.isEnabled = true
                    
                    result.fold(
                        onSuccess = { updateInfo ->
                            showUpdateCheckResult(updateInfo)
                        },
                        onFailure = { error ->
                            Toast.makeText(
                                requireContext(),
                                getString(R.string.firmware_update_check_failed, error.message ?: "Unknown error"),
                                Toast.LENGTH_LONG
                            ).show()
                        }
                    )
                }
            }
        })
    }
    
    /**
     * 显示更新检查结果
     */
    private fun showUpdateCheckResult(updateInfo: FirmwareUpdateInfo) {
        FirmwareUpdateDialogs.showUpdateConfirmDialog(
            context = requireContext(),
            updateInfo = updateInfo,
            onConfirm = {
                if (updateInfo.hasUpdate) {
                    startFirmwareDownload(updateInfo)
                }
            },
            onCancel = {
                // 用户取消更新
            }
        )
    }
    
    /**
     * 开始下载固件
     */
    private fun startFirmwareDownload(updateInfo: FirmwareUpdateInfo) {
        // 显示下载进度对话框
        downloadProgressDialog = FirmwareUpdateProgressDialog(
            context = requireContext(),
            title = getString(R.string.firmware_update_downloading_progress),
            cancellable = true
        ).apply {
            onCancel = {
                firmwareUpdateManager.cancel()
                dismiss()
            }
            show()
        }
        
        // 开始下载
        firmwareUpdateManager.downloadFirmware(updateInfo, object : SimpleFirmwareUpdateCallback() {
            override fun onDownloadProgress(progress: UpdateProgress) {
                if (!isAdded) return
                
                requireActivity().runOnUiThread {
                    downloadProgressDialog?.updateProgress(progress)
                }
            }
            
            override fun onDownloadComplete(result: FirmwareDownloadResult) {
                if (!isAdded) return
                
                requireActivity().runOnUiThread {
                    downloadProgressDialog?.dismiss()
                    downloadProgressDialog = null
                    
                    if (result.success && result.file != null) {
                        showInstallConfirmation(updateInfo, result.file!!)
                    } else {
                        Toast.makeText(
                            requireContext(),
                            getString(R.string.firmware_update_download_failed) + ": " + (result.error ?: "Unknown error"),
                            Toast.LENGTH_LONG
                        ).show()
                    }
                }
            }
        })
    }
    
    /**
     * 显示安装确认对话框
     */
    private fun showInstallConfirmation(updateInfo: FirmwareUpdateInfo, firmwareFile: java.io.File) {
        FirmwareUpdateDialogs.showInstallConfirmDialog(
            context = requireContext(),
            updateInfo = updateInfo,
            onConfirm = {
                startFirmwareInstallation(firmwareFile, updateInfo)
            },
            onCancel = {
                // 用户选择稍后安装
                Toast.makeText(
                    requireContext(),
                    getString(R.string.firmware_update_download_complete),
                    Toast.LENGTH_SHORT
                ).show()
            }
        )
    }
    
    private data class FirmwareValidationResult(
        val isValid: Boolean,
        val errorMessage: String
    )
    

    private fun validateFirmwareInstallationConditions(): FirmwareValidationResult {
        Log.d(TAG, "Validating firmware installation conditions")
        
        val device = mainViewModel.currentDevice.value
        if (device == null) {
            Log.e(TAG, "❌ Device not available for validation")
            return FirmwareValidationResult(false, getString(R.string.firmware_update_device_not_connected))
        }
        
        Log.d(TAG, "Battery level: ${currentBatteryLevel}%")
        if (currentBatteryLevel < 40) {
            val message = getString(R.string.firmware_update_error_low_battery, currentBatteryLevel)
            Log.e(TAG, "❌ Battery level too low: ${currentBatteryLevel}%")
            return FirmwareValidationResult(false, message)
        }
        
        val isInUDiskMode = switchUdiskMode.isChecked
        Log.d(TAG, "U-disk mode: $isInUDiskMode")
        if (isInUDiskMode) {
            val message = getString(R.string.firmware_update_error_udisk_mode)
            Log.e(TAG, "❌ Device is in U-disk mode")
            return FirmwareValidationResult(false, message)
        }
        
        if (isRecording) {
            val message = getString(R.string.firmware_update_error_recording)
            Log.e(TAG, "❌ Device is currently recording")
            return FirmwareValidationResult(false, message)
        }

        //4： todo：check is downloading

        Log.d(TAG, "✅ All firmware installation conditions are met")
        return FirmwareValidationResult(true, "")
    }
    
    /**
     * 开始安装固件
     */
    private fun startFirmwareInstallation(firmwareFile: java.io.File, updateInfo: FirmwareUpdateInfo) {
        val device = mainViewModel.currentDevice.value
        if (device == null) {
            Toast.makeText(requireContext(), getString(R.string.firmware_update_device_not_connected), Toast.LENGTH_SHORT).show()
            return
        }
        
        val validationResult = validateFirmwareInstallationConditions()
        if (!validationResult.isValid) {
            Toast.makeText(requireContext(), validationResult.errorMessage, Toast.LENGTH_LONG).show()
            return
        }
        
        installProgressDialog = FirmwareUpdateProgressDialog(
            context = requireContext(),
            title = getString(R.string.firmware_update_installing_progress),
            cancellable = true
        ).apply {
            onCancel = {
                firmwareUpdateManager.cancel()
                dismiss()
                
                Toast.makeText(
                    requireContext(),
                    getString(R.string.firmware_update_install_cancelled),
                    Toast.LENGTH_SHORT
                ).show()
            }
            show()
        }
        
        firmwareUpdateManager.installFirmware(firmwareFile, device, updateInfo, object : SimpleFirmwareUpdateCallback() {
            override fun onInstallProgress(progress: UpdateProgress) {
                if (!isAdded) return
                
                Log.i("DeviceFeature", "【Fragment进度】接收到UI进度更新: ${progress.progress}%")
                
                requireActivity().runOnUiThread {
                    Log.d("DeviceFeature", "【Fragment UI】准备更新UI进度: ${progress.progress}%")
                    installProgressDialog?.updateProgress(progress)
                    Log.d("DeviceFeature", "【Fragment UI】UI进度更新完成: ${progress.progress}%")
                }
            }
            
            override fun onInstallComplete(result: FirmwareInstallResult) {
                if (!isAdded) return
                
                requireActivity().runOnUiThread {
                    installProgressDialog?.dismiss()
                    installProgressDialog = null
                    
                    if (result.success) {
                        Toast.makeText(
                            requireContext(),
                            getString(R.string.firmware_update_install_success),
                            Toast.LENGTH_LONG
                        ).show()
                        
                        // 更新设备信息显示
                        loadDeviceInfo()
                    } else {
                        Toast.makeText(
                            requireContext(),
                            getString(R.string.firmware_update_install_failed, result.error ?: "Unknown error"),
                            Toast.LENGTH_LONG
                        ).show()
                    }
                }
            }
        })
    }
    
    override fun onDestroyView() {
        super.onDestroyView()
        
        // 清理固件更新相关资源
        firmwareUpdateManager.cancel()
        downloadProgressDialog?.dismiss()
        installProgressDialog?.dismiss()
        downloadProgressDialog = null
        installProgressDialog = null
        
        // 恢复默认状态栏颜色和外观
        activity?.window?.statusBarColor = ContextCompat.getColor(requireContext(), R.color.white)
        @Suppress("DEPRECATION")
        activity?.window?.decorView?.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR

        timeoutRunnable?.let { timeoutHandler.removeCallbacks(it) }
    }

    /**
     * 显示通用设置输入对话框
     */
    private fun showCommonSettingsInputDialog() {
        if (!isAdded) return

        val dialog = Dialog(requireContext())
        val view = LayoutInflater.from(requireContext()).inflate(R.layout.dialog_common_settings_test, null)
        dialog.setContentView(view)
        dialog.window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        val title = view.findViewById<TextView>(R.id.tv_dialog_title)
        val typeInputField = view.findViewById<com.google.android.material.textfield.TextInputEditText>(R.id.et_setting_type)
        val valueInputField = view.findViewById<com.google.android.material.textfield.TextInputEditText>(R.id.et_setting_value)
        val btnOk = view.findViewById<TextView>(R.id.btn_dialog_positive)
        val btnCancel = view.findViewById<TextView>(R.id.btn_dialog_negative)

        title.text = getString(R.string.dialog_title_test_common_settings)

        btnCancel.setOnClickListener {
            dialog.dismiss()
        }

        btnOk.setOnClickListener {
            val typeValue = typeInputField.text.toString().trim()
            val valueValue = valueInputField.text.toString().trim()
            
            if (typeValue.isNotEmpty() && valueValue.isNotEmpty()) {
                try {
                    val settingType = typeValue.toInt()
                    val settingValue = valueValue.toInt()
                    dialog.dismiss()
                    testCommonSettings(settingType, settingValue)
                } catch (e: NumberFormatException) {
                    Toast.makeText(requireContext(), getString(R.string.toast_invalid_input), Toast.LENGTH_SHORT).show()
                }
            } else {
                Toast.makeText(requireContext(), getString(R.string.toast_input_required), Toast.LENGTH_SHORT).show()
            }
        }

        dialog.show()
    }

    /**
     * 执行通用设置测试
     */
    private fun testCommonSettings(settingType: Int, settingValue: Int) {
        bleCore.commonSettings(settingType, settingValue) { success, response ->
            if (isAdded) {
                requireActivity().runOnUiThread {
                    if (success && response != null) {
                        val message = getString(R.string.dialog_result_message_success, settingType, settingValue, response.value.toInt())
                        showResultDialog(getString(R.string.dialog_result_title_success), message)
                    } else {
                        showResultDialog(getString(R.string.dialog_result_title_failed), getString(R.string.dialog_result_message_failed))
                    }
                }
            }
        }
    }

    /**
     * 显示结果对话框
     */
    private fun showResultDialog(title: String, message: String) {
        if (!isAdded) return

        val dialog = Dialog(requireContext())
        val view = LayoutInflater.from(requireContext()).inflate(R.layout.dialog_view_summary, null)
        dialog.setContentView(view)
        dialog.window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        val titleView = view.findViewById<TextView>(R.id.tv_summary_title)
        val messageView = view.findViewById<TextView>(R.id.tv_summary_content)
        val btnOk = view.findViewById<ImageButton>(R.id.btn_close)

        titleView.text = title
        messageView.text = message

        btnOk.setOnClickListener {
            dialog.dismiss()
        }

        dialog.show()
    }
}