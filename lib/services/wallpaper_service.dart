import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
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
      final status = await Permission.photos.request();
      return status.isGranted;
    }
    return true;
  }

  /// 이미지를 갤러리에 저장
  static Future<String?> saveToGallery(Uint8List imageBytes) async {
    if (kIsWeb) {
      debugPrint('Gallery save not supported on web');
      return null;
    }
    
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        return null;
      }

      final result = await ImageGallerySaver.saveImage(
        imageBytes,
        quality: 100,
        name: 'one_sentence_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (result['isSuccess'] == true) {
        return result['filePath'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
      return null;
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

      int wallpaperLocation;
      switch (location) {
        case WallpaperLocation.homeScreen:
          wallpaperLocation = WallpaperManagerFlutter.HOME_SCREEN;
          break;
        case WallpaperLocation.lockScreen:
          wallpaperLocation = WallpaperManagerFlutter.LOCK_SCREEN;
          break;
        case WallpaperLocation.both:
          wallpaperLocation = WallpaperManagerFlutter.BOTH_SCREENS;
          break;
      }

      await WallpaperManagerFlutter().setwallpaperfromFile(
        file,
        wallpaperLocation,
      );

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
