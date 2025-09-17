/**
 * Plaud React Native SDK
 * Main SDK interface
 */

import { NativeModules, NativeEventEmitter, Platform } from 'react-native';
import { EnvironmentManager } from '../src/config/environments';

// Check for supported platforms
if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
  throw new Error('Plaud SDK currently only supports Android and iOS platforms');
}

// Import native modules
const {
  PlaudSDK: PlaudSDKNative,
  PlaudBluetooth: PlaudBluetoothNative,
  PlaudRecording: PlaudRecordingNative,
  PlaudFileManager: PlaudFileManagerNative,
  PlaudUpload: PlaudUploadNative,
  PlaudPermissionModule: PlaudPermissionNative,
  PlaudEnvironmentModule: PlaudEnvironmentNative
} = NativeModules;

// Check if native modules are available - don't throw errors, allow app to start
const isNativeModuleAvailable = !!PlaudSDKNative;
console.log('Native modules availability:', {
  PlaudSDK: !!PlaudSDKNative,
  PlaudBluetooth: !!PlaudBluetoothNative,
  PlaudRecording: !!PlaudRecordingNative,
  PlaudFileManager: !!PlaudFileManagerNative,
  PlaudUpload: !!PlaudUploadNative
});

// Create event emitter - only when modules are available
const PlaudSDKEmitter = PlaudSDKNative ? new NativeEventEmitter(PlaudSDKNative) : null;
const PlaudBluetoothEmitter = PlaudBluetoothNative ? new NativeEventEmitter(PlaudBluetoothNative) : null;
const PlaudRecordingEmitter = PlaudRecordingNative ? new NativeEventEmitter(PlaudRecordingNative) : null;
const PlaudFileManagerEmitter = PlaudFileManagerNative ? new NativeEventEmitter(PlaudFileManagerNative) : null;
const PlaudUploadEmitter = PlaudUploadNative ? new NativeEventEmitter(PlaudUploadNative) : null;

/**
 * Core SDK module
 */
export const PlaudSDK = {
  // Environment constants
  ENVIRONMENT: {
    CHINA_PROD: 'CHINA_PROD',
    US_PROD: 'US_PROD',
    US_TEST: 'US_TEST',
    COMMON_TEST: 'COMMON_TEST'
  },

  /**
   * Initialize SDK
   */
  async initSdk(options) {
    if (!PlaudSDKNative) {
      throw new Error('PlaudSDK native module is not available. Make sure you have properly linked the Plaud SDK.');
    }
    
    if (!options.appKey || !options.appSecret) {
      throw new Error('appKey and appSecret are required');
    }
    return PlaudSDKNative.initSdk(options);
  },

  /**
   * Convenient initialization method - automatically uses current environment configuration
   */
  async initialize() {
    if (!PlaudSDKNative) {
      throw new Error('PlaudSDK native module is not available. Make sure you have properly linked the Plaud SDK.');
    }
    
    try {
      // Get current environment configuration
      const currentEnv = await EnvironmentManager.getCurrentEnvironment();
      console.log('🔧 SDK initialization using environment:', currentEnv.displayName);
      console.log('🔧 SDK initialization config:', {
        appKey: currentEnv.appKey,
        appSecret: currentEnv.appSecret?.substring(0, 10) + '...',
        environment: currentEnv.serverEnvironment
      });
      
      // Initialize SDK using current environment configuration
      const options = {
        appKey: currentEnv.appKey,
        appSecret: currentEnv.appSecret,
        environment: currentEnv.serverEnvironment
      };
      
      const result = await PlaudSDKNative.initSdk(options);
      console.log('🔧 SDK initialization result:', result);
      return result;
    } catch (error) {
      console.error('SDK initialization failed:', error);
      throw error;
    }
  },

  /**
   * User login
   */
  async login(appKey, appSecret) {
    if (!PlaudSDKNative) {
      throw new Error('PlaudSDK native module is not available.');
    }
    return PlaudSDKNative.login(appKey, appSecret);
  },

  /**
   * User logout
   */
  async logout() {
    return PlaudSDKNative.logout();
  },

  /**
   * Check if logged in
   */
  async isLoggedIn() {
    return PlaudSDKNative.isLoggedIn();
  },

  /**
   * Switch server environment
   */
  async switchEnvironment(environment) {
    return PlaudSDKNative.switchEnvironment(environment);
  },

  /**
   * Get current environment info
   */
  async getCurrentEnvironment() {
    return PlaudSDKNative.getCurrentEnvironment();
  },

  /**
   * Bind device
   */
  async bindDevice(ownerId, sn, snType) {
    return PlaudSDKNative.bindDevice(ownerId, sn, snType);
  },

  /**
   * Unbind device
   */
  async unbindDevice(ownerId, sn, snType) {
    return PlaudSDKNative.unbindDevice(ownerId, sn, snType);
  },

  // Event listeners
  addListener: (eventName, callback) => {
    if (!PlaudSDKEmitter) {
      console.warn('PlaudSDK native module not available, event listeners will not work');
      return { remove: () => {} };
    }
    return PlaudSDKEmitter.addListener(eventName, callback);
  },
  removeListener: (eventName, listener) => {
    if (PlaudSDKEmitter) {
      PlaudSDKEmitter.removeListener(eventName, listener);
    }
  },
  removeAllListeners: (eventName) => {
    if (PlaudSDKEmitter) {
      PlaudSDKEmitter.removeAllListeners(eventName);
    }
  },
};

