import React from 'react';
import {
  StatusBar,
  StyleSheet,
  SafeAreaView,
} from 'react-native';
import Navigator from './src/components/Navigator';
import './src/i18n'; // Initialize i18n

const App: React.FC = () => {
  // SDK initialization is handled by IntroScreen

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar
        barStyle="dark-content"
        backgroundColor="#FFFFFF"
        translucent={false}
      />
      <Navigator />
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
});

export default App;
