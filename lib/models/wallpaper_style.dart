import 'package:flutter/material.dart';

class WallpaperStyle {
  final String fontFamily;
  final double fontSize;
  final Color textColor;
  final Color shadowColor;
  final double shadowBlur;
  final Offset textPosition; // 0.0 ~ 1.0 비율
  final TextAlign textAlign;
  final FontWeight fontWeight;
  final double letterSpacing;
  final double lineHeight;

  const WallpaperStyle({
    this.fontFamily = 'Noto Sans KR',
    this.fontSize = 24.0,
    this.textColor = Colors.white,
    this.shadowColor = Colors.black54,
    this.shadowBlur = 4.0,
    this.textPosition = const Offset(0.5, 0.5),
    this.textAlign = TextAlign.center,
    this.fontWeight = FontWeight.w500,
    this.letterSpacing = 0.0,
    this.lineHeight = 1.5,
  });

  WallpaperStyle copyWith({
    String? fontFamily,
    double? fontSize,
    Color? textColor,
    Color? shadowColor,
    double? shadowBlur,
    Offset? textPosition,
    TextAlign? textAlign,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? lineHeight,
  }) {
    return WallpaperStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      textPosition: textPosition ?? this.textPosition,
      textAlign: textAlign ?? this.textAlign,
      fontWeight: fontWeight ?? this.fontWeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }
}

// 미리 정의된 스타일 프리셋
class StylePresets {
  static const List<WallpaperStyle> presets = [
    // 미니멀 화이트
    WallpaperStyle(
      fontFamily: 'Noto Sans KR',
      fontSize: 22.0,
      textColor: Colors.white,
      shadowColor: Colors.black45,
      shadowBlur: 6.0,
      fontWeight: FontWeight.w300,
      letterSpacing: 2.0,
    ),
    // 볼드 센터
    WallpaperStyle(
      fontFamily: 'Noto Serif KR',
      fontSize: 28.0,
      textColor: Colors.white,
      shadowColor: Colors.black87,
      shadowBlur: 8.0,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.0,
    ),
    // 소프트 파스텔
    WallpaperStyle(
      fontFamily: 'Gowun Dodum',
      fontSize: 24.0,
      textColor: Color(0xFFFFF8E7),
      shadowColor: Color(0x66000000),
      shadowBlur: 4.0,
      fontWeight: FontWeight.w400,
      letterSpacing: 1.0,
    ),
    // 모던 다크
    WallpaperStyle(
      fontFamily: 'Nanum Gothic',
      fontSize: 20.0,
      textColor: Color(0xFFE0E0E0),
      shadowColor: Colors.black,
      shadowBlur: 10.0,
      fontWeight: FontWeight.w400,
      letterSpacing: 3.0,
    ),
  ];

  static const List<String> presetNames = [
    '미니멀',
    '볼드',
    '소프트',
    '모던',
  ];
}
