import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';

enum WallpaperLocation { homeScreen, lockScreen, both }

class WallpaperService {
  static const MethodChannel _channel = MethodChannel(
    'com.onesentence/wallpaper',
  );

  /// 플랫폼 체크 헬퍼 (웹 호환)
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// 권한 요청
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    
    if (_isAndroid) {
      final status = await Permission.storage.request();
      if (status.isDenied) {
        // Android 13+ 에서는 photos 권한 사용
        final photosStatus = await Permission.photos.request();
        return photosStatus.isGranted;
      }
      return status.isGranted;
    } else if (_isIOS) {
      // iOS 14+: photosAddOnly로 저장 전용 권한 요청
      var status = await Permission.photosAddOnly.request();
      
      if (status.isGranted || status.isLimited) {
        return true;
      }
      
      // photosAddOnly가 안되면 photos 권한 시도
      status = await Permission.photos.request();
      
      if (status.isPermanentlyDenied) {
        // 설정으로 이동 안내
        await openAppSettings();
        return false;
      }
      
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  /// 이미지를 갤러리에 저장
  static Future<Map<String, dynamic>> saveToGallery(Uint8List imageBytes) async {
    if (kIsWeb) {
      debugPrint('Gallery save not supported on web');
      return {'success': false, 'error': '웹에서는 저장이 지원되지 않습니다.'};
    }
    
    try {
      debugPrint('Requesting permissions...');
      final hasPermission = await requestPermissions();
      debugPrint('Permission result: $hasPermission');
      
      if (!hasPermission) {
        return {'success': false, 'error': '사진 라이브러리 접근 권한이 필요합니다.\n설정에서 권한을 허용해주세요.'};
      }

      debugPrint('Saving image to gallery...');
      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        quality: 100,
        name: 'one_sentence_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      debugPrint('Save result: $result');

      if (result['isSuccess'] == true) {
        return {'success': true, 'filePath': result['filePath']};
      }
      return {'success': false, 'error': '저장에 실패했습니다: ${result['error'] ?? '알 수 없는 오류'}'};
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
      return {'success': false, 'error': '오류가 발생했습니다: $e'};
    }
  }

  /// 임시 파일로 저장
  static Future<File?> saveToTemp(Uint8List imageBytes) async {
    if (kIsWeb) return null;
    
    try {
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/wallpaper_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      return file;
    } catch (e) {
      debugPrint('Error saving to temp: $e');
      return null;
    }
  }

  /// 배경화면으로 설정 (Android만 지원)
  static Future<bool> setAsWallpaper(
    Uint8List imageBytes, {
    WallpaperLocation location = WallpaperLocation.both,
  }) async {
    if (kIsWeb || !_isAndroid) {
      // 웹 및 iOS는 시스템 제약으로 직접 배경화면 설정 불가
      return false;
    }
    
    try {
      final file = await saveToTemp(imageBytes);
      if (file == null) return false;

      final wallpaperManager = WallpaperManagerFlutter();
      
      switch (location) {
        case WallpaperLocation.homeScreen:
          await wallpaperManager.setWallpaper(file.path, WallpaperManagerFlutter.homeScreen);
          break;
        case WallpaperLocation.lockScreen:
          await wallpaperManager.setWallpaper(file.path, WallpaperManagerFlutter.lockScreen);
          break;
        case WallpaperLocation.both:
          await wallpaperManager.setWallpaper(file.path, WallpaperManagerFlutter.bothScreens);
          break;
      }

      return true;
    } catch (e) {
      debugPrint('Error setting wallpaper: $e');
      return false;
    }
  }

  /// 현재 배경화면 가져오기 (Android만 지원)
  static Future<File?> getCurrentWallpaper() async {
    if (kIsWeb || !_isAndroid) {
      // 웹 및 iOS는 보안상의 이유로 현재 배경화면에 접근 불가
      return null;
    }
    
    try {
      final Uint8List? wallpaperBytes = await _channel.invokeMethod(
        'getCurrentWallpaper',
      );

      if (wallpaperBytes == null || wallpaperBytes.isEmpty) {
        return null;
      }

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/current_wallpaper.png';
      final file = File(filePath);
      await file.writeAsBytes(wallpaperBytes);

      return file;
    } catch (e) {
      debugPrint('Error getting current wallpaper: $e');
      return null;
    }
  }

  /// 플랫폼이 배경화면 직접 설정을 지원하는지 확인
  static bool supportsDirectWallpaperSet() {
    if (kIsWeb) return false;
    return _isAndroid;
  }

  /// 플랫폼이 현재 배경화면 가져오기를 지원하는지 확인
  static bool supportsGetCurrentWallpaper() {
    if (kIsWeb) return false;
    return _isAndroid;
  }
}
