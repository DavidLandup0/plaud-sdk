import React, { useState, useEffect, useMemo } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  Alert,
  ActivityIndicator,
  Switch,
  Modal,
  TextInput,
} from 'react-native';
import { useTranslation } from 'react-i18next';
import { PlaudBluetooth, PlaudRecording, PlaudFileManager } from '../../js/PlaudSDK';

// Format version number: determine version type based on serial number and format display
const formatVersion = (versionCode: number, serialNumber: string): string => {
  // Determine device type and version type based on serial number prefix
  const prefix = serialNumber.substring(0, 3);
  let versionType = 'V'; // Default is V type

  // Format to 4 digits
  const formattedCode = String(versionCode).padStart(4, '0');
  return `${versionType}${formattedCode}`;
};

interface Device {
  id: string;
  name: string;
  serialNumber: string;
  macAddress?: string;
  rssi: number;
  versionCode?: number;
  wholeVersion?: string;
  batteryLevel?: number;
  isCharging?: boolean;
  manufacturer?: string;
  bindCode?: number;
  isConnected?: number;
  free?: number;
  total?: number;
}

interface DeviceFeatureScreenProps {
  device: Device;
  onNavigateToFiles: () => void;
  onDisconnect: () => void;
}

const DeviceFeatureScreen: React.FC<DeviceFeatureScreenProps> = ({ 
  device, 
  onNavigateToFiles,
  onDisconnect 
}) => {
  const { t } = useTranslation();
  // Use useMemo to cache initial device info to avoid repeated calculations
  const initialDeviceInfo = useMemo(() => ({
    serialNumber: device.serialNumber,
    firmware: device.wholeVersion || (device.versionCode ? formatVersion(device.versionCode, device.serialNumber) : t('device.getting_info')),
    battery: (device.batteryLevel !== undefined && device.batteryLevel > 0) ? `${device.batteryLevel}%${device.isCharging ? ' (Charging)' : ''}` : t('device.getting_info'),
    storage: t('device.getting_info'),
    micGain: 15,
  }), [device.serialNumber, device.wholeVersion, device.versionCode, device.batteryLevel, device.isCharging]);

  const [deviceInfo, setDeviceInfo] = useState(initialDeviceInfo);
  
  const [recordingState, setRecordingState] = useState({
    isRecording: false,
    isPaused: false,
    status: 'Idle',
  });
  
  const [fileCount, setFileCount] = useState(0);
  const [loading, setLoading] = useState(false);
  const [deviceInfoExpanded, setDeviceInfoExpanded] = useState(true);
  const [udiskMode, setUdiskMode] = useState(false);
  
  // Modal state
  const [micGainModalVisible, setMicGainModalVisible] = useState(false);
  const [tempMicGain, setTempMicGain] = useState(15);

  useEffect(() => {
    // Load device basic info immediately
    loadDeviceInfo();
    loadFileCount();
    
    // Device info will be auto-updated through event listeners
    
    // Listen for device connection events - update basic device info
    const deviceConnectedListener = PlaudBluetooth.addListener('onDeviceConnected', (data: any) => {
      console.log('Device connected, updating device info:', data);
      if (data.device) {
        // Get firmware version immediately from connection event
        if (data.device.wholeVersion || data.device.versionCode) {
          setDeviceInfo(prev => ({
            ...prev,
            firmware: data.device.wholeVersion || formatVersion(data.device.versionCode, data.device.serialNumber),
          }));
        }
        // Update basic device info
        setDeviceInfo(prev => ({
          ...prev,
          serialNumber: data.device.serialNumber || prev.serialNumber,
        }));
      }
      // Load other info immediately
      loadFileCount();
    });
    
    // Listen for file list update events
    const fileListListener = PlaudFileManager.addListener('onFileListUpdated', (data: any) => {
      console.log('File list updated:', data);
      if (data && data.files) {
        setFileCount(data.files.length);
      }
    });
    
    // Listen for real-time storage info update events
    const storageInfoListener = PlaudBluetooth.addListener('onStorageInfoUpdated', (data: any) => {
      console.log('Storage info real-time update:', data);
      if (data) {
        let storageText = t('device.getting_info');
        if (data.freeSpaceText && data.totalSpaceText && data.usagePercent) {
          const usagePercent = Math.round(parseFloat(data.usagePercent));
          storageText = `${data.usedSpaceText} / ${data.totalSpaceText} (${usagePercent}%)`;
        } else if (data.usedSpaceText && data.totalSpaceText) {
          storageText = `${data.usedSpaceText} / ${data.totalSpaceText}`;
        }
        setDeviceInfo(prev => ({
          ...prev,
          storage: storageText,
        }));
      }
    });
    
    // Listen for real-time battery info update events
    const batteryInfoListener = PlaudBluetooth.addListener('onBatteryInfoUpdated', (data: any) => {
      console.log('Battery info real-time update:', data);
      if (data) {
        let batteryText = t('device.getting_info');
        if (data.batteryText) {
          const chargingText = data.isCharging ? ' (Charging)' : '';
          batteryText = `${data.batteryText}${chargingText}`;
        } else if (data.batteryLevel !== undefined) {
          const chargingText = data.isCharging ? ' (Charging)' : '';
          batteryText = `${data.batteryLevel}%${chargingText}`;
        }
        setDeviceInfo(prev => ({
          ...prev,
          battery: batteryText,
        }));
      }
    });
    
    // Listen for recording state change events
    const recordingStartedListener = PlaudRecording.addListener('onRecordingStarted', (data: any) => {
      console.log('Recording start event:', data);
      setRecordingState({
        isRecording: true,
        isPaused: false,
        status: 'Recording',
      });
    });
    
    const recordingStoppedListener = PlaudRecording.addListener('onRecordingStopped', (data: any) => {
      console.log('Recording stop event:', data);
      setRecordingState({
        isRecording: false,
        isPaused: false,
        status: 'Idle',
      });
      // Refresh file list after recording ends
      loadFileCount();
    });
    
    const recordingPausedListener = PlaudRecording.addListener('onRecordingPaused', (data: any) => {
      console.log('Recording pause event:', data);
      setRecordingState({
        isRecording: true,
        isPaused: true,
        status: 'Paused',
      });
    });
    
    const recordingResumedListener = PlaudRecording.addListener('onRecordingResumed', (data: any) => {
      console.log('Recording resume event:', data);
      setRecordingState({
        isRecording: true,
        isPaused: false,
        status: 'Recording',
      });
    });
    
    return () => {
      deviceConnectedListener.remove();
      fileListListener.remove();
      storageInfoListener.remove();
      batteryInfoListener.remove();
      recordingStartedListener.remove();
      recordingStoppedListener.remove();
      recordingPausedListener.remove();
      recordingResumedListener.remove();
    };
  }, []);

  // Listen for device prop changes, sync update device info (only when there's new valid data)
  useEffect(() => {
    setDeviceInfo(prev => {
      let updated = false;
      const newInfo = { ...prev };
      
      // Only update when there's better data, avoid resetting already fetched info
      if (device.wholeVersion && prev.firmware === t('device.getting_info')) {
        newInfo.firmware = device.wholeVersion;
        updated = true;
      } else if (device.versionCode && prev.firmware === t('device.getting_info')) {
        newInfo.firmware = formatVersion(device.versionCode, device.serialNumber);
        updated = true;
      }
      
      if (device.batteryLevel !== undefined && device.batteryLevel > 0 && prev.battery === t('device.getting_info')) {
        const chargingText = device.isCharging ? ' (Charging)' : '';
        newInfo.battery = `${device.batteryLevel}%${chargingText}`;
        updated = true;
      }
      
      if (device.serialNumber !== prev.serialNumber) {
        newInfo.serialNumber = device.serialNumber;
        updated = true;
      }
      
      return updated ? newInfo : prev;
    });
  }, [device.wholeVersion, device.versionCode, device.batteryLevel, device.isCharging, device.serialNumber]);

  const loadDeviceInfo = async () => {
    try {
      console.log('Loading device basic info...');
      
      // Get device state
      const stateResult = await PlaudFileManager.getDeviceState();
      if (stateResult.success) {
        setRecordingState({
          isRecording: stateResult.isRecording,
          isPaused: false,
          status: stateResult.isRecording ? 'Recording' : 'Idle',
        });
      }

      // Battery and storage info auto-updated through real-time event listeners
      console.log('Waiting for battery and storage info to auto-update through events...');

    } catch (error) {
      console.error('Failed to load device info:', error);
    }
  };

  const loadFileCount = async () => {
    try {
      const result = await PlaudFileManager.getFileList();
      if (result && result.success && result.files) {
        setFileCount(result.files.length);
      }
    } catch (error) {
      console.error('Failed to load file count:', error);
    }
  };

  // Recording control
  const handleStartRecording = async () => {
    if (recordingState.isRecording) {
      Alert.alert(t('common.notice'), 'Device is already recording');
      return;
    }

    setLoading(true);
    try {
      const sessionId = Date.now();
      const result = await PlaudRecording.startRecording(device.id, { sessionId });
      setRecordingState({
        isRecording: true,
        isPaused: false,
        status: 'Recording',
      });
      console.log('Recording started');
    } catch (error: any) {
      console.error('Failed to start recording:', error);
      Alert.alert(t('common.error'), `Failed to start recording: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleStopRecording = async () => {
    if (!recordingState.isRecording) {
      Alert.alert(t('common.notice'), 'Device is not recording');
      return;
    }

    setLoading(true);
    try {
      await PlaudRecording.stopRecording();
      setRecordingState({
        isRecording: false,
        isPaused: false,
        status: 'Idle',
      });
      console.log('Recording stopped');
      loadFileCount();
    } catch (error: any) {
      console.error('Failed to stop recording:', error);
      Alert.alert(t('common.error'), `Failed to stop recording: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handlePauseResume = async () => {
    if (!recordingState.isRecording) {
      Alert.alert(t('common.notice'), 'Device is not recording');
      return;
    }

    setLoading(true);
    try {
      if (recordingState.isPaused) {
        // Resume recording
        await PlaudRecording.resumeRecording();
        setRecordingState(prev => ({
          ...prev,
          isPaused: false,
          status: 'Recording',
        }));
        console.log('Recording resumed');
      } else {
        // Pause recording
        await PlaudRecording.pauseRecording();
        setRecordingState(prev => ({
          ...prev,
          isPaused: true,
          status: 'Paused',
        }));
        console.log('Recording paused');
      }
    } catch (error: any) {
      console.error('Failed to pause/resume recording:', error);
      Alert.alert(t('common.error'), `Failed to pause/resume recording: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  // Device functions
  const handleGetStatus = async () => {
    setLoading(true);
    try {
      await loadDeviceInfo();
      Alert.alert(t('common.success'), 'Device status updated');
    } catch (error: any) {
      Alert.alert(t('common.error'), `Failed to get status: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleCheckUpdate = () => {
    Alert.alert(
      'Firmware Update',
      'Current firmware version: v1.2.3\nLatest version: v1.2.3\n\nYour firmware is already the latest version',
      [{ text: 'OK' }]
    );
  };

  const handleMicGainSetting = () => {
    setTempMicGain(deviceInfo.micGain);
    setMicGainModalVisible(true);
  };

  const saveMicGain = () => {
    setDeviceInfo(prev => ({ ...prev, micGain: tempMicGain }));
    setMicGainModalVisible(false);
    Alert.alert(t('common.success'), `Microphone gain set to ${tempMicGain}`);
  };

  const handleWifiDomain = () => {
    Alert.alert(t('device.wifi_domain'), t('common.under_development'));
  };

  const handleWifiCloud = () => {
    Alert.alert(t('device.wifi_cloud'), t('common.under_development'));
  };

  const handleWifiTransfer = () => {
    Alert.alert(t('device.wifi_transfer'), t('common.under_development'));
  };

  const handleBindCloud = () => {
    Alert.alert(t('device.bind_cloud'), t('common.under_development'));
  };

  const handleUnbindCloud = () => {
    Alert.alert(t('device.unbind_cloud'), t('common.under_development'));
  };

  const handleUnpair = () => {
    Alert.alert(
      t('device.unbind'),
      'Are you sure you want to unbind this device? You will need to pair again after unbinding.',
      [
        { text: t('common.cancel'), style: 'cancel' },
        {
          text: t('device.unbind'),
          style: 'destructive',
          onPress: () => {
            Alert.alert(t('common.success'), 'Device unbound');
            onDisconnect();
          }
        }
      ]
    );
  };

  const handleDisconnect = async () => {
    Alert.alert(
      t('device.disconnect'),
      'Are you sure you want to disconnect the device?',
      [
        { text: t('common.cancel'), style: 'cancel' },
        {
          text: t('device.disconnect'),
          style: 'destructive',
          onPress: async () => {
            try {
              await PlaudBluetooth.disconnect();
              onDisconnect();
            } catch (error) {
              console.error('Failed to disconnect:', error);
              onDisconnect();
            }
          },
        },
      ]
    );
  };

  return (
    <View style={styles.container}>
      {/* Toolbar */}
      <View style={styles.toolbar}>
        <TouchableOpacity style={styles.backButton} onPress={handleDisconnect}>
          <Text style={styles.backButtonText}>←</Text>
        </TouchableOpacity>
        <Text style={styles.toolbarTitle}>{t('device.details')}</Text>
        <View style={styles.backButton} />
      </View>

      <ScrollView style={styles.scrollView} showsVerticalScrollIndicator={false}>
        {/* Device info card */}
        <View style={styles.card}>
          <TouchableOpacity
            style={styles.cardHeader}
            onPress={() => setDeviceInfoExpanded(!deviceInfoExpanded)}
          >
            <Text style={styles.cardTitle}>{t('device.info')}</Text>
            <Text style={styles.expandIcon}>
              {deviceInfoExpanded ? '−' : '+'}
            </Text>
          </TouchableOpacity>
          
          {deviceInfoExpanded && (
            <View style={styles.cardContent}>
              <Text style={styles.infoText}>{t('device.serial_number')}: {deviceInfo.serialNumber}</Text>
              
              <View style={styles.infoRow}>
                <Text style={styles.infoText}>{t('device.firmware')}: {deviceInfo.firmware}</Text>
                {/* Firmware update feature is under development, temporarily hidden */}
                {/* <TouchableOpacity style={styles.miniButton} onPress={handleCheckUpdate}>
                  <Text style={styles.miniButtonText}>{t('device.check_update')}</Text>
                </TouchableOpacity> */}
              </View>
              
              <Text style={styles.infoText}>{t('device.battery')}: {deviceInfo.battery}</Text>
              <Text style={styles.infoText}>{t('device.storage')}: {deviceInfo.storage}</Text>
              
              <View style={styles.switchRow}>
                <Text style={styles.infoText}>{t('device.usb_mode')}</Text>
                <Switch
                  value={udiskMode}
                  onValueChange={setUdiskMode}
                  trackColor={{ false: '#E0E0E0', true: '#81C784' }}
                  thumbColor={udiskMode ? '#4CAF50' : '#FFFFFF'}
                />
              </View>
            </View>
          )}
        </View>

        {/* Recording control card */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>{t('recording.control')}</Text>
          
          <View style={styles.cardContent}>
            <Text style={[
              styles.recordStatus,
              { color: recordingState.isRecording ? '#F44336' : '#4CAF50' }
            ]}>
              {t('recording.status')}: {recordingState.status}
            </Text>
            
            <View style={styles.buttonRow}>
              <TouchableOpacity
                style={[
                  styles.button,
                  styles.buttonOutlined,
                  recordingState.isRecording && styles.buttonDisabled
                ]}
                onPress={handleStartRecording}
                disabled={loading || recordingState.isRecording}
              >
                <Text style={[
                  styles.buttonTextOutlined,
                  recordingState.isRecording && styles.buttonTextDisabled
                ]}>
                  {t('recording.start')}
                </Text>
              </TouchableOpacity>
              
              <TouchableOpacity
                style={[
                  styles.button,
                  styles.buttonOutlined,
                  !recordingState.isRecording && styles.buttonDisabled
                ]}
                onPress={handlePauseResume}
                disabled={loading || !recordingState.isRecording}
              >
                <Text style={[
                  styles.buttonTextOutlined,
                  !recordingState.isRecording && styles.buttonTextDisabled
                ]}>
                  {recordingState.isPaused ? t('recording.resume') : t('recording.pause')}
                </Text>
              </TouchableOpacity>
            </View>
            
            <TouchableOpacity
              style={[
                styles.button,
                styles.buttonOutlined,
                !recordingState.isRecording && styles.buttonDisabled
              ]}
              onPress={handleStopRecording}
              disabled={loading || !recordingState.isRecording}
            >
              <Text style={[
                styles.buttonTextOutlined,
                !recordingState.isRecording && styles.buttonTextDisabled
              ]}>
                {t('recording.stop')}
              </Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* File list entry card */}
        <TouchableOpacity style={styles.card} onPress={onNavigateToFiles}>
          <View style={styles.listEntryContent}>
            <Text style={styles.cardTitle}>{t('files.title')}</Text>
            <View style={styles.listEntryRight}>
              <Text style={styles.fileCountText}>{fileCount} {t('files.files_count')}</Text>
              <Text style={styles.chevronIcon}>→</Text>
            </View>
          </View>
        </TouchableOpacity>

        {/* Microphone gain settings */}
        <TouchableOpacity style={styles.card} onPress={handleMicGainSetting}>
          <View style={styles.listEntryContent}>
            <Text style={styles.cardTitle}>{t('device.mic_gain')}</Text>
            <View style={styles.listEntryRight}>
              <Text style={styles.fileCountText}>{deviceInfo.micGain}</Text>
              <Text style={styles.chevronIcon}>→</Text>
            </View>
          </View>
        </TouchableOpacity>

        {/* Advanced features card */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>{t('device.functions')}</Text>
          
          <View style={styles.cardContent}>
            {/* First row */}
            <View style={styles.buttonRow}>
              <TouchableOpacity
                style={[styles.button, styles.buttonOutlined]}
                onPress={handleGetStatus}
                disabled={loading}
              >
                <Text style={styles.buttonTextOutlined}>{t('device.get_status')}</Text>
              </TouchableOpacity>
              
              <TouchableOpacity
                style={[styles.button, styles.buttonOutlined]}
                onPress={loadFileCount}
                disabled={loading}
              >
                <Text style={styles.buttonTextOutlined}>{t('device.get_files')}</Text>
              </TouchableOpacity>
            </View>
            
            {/* Second row - WiFi features temporarily hidden, under development */}
            {/* <View style={styles.buttonRow}>
              <TouchableOpacity
                style={[styles.button, styles.buttonOutlined]}
                onPress={handleWifiDomain}
                disabled={loading}
              >
                <Text style={styles.buttonTextOutlined}>{t('device.wifi_domain')}</Text>
              </TouchableOpacity>
              
              <TouchableOpacity
                style={[styles.button, styles.buttonOutlined]}
                onPress={handleWifiCloud}
                disabled={loading}
              >
                <Text style={styles.buttonTextOutlined}>{t('device.wifi_cloud')}</Text>
              </TouchableOpacity>
            </View> */}

            {/* WiFi transfer - under development, temporarily hidden */}
            {/* <TouchableOpacity
              style={[styles.button, styles.buttonOutlined, styles.fullWidthButton]}
              onPress={handleWifiTransfer}
              disabled={loading}
            >
              <Text style={styles.buttonTextOutlined}>📶 WiFi Transfer</Text>
            </TouchableOpacity> */}
            
            {/* Third row - cloud features temporarily hidden, under development */}
            {/* <View style={styles.buttonRow}>
              <TouchableOpacity
                style={[styles.button, styles.buttonOutlined]}
                onPress={handleBindCloud}
                disabled={loading}
              >
                <Text style={styles.buttonTextOutlined}>{t('device.bind_cloud')}</Text>
              </TouchableOpacity>
              
              <TouchableOpacity
                style={[styles.button, styles.buttonOutlined]}
                onPress={handleUnbindCloud}
                disabled={loading}
              >
                <Text style={styles.buttonTextOutlined}>{t('device.unbind_cloud')}</Text>
              </TouchableOpacity>
            </View> */}
            
            {/* Fourth row */}
            <View style={styles.buttonRow}>
              <TouchableOpacity
                style={[styles.button, styles.buttonOutlined]}
                onPress={handleUnpair}
                disabled={loading}
              >
                <Text style={[styles.buttonTextOutlined, { color: '#F44336' }]}>
                  {t('device.unbind')}
                </Text>
              </TouchableOpacity>
              
              <TouchableOpacity
                style={[styles.button, styles.buttonOutlined]}
                onPress={handleDisconnect}
                disabled={loading}
              >
                <Text style={[styles.buttonTextOutlined, { color: '#F44336' }]}>
                  {t('device.disconnect')}
                </Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </ScrollView>

      {/* Microphone gain setting dialog */}
      <Modal
        visible={micGainModalVisible}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setMicGainModalVisible(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>{t('device.set_mic_gain')}</Text>
            
            <View style={styles.sliderContainer}>
              <Text style={styles.sliderLabel}>{t('device.gain_value')}: {tempMicGain}</Text>
              <View style={styles.sliderRow}>
                <Text style={styles.sliderMinMax}>0</Text>
                <View style={styles.sliderWrapper}>
                  {/* Use simple buttons instead of slider here */}
                  <View style={styles.simpleSlider}>
                    <TouchableOpacity 
                      style={styles.sliderButton}
                      onPress={() => setTempMicGain(Math.max(0, tempMicGain - 1))}
                    >
                      <Text style={styles.sliderButtonText}>−</Text>
                    </TouchableOpacity>
                    <Text style={styles.sliderValue}>{tempMicGain}</Text>
                    <TouchableOpacity 
                      style={styles.sliderButton}
                      onPress={() => setTempMicGain(Math.min(30, tempMicGain + 1))}
                    >
                      <Text style={styles.sliderButtonText}>+</Text>
                    </TouchableOpacity>
                  </View>
                </View>
                <Text style={styles.sliderMinMax}>30</Text>
              </View>
            </View>

            <View style={styles.modalButtons}>
              <TouchableOpacity 
                style={[styles.modalButton, styles.cancelButton]}
                onPress={() => setMicGainModalVisible(false)}
              >
                <Text style={styles.cancelButtonText}>{t('common.cancel')}</Text>
              </TouchableOpacity>
              
              <TouchableOpacity 
                style={[styles.modalButton, styles.confirmButton]}
                onPress={saveMicGain}
              >
                <Text style={styles.confirmButtonText}>{t('common.set')}</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* Loading indicator */}
      {loading && (
        <View style={styles.loadingOverlay}>
          <ActivityIndicator size="large" color="#2196F3" />
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  toolbar: {
    flexDirection: 'row',
    alignItems: 'center',
    height: 56,
    backgroundColor: '#FFFFFF',
    paddingHorizontal: 16,
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  backButton: {
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'center',
  },
  backButtonText: {
    fontSize: 24,
    color: '#212121',
  },
  toolbarTitle: {
    flex: 1,
    fontSize: 18,
    fontWeight: '600',
    color: '#212121',
    textAlign: 'center',
  },
  scrollView: {
    flex: 1,
    padding: 16,
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    marginBottom: 16,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212121',
  },
  expandIcon: {
    fontSize: 20,
    color: '#616161',
  },
  cardContent: {
    paddingHorizontal: 16,
    paddingBottom: 16,
  },
  infoText: {
    fontSize: 16,
    color: '#616161',
    marginBottom: 8,
    flex: 1,
  },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  miniButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#2196F3',
    backgroundColor: 'transparent',
  },
  miniButtonText: {
    color: '#2196F3',
    fontSize: 12,
    fontWeight: '500',
  },
  switchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  recordStatus: {
    fontSize: 16,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: 16,
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  button: {
    flex: 1,
    height: 56,
    justifyContent: 'center',
    alignItems: 'center',
    borderRadius: 4,
    marginHorizontal: 4,
  },
  fullWidthButton: {
    marginHorizontal: 0,
    marginBottom: 8,
  },
  buttonOutlined: {
    borderWidth: 1,
    borderColor: '#2196F3',
    backgroundColor: 'transparent',
  },
  buttonDisabled: {
    borderColor: '#E0E0E0',
    backgroundColor: '#F5F5F5',
  },
  buttonTextOutlined: {
    color: '#2196F3',
    fontSize: 14,
    fontWeight: '500',
  },
  buttonTextDisabled: {
    color: '#9E9E9E',
  },
  listEntryContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
  },
  listEntryRight: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  fileCountText: {
    fontSize: 16,
    color: '#616161',
    marginRight: 8,
  },
  chevronIcon: {
    fontSize: 20,
    color: '#616161',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 24,
    width: '90%',
    maxWidth: 400,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#212121',
    textAlign: 'center',
    marginBottom: 24,
  },
  sliderContainer: {
    marginBottom: 24,
  },
  sliderLabel: {
    fontSize: 16,
    color: '#212121',
    textAlign: 'center',
    marginBottom: 16,
  },
  sliderRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  sliderMinMax: {
    fontSize: 14,
    color: '#616161',
    minWidth: 24,
    textAlign: 'center',
  },
  sliderWrapper: {
    flex: 1,
    marginHorizontal: 16,
  },
  simpleSlider: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  sliderButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#2196F3',
    justifyContent: 'center',
    alignItems: 'center',
    marginHorizontal: 16,
  },
  sliderButtonText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: 'bold',
  },
  sliderValue: {
    fontSize: 20,
    fontWeight: '600',
    color: '#212121',
    minWidth: 40,
    textAlign: 'center',
  },
  modalButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  modalButton: {
    flex: 1,
    height: 44,
    borderRadius: 4,
    justifyContent: 'center',
    alignItems: 'center',
    marginHorizontal: 8,
  },
  cancelButton: {
    borderWidth: 1,
    borderColor: '#E0E0E0',
    backgroundColor: 'transparent',
  },
  confirmButton: {
    backgroundColor: '#2196F3',
  },
  cancelButtonText: {
    color: '#616161',
    fontSize: 16,
    fontWeight: '500',
  },
  confirmButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  loadingOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.3)',
  },
});

export default DeviceFeatureScreen;