/**
 * Bluetooth module
 */
export const PlaudBluetooth = {
  /**
   * Start scanning devices
   */
  async startScan(options = {}) {
    if (!PlaudBluetoothNative) {
      throw new Error('PlaudBluetooth native module is not available.');
    }
    return PlaudBluetoothNative.startScan(options);
  },

  /**
   * Stop scanning
   */
  async stopScan() {
    return PlaudBluetoothNative.stopScan();
  },

  /**
   * Connect to device
   */
  async connect(serialNumber, token, options = {}) {
    return PlaudBluetoothNative.connect(serialNumber, token, options);
  },

  /**
   * Connect to device (convenient method)
   */
  async connectDevice(deviceId, token = '', options = {}) {
    return PlaudBluetoothNative.connect(deviceId, token, options);
  },

  /**
   * Disconnect
   */
  async disconnect() {
    return PlaudBluetoothNative.disconnect();
  },

  /**
   * Disconnect (convenient method)
   */
  async disconnectDevice() {
    return PlaudBluetoothNative.disconnect();
  },

  /**
   * Get device status
   */
  async getDeviceState() {
    return PlaudBluetoothNative.getDeviceState();
  },

  /**
   * Check if connected
   */
  async isConnected() {
    return PlaudBluetoothNative.isConnected();
  },

  /**
   * Check if Bluetooth is available
   */
  async isBluetoothAvailable() {
    return PlaudBluetoothNative.isBluetoothAvailable();
  },

  /**
   * Get Bluetooth manager status (for debugging)
   */
  async getBluetoothManagerStatus() {
    return PlaudBluetoothNative.getBluetoothManagerStatus();
  },

  // Event listeners
  addListener: (eventName, callback) => {
    if (!PlaudBluetoothEmitter) {
      console.warn('PlaudBluetooth native module not available, event listeners will not work');
      return { remove: () => {} };
    }
    return PlaudBluetoothEmitter.addListener(eventName, callback);
  },
  removeListener: (eventName, listener) => {
    if (PlaudBluetoothEmitter) {
      PlaudBluetoothEmitter.removeListener(eventName, listener);
    }
  },
  removeAllListeners: (eventName) => {
    if (PlaudBluetoothEmitter) {
      PlaudBluetoothEmitter.removeAllListeners(eventName);
    }
  },
};

/**
 * Recording module
 */
export const PlaudRecording = {
  /**
   * Start recording (recommended)
   */
  async startRecording(deviceId, options = {}) {
    const sessionId = options.sessionId || Date.now();
    return PlaudRecordingNative.startRecording(deviceId, { ...options, sessionId });
  },

  /**
   * Stop recording (recommended)
   */
  async stopRecording() {
    return PlaudRecordingNative.stopRecording();
  },

  /**
   * Pause recording
   */
  async pauseRecording() {
    return PlaudRecordingNative.pauseRecording();
  },

  /**
   * Resume recording
   */
  async resumeRecording() {
    return PlaudRecordingNative.resumeRecording();
  },

  /**
   * Get recording status
   */
  async getRecordingStatus() {
    return PlaudRecordingNative.getRecordingStatus();
  },

  // Event listeners
  addListener: (eventName, callback) => {
    if (!PlaudRecordingEmitter) {
      console.warn('PlaudRecording native module not available, event listeners will not work');
      return { remove: () => {} };
    }
    return PlaudRecordingEmitter.addListener(eventName, callback);
  },
  removeListener: (eventName, listener) => {
    if (PlaudRecordingEmitter) {
      PlaudRecordingEmitter.removeListener(eventName, listener);
    }
  },
  removeAllListeners: (eventName) => {
    if (PlaudRecordingEmitter) {
      PlaudRecordingEmitter.removeAllListeners(eventName);
    }
  },
};

/**
 * File management module
 */
