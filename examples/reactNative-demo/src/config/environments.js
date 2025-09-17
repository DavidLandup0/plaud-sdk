/**
 * Unified environment configuration file
 * All platforms use the same configuration to avoid Android/iOS configuration inconsistencies
 */

import AsyncStorage from '@react-native-async-storage/async-storage';

export const ENVIRONMENTS = {
  development: {
    name: 'development',
    displayName: 'US Production Environment',
    baseUrl: 'https://platform.plaud.ai',
    appKey: 'plaud-rVDQilOD-1749538697969',
    appSecret: 'aksk_3OWsepikIeI3EGsaPSmUUf5TAaNSktEh',
    serverEnvironment: 'US_PROD'
  },
  test: {
    name: 'test', 
    displayName: 'Common Test Environment',
    baseUrl: 'https://platform-beta.plaud.ai',
    appKey: 'plaud-uj5LWcHX-1755488820087',
    appSecret: 'aksk_SRzfcAAGnr4q9ZIK1kCaAjLEbaPX9Sfg',
    serverEnvironment: 'COMMON_TEST'
  },
  production: {
    name: 'production',
    displayName: 'China Production Environment', 
    baseUrl: 'https://platform.plaud.cn',
    appKey: 'plaud-zoem8KYd-1748487531106',
    appSecret: 'aksk_hAyGDINVTsG3vsob2Shqku3iBqgI7clL',
    serverEnvironment: 'CHINA_PROD'
  }
};

export const DEFAULT_ENVIRONMENT = 'development'; // Default US production environment

/**
 * Environment management class
 * Use React Native built-in local storage to persist environment settings
 */
export class EnvironmentManager {
  static currentEnvironment = null; // null when not initialized
  static storageKey = 'plaud_current_environment';
  
  /**
   * Initialize environment configuration (read from local storage)
   */
  static async initialize() {
    try {
      const savedEnv = await AsyncStorage.getItem(this.storageKey);
      
      if (savedEnv && ENVIRONMENTS[savedEnv]) {
        this.currentEnvironment = savedEnv;
        console.log(`Restored environment: ${ENVIRONMENTS[savedEnv].displayName}`);
      } else {
        this.currentEnvironment = DEFAULT_ENVIRONMENT;
        console.log(`Using default environment: ${ENVIRONMENTS[DEFAULT_ENVIRONMENT].displayName}`);
      }
    } catch (error) {
      console.warn('Failed to load saved environment, using default:', error);
      this.currentEnvironment = DEFAULT_ENVIRONMENT;
    }
  }
  
  /**
   * Get current environment configuration
   */
  static async getCurrentEnvironment() {
    // If not initialized yet, initialize first
    if (this.currentEnvironment === null) {
      await this.initialize();
    }
    
    const config = ENVIRONMENTS[this.currentEnvironment];
    if (!config) {
      console.warn(`Environment ${this.currentEnvironment} not found, using default ${DEFAULT_ENVIRONMENT}`);
      this.currentEnvironment = DEFAULT_ENVIRONMENT;
      return ENVIRONMENTS[DEFAULT_ENVIRONMENT];
    }
    return config;
  }
  
  /**
   * Get all available environments
   */
  static getAllEnvironments() {
    return Object.values(ENVIRONMENTS);
  }
  
  /**
   * Set current environment
   */
  static async setEnvironment(envName) {
    const config = ENVIRONMENTS[envName];
    if (!config) {
      return {
        success: false,
        message: `Environment ${envName} not found`
      };
    }
    
    try {
      // Save to local storage
      await AsyncStorage.setItem(this.storageKey, envName);
      
      this.currentEnvironment = envName;
      console.log(`Environment switched to: ${config.displayName}`);
      
      return {
        success: true,
        message: `Environment switched to ${config.displayName}`,
        ...config
      };
    } catch (error) {
      console.error('Failed to save environment setting:', error);
      return {
        success: false,
        message: 'Failed to save environment setting'
      };
    }
  }
  
  /**
   * Get configuration by environment name
   */
  static getEnvironmentConfig(envName) {
    return ENVIRONMENTS[envName] || ENVIRONMENTS[DEFAULT_ENVIRONMENT];
  }
}
