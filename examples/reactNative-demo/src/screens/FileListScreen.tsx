import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  FlatList,
  StyleSheet,
  Alert,
  ActivityIndicator,
  PermissionsAndroid,
  Platform,
  Linking,
} from 'react-native';
import { useTranslation } from 'react-i18next';
import { PlaudFileManager } from '../../js/PlaudSDK';

interface FileItem {
  sessionId: number;
  fileSize: number;
  scene: number;
  sceneName: string;
  duration: string;
  sizeText: string;
  createTime: string;
  startTime: number;
  endTime: number;
}

interface FileListScreenProps {
  onBack: () => void;
}

const FileListScreen: React.FC<FileListScreenProps> = ({ onBack }) => {
  const { t } = useTranslation();
  const [files, setFiles] = useState<FileItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedFiles, setSelectedFiles] = useState<Set<number>>(new Set());
  const [selectionMode, setSelectionMode] = useState(false);
  const [downloadingFiles, setDownloadingFiles] = useState<Set<number>>(new Set());
  const [downloadProgress, setDownloadProgress] = useState<Map<number, {bytes: number, total: number, progress: number}>>(new Map());

  useEffect(() => {
    loadFileList();
    
    // Add download event listeners
    const progressListener = PlaudFileManager.addListener('onDownloadProgress', (data: any) => {
      console.log('Download progress update:', data);
      setDownloadProgress(prev => {
        const newMap = new Map(prev);
        newMap.set(data.sessionId, {
          bytes: data.downloadedBytes || 0,
          total: data.totalBytes || 0,
          progress: data.progress || 0
        });
        return newMap;
      });
    });
    
    // Listen for download completion events
    const completeListener = PlaudFileManager.addListener('onDownloadCompleted', (data: any) => {
      console.log('Download completion event:', data);
      setDownloadingFiles(prev => {
        const newSet = new Set(prev);
        newSet.delete(data.sessionId);
        return newSet;
      });
      setDownloadProgress(prev => {
        const newMap = new Map(prev);
        newMap.delete(data.sessionId);
        return newMap;
      });
      
      // Show alert with share option
      Alert.alert(
        'Download Complete', 
        `File saved to app internal storage: ${data.fileName}\n\nTap 'Share File' to share the file to other apps or save to other locations`,
        [
          { text: 'OK', style: 'default' },
          { 
            text: 'Share File', 
            style: 'default',
            onPress: () => shareDownloadedFile(data.filePath)
          }
        ]
      );
    });
    
    // Keep original onDownloadComplete listener for compatibility
    const legacyCompleteListener = PlaudFileManager.addListener('onDownloadComplete', (data: any) => {
      console.log('Download complete (old event):', data);
      setDownloadingFiles(prev => {
        const newSet = new Set(prev);
        newSet.delete(data.sessionId);
        return newSet;
      });
      setDownloadProgress(prev => {
        const newMap = new Map(prev);
        newMap.delete(data.sessionId);
        return newMap;
      });
      Alert.alert('Download Complete', `File saved: ${data.fileName}`);
    });
    
    // Listen for download error events
    const errorListener = PlaudFileManager.addListener('onDownloadError', (data: any) => {
      console.log('Download error event:', data);
      setDownloadingFiles(prev => {
        const newSet = new Set(prev);
        newSet.delete(data.sessionId);
        return newSet;
      });
      setDownloadProgress(prev => {
        const newMap = new Map(prev);
        newMap.delete(data.sessionId);
        return newMap;
      });
      Alert.alert('Download Failed', data.message || 'Error occurred during file download');
    });
    
    return () => {
      progressListener.remove();
      completeListener.remove();
      legacyCompleteListener.remove();
      errorListener.remove();
    };
  }, []);

  const loadFileList = async () => {
    setLoading(true);
    try {
      const result = await PlaudFileManager.getFileList();
      if (result && result.success && result.files) {
        setFiles(result.files);
      } else {
        Alert.alert('Notice', 'Failed to get file list');
        setFiles([]);
      }
    } catch (error: any) {
      Alert.alert('Error', `Failed to load files: ${error.message}`);
      setFiles([]);
    } finally {
      setLoading(false);
    }
  };

  const toggleSelectionMode = () => {
    setSelectionMode(!selectionMode);
    setSelectedFiles(new Set());
  };

  const toggleFileSelection = (sessionId: number) => {
    const newSelected = new Set(selectedFiles);
    if (newSelected.has(sessionId)) {
      newSelected.delete(sessionId);
    } else {
      newSelected.add(sessionId);
    }
    setSelectedFiles(newSelected);
  };

  const selectAllFiles = () => {
    if (selectedFiles.size === files.length) {
      setSelectedFiles(new Set());
    } else {
      setSelectedFiles(new Set(files.map(f => f.sessionId)));
    }
  };

  const requestStoragePermission = async () => {
    if (Platform.OS !== 'android') {
      return true;
    }
    
    try {
      const androidVersion = Platform.Version;
      console.log('Android version:', androidVersion);
      
      // Android 13+ (API 33+) does not need WRITE_EXTERNAL_STORAGE permission
      if (androidVersion >= 33) {
        console.log('Android 13+, no need to request storage permission');
        return true;
      }
      
      // Check if permission is already granted
      const hasPermission = await PermissionsAndroid.check(
        PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE
      );
      
      if (hasPermission) {
        console.log('Storage permission already granted');
        return true;
      }
      
      console.log('Requesting storage permission...');
      const granted = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
        {
          title: 'Storage Permission Request',
          message: 'The app needs storage permission to save recording files to your device.',
          buttonNeutral: 'Ask Later',
          buttonNegative: 'Deny',
          buttonPositive: 'Allow',
        }
      );
      
      const isGranted = granted === PermissionsAndroid.RESULTS.GRANTED;
      console.log('Permission request result:', granted, 'Is granted:', isGranted);
      
      if (!isGranted) {
        // If permission is denied, provide option to go to settings
        Alert.alert(
          'Permission Denied',
          'Cannot save files to device. You can manually enable storage permission in settings.',
          [
            { text: 'Cancel', style: 'cancel' },
            { 
              text: 'Go to Settings', 
              onPress: () => {
                Linking.openSettings().catch(() => {
                  Alert.alert('Error', 'Cannot open settings page');
                });
              }
            }
          ]
        );
      }
      
      return isGranted;
    } catch (err) {
      console.error('Permission request error:', err);
      Alert.alert('Error', 'Permission request failed, please try again');
      return false;
    }
  };

  const shareDownloadedFile = async (filePath: string) => {
    try {
      const result = await PlaudFileManager.shareFile(filePath);
      console.log('Share file result:', result);
    } catch (error: any) {
      console.error('Share file error:', error);
      Alert.alert('Share Failed', error.message || 'Cannot share file');
    }
  };

  const downloadFile = async (file: FileItem) => {
    console.log('Starting file download:', file.sessionId);
    
    // Check storage permission
    const hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      console.log('Permission check failed, canceling download');
      return;
    }
    
    console.log('Permission check passed, starting download');
    setDownloadingFiles(prev => new Set(prev).add(file.sessionId));
    
    try {
      const result = await PlaudFileManager.downloadFile(file.sessionId);
      console.log('Download result:', result);
      
      if (result.success) {
        console.log('File download started:', result.fileName);
        // Remove popup, only log in console
        // Alert.alert('Download started', 'File is downloading...');
      } else {
        Alert.alert('Download Notice', result.message || 'File download failed', [
          { text: 'OK' },
          ...(result.suggestion ? [{ text: 'Learn More', onPress: () => Alert.alert('Suggestion', result.suggestion) }] : [])
        ]);
        setDownloadingFiles(prev => {
          const newSet = new Set(prev);
          newSet.delete(file.sessionId);
          return newSet;
        });
      }
    } catch (error: any) {
      console.error('Download error:', error);
      Alert.alert('Error', `Download failed: ${error.message}`);
      setDownloadingFiles(prev => {
        const newSet = new Set(prev);
        newSet.delete(file.sessionId);
        return newSet;
      });
    }
  };

  const clearAllFiles = async () => {
    Alert.alert(
      'Confirm Delete',
      'Are you sure you want to clear all recording files on the device? This operation cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: t('common.delete'),
          style: 'destructive',
          onPress: async () => {
            setLoading(true);
            try {
              const result = await PlaudFileManager.clearAllFiles();
              if (result.success) {
                Alert.alert(t('common.success'), 'All files have been cleared');
                setFiles([]);
                setSelectedFiles(new Set());
                setSelectionMode(false);
              } else {
                Alert.alert(t('common.failed'), result.message || 'Failed to clear files');
              }
            } catch (error: any) {
              Alert.alert(t('common.error'), `Failed to clear files: ${error.message}`);
            } finally {
              setLoading(false);
            }
          },
        },
      ]
    );
  };

  const getSceneIcon = (scene: number) => {
    switch (scene) {
      case 1: return t('files.scenes.meeting'); // Meeting
      case 2: return t('files.scenes.classroom'); // Classroom
      case 3: return t('files.scenes.interview'); // Interview
      case 4: return t('files.scenes.music'); // Music
      case 5: return t('files.scenes.memo'); // Memo
      default: return '🎙️';
    }
  };

  const renderFileItem = ({ item }: { item: FileItem }) => {
    const isSelected = selectedFiles.has(item.sessionId);
    const isDownloading = downloadingFiles.has(item.sessionId);
    const progressInfo = downloadProgress.get(item.sessionId);
    const progressBytes = progressInfo?.bytes || 0;
    const progressPercent = progressInfo?.progress || 0;
    
    return (
      <TouchableOpacity
        style={[
          styles.fileItem,
          isSelected && styles.fileItemSelected,
          selectionMode && styles.fileItemSelectionMode
        ]}
        onPress={() => selectionMode ? toggleFileSelection(item.sessionId) : undefined}
      >
        <View style={styles.fileIcon}>
          <Text style={styles.sceneIcon}>{getSceneIcon(item.scene)}</Text>
          {isSelected && (
            <View style={styles.selectedIndicator}>
              <Text style={styles.selectedText}>✓</Text>
            </View>
          )}
        </View>
        
        <View style={styles.fileInfo}>
          <View style={styles.fileHeader}>
            <Text style={styles.fileName}>
              {item.sceneName} - {item.createTime.split(' ')[1]}
            </Text>
            <Text style={styles.fileDuration}>{item.duration}</Text>
          </View>
          
          <View style={styles.fileDetails}>
            <Text style={styles.fileSize}>{item.sizeText}</Text>
            <Text style={styles.fileDate}>{item.createTime.split(' ')[0]}</Text>
          </View>
          
          <Text style={styles.fileId}>{t('files.session_id')}: {item.sessionId}</Text>
          
          {isDownloading && (
            <View style={styles.downloadProgress}>
              <Text style={styles.downloadText}>
                {progressPercent >= 1 
                  ? `${t('files.converting')} ${(progressBytes / 1024).toFixed(1)} KB` 
                  : `${t('files.downloading')} ${(progressBytes / 1024).toFixed(1)} KB (${(progressPercent * 100).toFixed(1)}%)`
                }
              </Text>
              <ActivityIndicator size="small" color="#2196F3" />
            </View>
          )}
        </View>
        
        {!selectionMode && (
          <TouchableOpacity
            style={[
              styles.downloadButton,
              isDownloading && styles.downloadButtonDisabled
            ]}
            onPress={() => downloadFile(item)}
            disabled={isDownloading}
          >
            {isDownloading ? (
              <ActivityIndicator size="small" color="#FFFFFF" />
            ) : (
              <Text style={styles.downloadButtonText}>📥</Text>
            )}
          </TouchableOpacity>
        )}
      </TouchableOpacity>
    );
  };

  return (
    <View style={styles.container}>
      {/* Toolbar */}
      <View style={styles.toolbar}>
        <TouchableOpacity style={styles.backButton} onPress={onBack}>
          <Text style={styles.backButtonText}>←</Text>
        </TouchableOpacity>
        <Text style={styles.toolbarTitle}>{t('files.title')}</Text>
        <View style={styles.backButton} />
      </View>

      {/* File statistics bar */}
      <View style={styles.headerBar}>
        <Text style={styles.fileCountText}>{files.length} {t('files.files_count')}</Text>
        
        <TouchableOpacity
          style={styles.selectButton}
          onPress={toggleSelectionMode}
        >
          <Text style={styles.selectButtonText}>
            {selectionMode ? t('files.cancel') : t('files.select')}
          </Text>
        </TouchableOpacity>
      </View>

      {/* File list */}
      <View style={styles.fileListContainer}>
        {files.length > 0 ? (
          <FlatList
            data={files}
            renderItem={renderFileItem}
            keyExtractor={(item) => item.sessionId.toString()}
            style={styles.fileList}
            showsVerticalScrollIndicator={true}
            refreshing={loading}
            onRefresh={loadFileList}
          />
        ) : (
          <View style={styles.emptyContainer}>
            <Text style={styles.emptyIcon}>📁</Text>
            <Text style={styles.emptyText}>{t('files.no_files')}</Text>
            <TouchableOpacity style={styles.refreshButton} onPress={loadFileList}>
              <Text style={styles.refreshButtonText}>{t('files.refresh')}</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>

      {/* Selection mode action bar */}
      {selectionMode && (
        <View style={styles.selectionActions}>
          <TouchableOpacity
            style={styles.actionButton}
            onPress={selectAllFiles}
          >
            <Text style={styles.actionButtonText}>
              {selectedFiles.size === files.length ? t('files.deselect_all') : t('files.select_all')}
            </Text>
          </TouchableOpacity>
          
          <TouchableOpacity
            style={[styles.actionButton, styles.deleteButton]}
            onPress={clearAllFiles}
            disabled={files.length === 0}
          >
            <Text style={[styles.actionButtonText, styles.deleteButtonText]}>
              {t('files.clear_all')}
            </Text>
          </TouchableOpacity>
        </View>
      )}

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
  headerBar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  fileCountText: {
    fontSize: 16,
    color: '#616161',
  },
  selectButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#2196F3',
  },
  selectButtonText: {
    color: '#2196F3',
    fontSize: 14,
    fontWeight: '500',
  },
  fileListContainer: {
    flex: 1,
    padding: 16,
  },
  fileList: {
    flex: 1,
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    paddingVertical: 8,
  },
  fileItem: {
    flexDirection: 'row',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  fileItemSelected: {
    backgroundColor: '#E3F2FD',
  },
  fileItemSelectionMode: {
    paddingLeft: 12,
  },
  fileIcon: {
    width: 48,
    height: 48,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
    position: 'relative',
  },
  sceneIcon: {
    fontSize: 24,
  },
  selectedIndicator: {
    position: 'absolute',
    top: -4,
    right: -4,
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: '#2196F3',
    justifyContent: 'center',
    alignItems: 'center',
  },
  selectedText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: 'bold',
  },
  fileInfo: {
    flex: 1,
  },
  fileHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  fileName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212121',
    flex: 1,
  },
  fileDuration: {
    fontSize: 14,
    color: '#2196F3',
    fontWeight: '500',
  },
  fileDetails: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  fileSize: {
    fontSize: 14,
    color: '#616161',
  },
  fileDate: {
    fontSize: 14,
    color: '#616161',
  },
  fileId: {
    fontSize: 12,
    color: '#9E9E9E',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 32,
  },
  emptyIcon: {
    fontSize: 64,
    marginBottom: 16,
  },
  emptyText: {
    fontSize: 16,
    color: '#616161',
    marginBottom: 24,
  },
  refreshButton: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#2196F3',
  },
  refreshButtonText: {
    color: '#2196F3',
    fontSize: 14,
    fontWeight: '500',
  },
  selectionActions: {
    flexDirection: 'row',
    backgroundColor: '#FFFFFF',
    padding: 8,
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  actionButton: {
    flex: 1,
    paddingVertical: 12,
    paddingHorizontal: 16,
    marginHorizontal: 4,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#2196F3',
    alignItems: 'center',
  },
  deleteButton: {
    borderColor: '#F44336',
  },
  actionButtonText: {
    color: '#2196F3',
    fontSize: 14,
    fontWeight: '500',
  },
  deleteButtonText: {
    color: '#F44336',
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
  downloadButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#2196F3',
    justifyContent: 'center',
    alignItems: 'center',
    marginLeft: 8,
  },
  downloadButtonDisabled: {
    backgroundColor: '#CCCCCC',
  },
  downloadButtonText: {
    fontSize: 18,
    color: '#FFFFFF',
  },
  downloadProgress: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
  },
  downloadText: {
    fontSize: 12,
    color: '#2196F3',
    marginRight: 8,
  },
});

export default FileListScreen;