export const PlaudFileManager = {
  /**
   * Get file list
   */
  async getFileList() {
    return PlaudFileManagerNative.getFileList();
  },

  /**
   * Get storage info
   */
  async getStorageInfo() {
    return PlaudFileManagerNative.getStorageInfo();
  },

  /**
   * Get device status
   */
  async getDeviceState() {
    return PlaudFileManagerNative.getDeviceState();
  },

  /**
   * Get battery status
   */
  async getBatteryStatus() {
    return PlaudFileManagerNative.getBatteryStatus();
  },

  /**
   * Get device version
   */
  async getDeviceVersion() {
    return PlaudFileManagerNative.getDeviceVersion();
  },

  /**
   * Clear all files
   */
  async clearAllFiles() {
    return PlaudFileManagerNative.clearAllFiles();
  },

  /**
   * Download file
   */
  async downloadFile(sessionId, options = {}) {
    return PlaudFileManagerNative.downloadFile(sessionId, options);
  },

  /**
   * Share file
   */
  async shareFile(filePath) {
    return PlaudFileManagerNative.shareFile(filePath);
  },

  /**
   * Delete file
   */
  async deleteFile(sessionId) {
    return PlaudFileManagerNative.deleteFile(sessionId);
  },

  // Event listeners
  addListener: (eventName, callback) => {
    if (!PlaudFileManagerEmitter) {
      console.warn('PlaudFileManager native module not available, event listeners will not work');
      return { remove: () => {} };
    }
    return PlaudFileManagerEmitter.addListener(eventName, callback);
  },
  removeListener: (eventName, listener) => {
    if (PlaudFileManagerEmitter) {
      PlaudFileManagerEmitter.removeListener(eventName, listener);
    }
  },
  removeAllListeners: (eventName) => {
    if (PlaudFileManagerEmitter) {
      PlaudFileManagerEmitter.removeAllListeners(eventName);
    }
  },
};

/**
 * Upload module
 */
export const PlaudUpload = {
  /**
   * Upload file to cloud
   */
  async uploadFile(filePath, options = {}) {
    return PlaudUploadNative.uploadFile(filePath, options);
  },

  // Event listeners
  addListener: (eventName, callback) => {
    if (!PlaudUploadEmitter) {
      console.warn('PlaudUpload native module not available, event listeners will not work');
      return { remove: () => {} };
    }
    return PlaudUploadEmitter.addListener(eventName, callback);
  },
  removeListener: (eventName, listener) => {
    if (PlaudUploadEmitter) {
      PlaudUploadEmitter.removeListener(eventName, listener);
    }
  },
  removeAllListeners: (eventName) => {
    if (PlaudUploadEmitter) {
      PlaudUploadEmitter.removeAllListeners(eventName);
    }
  },
};

/**
 * Utility functions
 */
export const PlaudUtils = {
  /**
   * Remove all event listeners
   */
  removeAllListeners() {
    if (PlaudSDKEmitter) {
      PlaudSDKEmitter.removeAllListeners();
    }
    if (PlaudBluetoothEmitter) {
      PlaudBluetoothEmitter.removeAllListeners();
    }
    if (PlaudRecordingEmitter) {
      PlaudRecordingEmitter.removeAllListeners();
    }
    if (PlaudFileManagerEmitter) {
      PlaudFileManagerEmitter.removeAllListeners();
    }
    if (PlaudUploadEmitter) {
      PlaudUploadEmitter.removeAllListeners();
    }
  },

  /**
   * Get platform info
   */
  getPlatformInfo() {
    return {
      OS: Platform.OS,
      Version: Platform.Version,
      isAndroid: Platform.OS === 'android',
      isIOS: Platform.OS === 'ios',
    };
  },
};


/**
 * Permission management
 */
const PlaudPermission = {
  /**
   * Check permission status
   */
  async checkPermissions() {
    if (!PlaudPermissionNative) {
      throw new Error('PlaudPermissionModule not available');
    }
    return PlaudPermissionNative.checkPermissions();
  },

  /**
   * Request permission
   */
  async requestPermissions() {
    if (!PlaudPermissionNative) {
      throw new Error('PlaudPermissionModule not available');
    }
    return PlaudPermissionNative.requestPermissions();
  },
};

/**
 * Environment management - unified configuration using RN layer
 */
const PlaudEnvironment = {
  /**
   * Get current environment configuration
   */
  async getCurrentEnvironment() {
    return EnvironmentManager.getCurrentEnvironment();
  },

  /**
   * Get all available environments
   */
  async getAllEnvironments() {
    return EnvironmentManager.getAllEnvironments();
  },

  /**
   * Switch environment
   */
  async setEnvironment(envName) {
    return EnvironmentManager.setEnvironment(envName);
  },
};

// Named exports for individual modules
export { PlaudPermission, PlaudEnvironment };

// Default export
export default {
  PlaudSDK,
  PlaudBluetooth,
  PlaudRecording,
  PlaudFileManager,
  PlaudUpload,
  PlaudUtils,
  PlaudPermission,
  PlaudEnvironment,
};
