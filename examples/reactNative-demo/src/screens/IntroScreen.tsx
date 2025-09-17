import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  Modal,
  TextInput,
  StatusBar,
  FlatList,
  ActivityIndicator,
} from 'react-native';
import { useTranslation } from 'react-i18next';
import { PlaudSDK, PlaudEnvironment } from '../../js/PlaudSDK';

interface IntroScreenProps {
  onStartScan: () => void;
}

const IntroScreen: React.FC<IntroScreenProps> = ({ onStartScan }) => {
  const { t } = useTranslation();
  const [appKeyModalVisible, setAppKeyModalVisible] = useState(false);
  const [envModalVisible, setEnvModalVisible] = useState(false);
  const [appKey, setAppKey] = useState('');
  const [appSecret, setAppSecret] = useState('');
  const [currentEnv, setCurrentEnv] = useState<any>(null);
  const [allEnvironments, setAllEnvironments] = useState<any[]>([]);
  const [initializing, setInitializing] = useState(false);
  const [longPressTimer, setLongPressTimer] = useState<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    initializeApp();
  }, []);

  const initializeApp = async () => {
    try {
      setInitializing(true);
      console.log('🚀 IntroScreen starting initialization...');
      
      // 1. Load environment configuration
      const env = await PlaudEnvironment.getCurrentEnvironment();
      setCurrentEnv(env);
      setAppKey(env.appKey || '');
      setAppSecret(env.appSecret || '');
      console.log('✅ Environment configuration loaded successfully:', env.displayName);
      
      // 2. Load all available environments
      const environments = await PlaudEnvironment.getAllEnvironments();
      setAllEnvironments(environments);
      console.log('✅ All environments loaded successfully:', environments.length);
      
      // 3. Initialize SDK
      await PlaudSDK.initialize();
      console.log('✅ SDK initialization successful');
      
      setInitializing(false);
    } catch (error) {
      console.error('❌ Application initialization failed:', error);
      setInitializing(false);
      Alert.alert(t('errors.sdk_init_failed'), t('errors.unknown_error'));
    }
  };

  const handleSetAppKey = () => {
    setAppKeyModalVisible(true);
  };

  const saveAppKey = async () => {
    if (!appKey.trim() || !appSecret.trim()) {
      Alert.alert(t('common.error'), 'App Key and App Secret cannot be empty');
      return;
    }

    try {
      // Logic for saving custom App Key can be added here
      Alert.alert(t('common.success'), 'App Key settings saved successfully');
      setAppKeyModalVisible(false);
    } catch (error) {
      Alert.alert(t('common.error'), 'Failed to save settings');
    }
  };



  const handleStartScan = () => {
    console.log('🔍 User clicked start scan, navigating to device list page');
    onStartScan();
  };

  // Long press title start
  const handleTitlePressIn = () => {
    const timer = setTimeout(() => {
      console.log('🔧 Long press 5 seconds detected, showing environment switch modal');
      setEnvModalVisible(true);
    }, 5000); // 5 seconds
    setLongPressTimer(timer);
  };

  // Long press title end or cancel
  const handleTitlePressOut = () => {
    if (longPressTimer) {
      clearTimeout(longPressTimer);
      setLongPressTimer(null);
    }
  };

  // Switch environment
  const handleSwitchEnvironment = async (env: any) => {
    try {
      setInitializing(true);
      setEnvModalVisible(false);
      
      console.log('🔄 Starting environment switch to:', env.displayName);
      
      // 1. Switch environment configuration
      const result = await PlaudEnvironment.setEnvironment(env.name);
      if (!result.success) {
        throw new Error(result.message);
      }
      console.log('✅ Environment configuration switched successfully:', result);
      
      // 2. Update UI state
      setCurrentEnv(env);
      setAppKey(env.appKey || '');
      setAppSecret(env.appSecret || '');
      
      // 3. Verify environment configuration is correctly updated
      console.log('🔍 Verifying current environment configuration...');
      const verifyEnv = await PlaudEnvironment.getCurrentEnvironment();
      console.log('🔍 Current environment configuration:', {
        name: verifyEnv.name,
        displayName: verifyEnv.displayName,
        appKey: verifyEnv.appKey,
        appSecret: verifyEnv.appSecret?.substring(0, 10) + '...'
      });
      
      // 4. Re-initialize SDK (environment configuration updated, just need to re-initialize SDK)
      console.log('🔄 Re-initializing SDK...');
      await PlaudSDK.initialize();
      console.log('✅ SDK re-initialization successful');
      
      setInitializing(false);
      Alert.alert(t('environment.switch_success'), `Switched to ${env.displayName}, all configurations updated`);
      
    } catch (error: any) {
      console.error('❌ Environment switch failed:', error);
      setInitializing(false);
      Alert.alert(t('environment.switch_error'), error.message || 'Environment switch failed, please try again');
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#FFFFFF" />
      
      {/* Main content area */}
      <View style={styles.mainContent}>
        <TouchableOpacity
          style={styles.titleContainer}
          onPressIn={handleTitlePressIn}
          onPressOut={handleTitlePressOut}
          activeOpacity={1}
        >
          <Text style={styles.title}>{t('welcome.title')}</Text>
        </TouchableOpacity>
        <Text style={styles.subtitle}>
          {t('welcome.subtitle')}
        </Text>

        {/* Environment info - hidden display, but keep long press switch functionality */}
        {/* currentEnv && (
          <View style={styles.envInfo}>
            <Text style={styles.envText}>{t('environment.current')}: {currentEnv.displayName}</Text>
          </View>
        ) */}

        {/* Function buttons */}
        <TouchableOpacity style={styles.button} onPress={handleSetAppKey}>
          <Text style={styles.buttonText}>Set App Key</Text>
        </TouchableOpacity>

      </View>

      {/* Start scan button */}
      <TouchableOpacity 
        style={[styles.startButton, initializing && styles.disabledButton]} 
        onPress={handleStartScan}
        disabled={initializing}
      >
        {initializing ? (
          <ActivityIndicator color="#FFFFFF" size="small" />
        ) : (
          <Text style={styles.startButtonText}>{t('welcome.scan_devices')}</Text>
        )}
      </TouchableOpacity>


      {/* App Key settings dialog */}
      <Modal
        visible={appKeyModalVisible}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setAppKeyModalVisible(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Set App Key</Text>
            
            <Text style={styles.inputLabel}>App Key:</Text>
            <TextInput
              style={styles.textInput}
              value={appKey}
              onChangeText={setAppKey}
              placeholder="Enter App Key"
              multiline={false}
            />
            
            <Text style={styles.inputLabel}>App Secret:</Text>
            <TextInput
              style={styles.textInput}
              value={appSecret}
              onChangeText={setAppSecret}
              placeholder="Enter App Secret"
              multiline={false}
            />

            <View style={styles.modalButtons}>
              <TouchableOpacity 
                style={[styles.modalButton, styles.cancelButton]}
                onPress={() => setAppKeyModalVisible(false)}
              >
                <Text style={styles.cancelButtonText}>{t('common.cancel')}</Text>
              </TouchableOpacity>
              
              <TouchableOpacity 
                style={[styles.modalButton, styles.confirmButton]}
                onPress={saveAppKey}
              >
                <Text style={styles.confirmButtonText}>{t('common.save')}</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* Environment selection dialog */}
      <Modal
        visible={envModalVisible}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setEnvModalVisible(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>{t('environment.title')}</Text>
            <Text style={styles.envModalSubtitle}>
              {t('environment.current')}: {currentEnv?.displayName || 'Unknown'}
            </Text>
            
            <FlatList
              data={allEnvironments}
              keyExtractor={(item) => item.name}
              renderItem={({ item }) => (
                <TouchableOpacity
                  style={[
                    styles.envItem,
                    currentEnv?.name === item.name && styles.currentEnvItem
                  ]}
                  onPress={() => handleSwitchEnvironment(item)}
                >
                  <View style={styles.envItemContent}>
                    <Text style={[
                      styles.envItemTitle,
                      currentEnv?.name === item.name && styles.currentEnvText
                    ]}>
                      {item.displayName}
                    </Text>
                    <Text style={styles.envItemUrl}>
                      {item.baseUrl}
                    </Text>
                    {currentEnv?.name === item.name && (
                      <Text style={styles.currentLabel}>Current</Text>
                    )}
                  </View>
                </TouchableOpacity>
              )}
              style={styles.envList}
            />

            <View style={styles.modalButtons}>
              <TouchableOpacity 
                style={[styles.modalButton, styles.cancelButton]}
                onPress={() => setEnvModalVisible(false)}
              >
                <Text style={styles.cancelButtonText}>{t('common.cancel')}</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
    paddingHorizontal: 32,
    justifyContent: 'center',
  },
  mainContent: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  titleContainer: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 8,
  },
  title: {
    fontSize: 36,
    fontWeight: 'bold',
    color: '#212121',
    textAlign: 'center',
    marginBottom: 16,
  },
  subtitle: {
    fontSize: 16,
    color: '#616161',
    textAlign: 'center',
    marginBottom: 32,
  },
  envInfo: {
    backgroundColor: '#E3F2FD',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
    marginBottom: 32,
  },
  envText: {
    fontSize: 14,
    color: '#1976D2',
    textAlign: 'center',
  },
  button: {
    width: '100%',
    height: 56,
    borderWidth: 1,
    borderColor: '#2196F3',
    borderRadius: 4,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
    backgroundColor: 'transparent',
  },
  buttonText: {
    fontSize: 16,
    color: '#2196F3',
    fontWeight: '500',
  },
  startButton: {
    width: '100%',
    height: 56,
    backgroundColor: '#2196F3',
    borderRadius: 4,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 24,
    marginTop: 24,
  },
  startButtonText: {
    fontSize: 16,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  disabledButton: {
    backgroundColor: '#BDBDBD',
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
  inputLabel: {
    fontSize: 14,
    color: '#616161',
    marginBottom: 8,
    marginTop: 16,
  },
  textInput: {
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 4,
    padding: 12,
    fontSize: 16,
    color: '#212121',
    backgroundColor: '#FAFAFA',
  },
  modalButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 24,
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
  // Environment selection modal styles
  envModalSubtitle: {
    fontSize: 14,
    color: '#616161',
    textAlign: 'center',
    marginBottom: 16,
  },
  envList: {
    maxHeight: 200,
    marginBottom: 16,
  },
  envItem: {
    padding: 16,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#E0E0E0',
    marginBottom: 8,
    backgroundColor: '#FAFAFA',
  },
  currentEnvItem: {
    borderColor: '#2196F3',
    backgroundColor: '#E3F2FD',
  },
  envItemContent: {
    flexDirection: 'column',
  },
  envItemTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212121',
    marginBottom: 4,
  },
  currentEnvText: {
    color: '#2196F3',
  },
  envItemUrl: {
    fontSize: 12,
    color: '#616161',
    marginBottom: 4,
  },
  currentLabel: {
    fontSize: 12,
    color: '#2196F3',
    fontWeight: 'bold',
    alignSelf: 'flex-end',
  },
});

export default IntroScreen;
