import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  FlatList,
  StyleSheet,
  Alert,
  ActivityIndicator,
  Platform,
  PermissionsAndroid,
} from 'react-native';
import { useTranslation } from 'react-i18next';
import { PlaudBluetooth, PlaudSDK } from '../../js/PlaudSDK';

interface Device {
  id: string;
  name: string;
  serialNumber: string;
  macAddress: string;
  rssi: number;
}

interface DeviceListScreenProps {
  onDeviceConnected: (device: Device) => void;
}

const DeviceListScreen: React.FC<DeviceListScreenProps> = ({ onDeviceConnected }) => {
  const { t } = useTranslation();
  const [devices, setDevices] = useState<Device[]>([]);
  const [scanning, setScanning] = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [connectingDeviceId, setConnectingDeviceId] = useState<string>('');

  useEffect(() => {
    // SDK already initialized in IntroScreen, start scanning directly
    console.log('DeviceListScreen loaded, starting auto scan...');
    startScan();
    
    return () => {
      // Clean up resources
      if (scanning) {
        stopScan();
      }
    };
  }, []);

  const startScan = async () => {
    if (scanning) return;

    // Android platform needs to check and request permissions first
    if (Platform.OS === 'android') {
      try {
        console.log('[Android] Checking permission status...');

        // Request required permissions
        const permissions = [
          PermissionsAndroid.PERMISSIONS.BLUETOOTH_SCAN,
          PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT,
          PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
          PermissionsAndroid.PERMISSIONS.ACCESS_COARSE_LOCATION
        ];

        const granted = await PermissionsAndroid.requestMultiple(permissions);
        console.log('[Android] Permission status:', granted);

        // Check if all permissions are granted
        const allGranted = Object.values(granted).every(
          status => status === PermissionsAndroid.RESULTS.GRANTED
        );

        if (!allGranted) {
          Alert.alert(t('permissions.bluetooth_required'), t('permissions.location_required'));
          return;
        }
      } catch (error) {
        console.error('[Android] Permission request failed:', error);
        Alert.alert(t('common.error'), t('permissions.permission_denied'));
        return;
      }
    }

    setScanning(true);
    setDevices([]);
    
    try {
      console.log('Starting device scan...');
      
      // Add device discovery listener
      PlaudBluetooth.addListener('onDeviceFound', (device: Device) => {
        console.log('Device discovered:', device);
        setDevices(prev => {
          const exists = prev.some(d => d.id === device.id);
          if (!exists) {
            console.log('Added new device to list:', device.name || device.id);
            return [...prev, device];
          }
          return prev.map(d => d.id === device.id ? device : d);
        });
      });

      const result = await PlaudBluetooth.startScan();
      console.log('Scan result:', result);
      
      if (!result.success) {
        Alert.alert(t('bluetooth.scan_error'), result.message || t('errors.unknown_error'));
        setScanning(false);
      }
    } catch (error: any) {
      console.error('Scan exception:', error);
      Alert.alert(t('bluetooth.scan_error'), `Scan exception: ${error.message}`);
      setScanning(false);
    }
  };

  const stopScan = async () => {
    try {
      await PlaudBluetooth.stopScan();
      setScanning(false);
    } catch (error) {
      console.error('Stop scan failed:', error);
    }
  };

  const connectDevice = async (device: Device) => {
    if (connecting) return;
    
    setConnecting(true);
    setConnectingDeviceId(device.id);
    
    // Listen for connection completion events
    const deviceConnectedListener = PlaudBluetooth.addListener('onDeviceConnected', (data: any) => {
      console.log('Received onDeviceConnected event:', data);
      if (data.success) {
        console.log('Device connection successful:', data);
        deviceConnectedListener.remove();
        Alert.alert(t('common.success'), t('bluetooth.connected'));
        onDeviceConnected(device);
        setConnecting(false);
        setConnectingDeviceId('');
      } else {
        console.log('Connection event success is false:', data);
      }
    });
    
    // Listen for connection failure during connection attempt
    const deviceDisconnectedListener = PlaudBluetooth.addListener('onDeviceDisconnected', () => {
      deviceConnectedListener.remove();
      deviceDisconnectedListener.remove();
      // Reset connection state without showing popup
      if (connecting) {
        console.log('Connection failed: device disconnected during connection attempt');
        setConnecting(false);
        setConnectingDeviceId('');
      }
    });
    
    try {
      // Stop scanning
      if (scanning) {
        await stopScan();
      }
      
      const token = device.serialNumber || device.id;
      const result = await PlaudBluetooth.connect(device.serialNumber || device.id, token, {});
      
      if (!result.success) {
        deviceConnectedListener.remove();
        deviceDisconnectedListener.remove();
        console.log('Connection failed:', result.message || 'Unknown error');
        setConnecting(false);
        setConnectingDeviceId('');
      }
      // Wait for onDeviceConnected event on success
    } catch (error: any) {
      deviceConnectedListener.remove();
      deviceDisconnectedListener.remove();
      console.log('Connection error:', error.message);
      setConnecting(false);
      setConnectingDeviceId('');
    }
  };

  const getRssiIcon = (rssi: number) => {
    if (rssi > -50) return '📶';
    if (rssi > -70) return '📶';
    if (rssi > -80) return '📶';
    return '📶';
  };

  const getRssiColor = (rssi: number) => {
    if (rssi > -50) return '#4CAF50'; // Strong signal - green
    if (rssi > -70) return '#FF9800'; // Medium signal - orange
    return '#F44336'; // Weak signal - red
  };

  const renderDevice = ({ item }: { item: Device }) => (
    <TouchableOpacity
      style={[
        styles.deviceItem,
        connecting && connectingDeviceId === item.id && styles.deviceItemConnecting
      ]}
      onPress={() => connectDevice(item)}
      disabled={connecting}
    >
      <View style={styles.deviceInfo}>
        <Text style={styles.deviceName}>{item.name || t('bluetooth.device_found')}</Text>
        <Text style={styles.deviceSn}>SN: {item.serialNumber}</Text>
        <Text style={styles.deviceMac}>MAC: {item.macAddress}</Text>
      </View>
      
      <View style={styles.deviceMeta}>
        <View style={styles.rssiContainer}>
          <Text style={[styles.rssiIcon, { color: getRssiColor(item.rssi) }]}>
            {getRssiIcon(item.rssi)}
          </Text>
          <Text style={styles.rssiText}>{item.rssi}dBm</Text>
        </View>
        
        {connecting && connectingDeviceId === item.id ? (
          <ActivityIndicator size="small" color="#2196F3" />
        ) : (
          <Text style={styles.connectText}>{t('bluetooth.connecting')}</Text>
        )}
      </View>
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      {/* Toolbar */}
      <View style={styles.toolbar}>
        <Text style={styles.toolbarTitle}>{t('bluetooth.device_info')}</Text>
      </View>

      {/* Status bar */}
      <View style={styles.statusBar}>
        <View style={styles.statusLeft}>
          <Text style={styles.statusText}>
            {scanning ? t('bluetooth.scanning') : `${devices.length} devices found`}
          </Text>
          {scanning && (
            <ActivityIndicator 
              size="small" 
              color="#2196F3" 
              style={styles.scanningIndicator}
            />
          )}
        </View>
        
        <TouchableOpacity
          style={[styles.scanButton, scanning && styles.scanButtonActive]}
          onPress={scanning ? stopScan : startScan}
          disabled={connecting}
        >
          <Text style={[styles.scanButtonText, scanning && styles.scanButtonTextActive]}>
            {scanning ? 'Stop Scan' : 'Restart Scan'}
          </Text>
        </TouchableOpacity>
      </View>

      {/* Device list */}
      <View style={styles.deviceListContainer}>
        <FlatList
          data={devices}
          renderItem={renderDevice}
          keyExtractor={(item) => item.id}
          style={styles.deviceList}
          showsVerticalScrollIndicator={true}
          nestedScrollEnabled={true}
          removeClippedSubviews={false}
          initialNumToRender={10}
          maxToRenderPerBatch={10}
          windowSize={10}
          getItemLayout={(data, index) => ({
            length: 100,
            offset: 100 * index,
            index,
          })}
        />
      </View>

      {/* Connection status indicator - only show when connecting */}
      {connecting && (
        <View style={styles.connectingOverlay}>
          <View style={styles.connectingContent}>
            <ActivityIndicator size="large" color="#2196F3" />
            <Text style={styles.connectingText}>{t('bluetooth.connecting')}...</Text>
          </View>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5', // background_secondary
  },
  toolbar: {
    height: 56,
    backgroundColor: '#FFFFFF',
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  toolbarTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#212121',
  },
  statusBar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  statusLeft: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusText: {
    fontSize: 16,
    color: '#616161',
  },
  scanningIndicator: {
    marginLeft: 8,
  },
  scanButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#2196F3',
  },
  scanButtonActive: {
    backgroundColor: '#2196F3',
  },
  scanButtonText: {
    color: '#2196F3',
    fontSize: 14,
    fontWeight: '500',
  },
  scanButtonTextActive: {
    color: '#FFFFFF',
  },
  deviceListContainer: {
    flex: 1,
    padding: 16,
  },
  deviceList: {
    flex: 1,
  },
  deviceItem: {
    flexDirection: 'row',
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    marginBottom: 8,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  deviceItemConnecting: {
    borderColor: '#2196F3',
    borderWidth: 2,
  },
  deviceInfo: {
    flex: 1,
  },
  deviceName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212121',
    marginBottom: 4,
  },
  deviceSn: {
    fontSize: 14,
    color: '#616161',
    marginBottom: 2,
  },
  deviceMac: {
    fontSize: 12,
    color: '#9E9E9E',
  },
  deviceMeta: {
    alignItems: 'flex-end',
    justifyContent: 'space-between',
  },
  rssiContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  rssiIcon: {
    fontSize: 16,
    marginRight: 4,
  },
  rssiText: {
    fontSize: 12,
    color: '#616161',
  },
  connectText: {
    fontSize: 12,
    color: '#2196F3',
    fontWeight: '500',
  },
  connectingOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  connectingContent: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 24,
    alignItems: 'center',
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
  },
  connectingText: {
    fontSize: 16,
    color: '#212121',
    marginTop: 16,
    fontWeight: '500',
  },
});

export default DeviceListScreen;
