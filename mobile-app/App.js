import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert, ActivityIndicator, Platform } from 'react-native';
import { WebView } from 'react-native-webview';
import RNFS from 'react-native-fs';
import { NativeModules } from 'react-native';

const { SauceRobotServer } = NativeModules;

const App = () => {
  const [serverRunning, setServerRunning] = useState(false);
  const [serverUrl, setServerUrl] = useState(null);
  const [loading, setLoading] = useState(true);
  const [serverStatus, setServerStatus] = useState('Initializing...');

  useEffect(() => {
    initializeApp();
  }, []);

  const initializeApp = async () => {
    try {
      setServerStatus('Copying server files...');
      await copyServerFiles();

      setServerStatus('Starting Sauce Robot server...');
      await startServer();

      setLoading(false);
    } catch (error) {
      console.error('Initialization error:', error);
      Alert.alert('Error', `Failed to initialize Sauce Robot: ${error.message}`);
      setLoading(false);
    }
  };

  const copyServerFiles = async () => {
    try {
      await SauceRobotServer.copyServerFiles();
      console.log('Server files copied successfully');
    } catch (error) {
      console.error('Error copying server files:', error);
      throw error;
    }
  };

  const startServer = async () => {
    try {
      const result = await SauceRobotServer.startServer();
      if (result.success) {
        setServerUrl(result.serverUrl);
        setServerRunning(true);
        console.log('iOS Server started at:', result.serverUrl);
      } else {
        throw new Error(result.error || 'Failed to start server');
      }
    } catch (error) {
      console.error('Error starting server:', error);
      throw error;
    }
  };

  const restartServer = async () => {
    setLoading(true);
    setServerStatus('Restarting server...');
    try {
      await SauceRobotServer.stopServer();
      setServerRunning(false);
      await startServer();
    } catch (error) {
      Alert.alert('Error', 'Failed to restart server');
    }
    setLoading(false);
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#ff6b35" />
        <Text style={styles.loadingText}>SAUCE ROBOT STARTING UP...</Text>
        <Text style={styles.loadingSubtext}>{serverStatus}</Text>
      </View>
    );
  }

  if (!serverRunning || !serverUrl) {
    return (
      <View style={styles.errorContainer}>
        <Text style={styles.errorTitle}>🔧 Server Not Running</Text>
        <Text style={styles.errorText}>
          The Sauce Robot server failed to start. This robot may need maintenance.
        </Text>
        <TouchableOpacity style={styles.restartButton} onPress={restartServer}>
          <Text style={styles.restartButtonText}>RESTART ROBOT</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerText}>🍅 SAUCE ROBOT v2.0</Text>
        <TouchableOpacity style={styles.restartButtonSmall} onPress={restartServer}>
          <Text style={styles.restartButtonTextSmall}>⟳</Text>
        </TouchableOpacity>
      </View>

      <WebView
        source={{ uri: serverUrl }}
        style={styles.webview}
        javaScriptEnabled={true}
        domStorageEnabled={true}
        startInLoadingState={true}
        scalesPageToFit={true}
        renderLoading={() => (
          <View style={styles.webviewLoading}>
            <ActivityIndicator size="large" color="#ff6b35" />
            <Text style={styles.webviewLoadingText}>Loading Sauce Interface...</Text>
          </View>
        )}
        onError={(syntheticEvent) => {
          const { nativeEvent } = syntheticEvent;
          console.warn('WebView error: ', nativeEvent);
        }}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1a1a1a',
  },
  loadingText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#ff6b35',
    marginTop: 20,
    textAlign: 'center',
  },
  loadingSubtext: {
    fontSize: 16,
    color: '#cccccc',
    marginTop: 10,
    textAlign: 'center',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#1a1a1a',
  },
  errorTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#ff6b35',
    marginBottom: 20,
    textAlign: 'center',
  },
  errorText: {
    fontSize: 16,
    color: '#cccccc',
    textAlign: 'center',
    marginBottom: 30,
    lineHeight: 24,
  },
  restartButton: {
    backgroundColor: '#ff6b35',
    paddingHorizontal: 30,
    paddingVertical: 15,
    borderRadius: 8,
  },
  restartButtonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 15,
    backgroundColor: '#2a2a2a',
    borderBottomWidth: 1,
    borderBottomColor: '#444',
  },
  headerText: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#ff6b35',
  },
  restartButtonSmall: {
    backgroundColor: '#ff6b35',
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  restartButtonTextSmall: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
  webview: {
    flex: 1,
  },
  webviewLoading: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1a1a1a',
  },
  webviewLoadingText: {
    fontSize: 16,
    color: '#cccccc',
    marginTop: 10,
  },
});

export default App;
