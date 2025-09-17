import React, { useState, useEffect } from 'react';
import { View, StyleSheet, BackHandler } from 'react-native';
import IntroScreen from '../screens/IntroScreen';
import DeviceListScreen from '../screens/DeviceListScreen';
import DeviceFeatureScreen from '../screens/DeviceFeatureScreen';
import FileListScreen from '../screens/FileListScreen';

export type Screen = 'Intro' | 'DeviceList' | 'DeviceFeature' | 'FileList';

interface Device {
  id: string;
  name: string;
  serialNumber: string;
  macAddress: string;
  rssi: number;
}

const Navigator: React.FC = () => {
  const [currentScreen, setCurrentScreen] = useState<Screen>('Intro');
  const [connectedDevice, setConnectedDevice] = useState<Device | null>(null);

  // Handle Android back button
  useEffect(() => {
    const backAction = () => {
      if (currentScreen === 'Intro') {
        // On home screen, allow app exit
        return false;
      } else {
        // Other pages perform step-by-step return
        navigateBack();
        return true; // Prevent default back behavior
      }
    };

    const backHandler = BackHandler.addEventListener('hardwareBackPress', backAction);

    return () => backHandler.remove();
  }, [currentScreen]);

  const navigateToDeviceList = () => {
    setCurrentScreen('DeviceList');
  };

  const navigateToDeviceFeature = (device: Device) => {
    setConnectedDevice(device);
    setCurrentScreen('DeviceFeature');
  };

  const navigateToFileList = () => {
    setCurrentScreen('FileList');
  };

  const navigateToIntro = () => {
    setConnectedDevice(null);
    setCurrentScreen('Intro');
  };

  const navigateBack = () => {
    switch (currentScreen) {
      case 'FileList':
        setCurrentScreen('DeviceFeature');
        break;
      case 'DeviceFeature':
        navigateToDeviceList();
        break;
      case 'DeviceList':
        navigateToIntro();
        break;
      default:
        break;
    }
  };

  const renderCurrentScreen = () => {
    switch (currentScreen) {
      case 'Intro':
        return (
          <IntroScreen
            onStartScan={navigateToDeviceList}
          />
        );
      
      case 'DeviceList':
        return (
          <DeviceListScreen
            onDeviceConnected={navigateToDeviceFeature}
          />
        );
      
      case 'DeviceFeature':
        return connectedDevice ? (
          <DeviceFeatureScreen
            device={connectedDevice}
            onNavigateToFiles={navigateToFileList}
            onDisconnect={navigateToDeviceList}
          />
        ) : null;
      
      case 'FileList':
        return (
          <FileListScreen
            onBack={navigateBack}
          />
        );
      
      default:
        return (
          <IntroScreen
            onStartScan={navigateToDeviceList}
          />
        );
    }
  };

  return (
    <View style={styles.container}>
      {renderCurrentScreen()}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});

export default Navigator;
