import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import AsyncStorage from '@react-native-async-storage/async-storage';

import en from './locales/en.json';
import zh from './locales/zh.json';

const LANGUAGE_DETECTOR = {
  type: 'languageDetector',
  async: true,
  detect: async (callback) => {
    try {
      // Try to get the saved language from AsyncStorage
      const savedLanguage = await AsyncStorage.getItem('app_language');
      if (savedLanguage) {
        callback(savedLanguage);
        return;
      }
      
      // Default to English for overseas users
      callback('en');
    } catch (error) {
      console.warn('Error detecting language:', error);
      callback('en');
    }
  },
  cacheUserLanguage: async (language) => {
    try {
      await AsyncStorage.setItem('app_language', language);
    } catch (error) {
      console.warn('Error saving language:', error);
    }
  }
};

i18n
  .use(LANGUAGE_DETECTOR)
  .use(initReactI18next)
  .init({
    compatibilityJSON: 'v3',
    fallbackLng: 'en',
    debug: false,
    
    resources: {
      en: {
        translation: en
      },
      zh: {
        translation: zh
      }
    },
    
    interpolation: {
      escapeValue: false
    }
  });

export default i18n;
