import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screenshot/screenshot.dart';
import '../models/wallpaper_style.dart';
import '../services/wallpaper_service.dart';

class EditorScreen extends StatefulWidget {
  final String sentence;
  final File? backgroundImage;

  const EditorScreen({
    super.key,
    required this.sentence,
    this.backgroundImage,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with SingleTickerProviderStateMixin {
  final ScreenshotController _screenshotController = ScreenshotController();
  late WallpaperStyle _style;
  int _selectedPresetIndex = 0;
  bool _isProcessing = false;

  // 드래그 위치
  Offset _textPosition = const Offset(0.5, 0.5);

  // 사용 가능한 폰트 목록
  final List<String> _availableFonts = [
    'Noto Sans KR',
    'Noto Serif KR',
    'Gowun Dodum',
    'Nanum Gothic',
    'Nanum Myeongjo',
    'Do Hyeon',
    'Gothic A1',
    'Jua',
  ];

  // 기본 배경 그라데이션 프리셋
  final List<List<Color>> _backgroundGradients = [
    [const Color(0xFF0F0F1A), const Color(0xFF1A1A2E), const Color(0xFF0F0F1A)],
    [const Color(0xFF1A1A2E), const Color(0xFF16213E), const Color(0xFF0F3460)],
    [const Color(0xFF2C3E50), const Color(0xFF3498DB), const Color(0xFF2C3E50)],
    [const Color(0xFF141E30), const Color(0xFF243B55), const Color(0xFF141E30)],
    [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)],
    [const Color(0xFF232526), const Color(0xFF414345), const Color(0xFF232526)],
  ];
  int _selectedGradientIndex = 0;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _style = StylePresets.presets[0];
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _captureWallpaper() async {
    return await _screenshotController.capture(pixelRatio: 3.0);
  }

  Future<void> _saveWallpaper() async {
    setState(() => _isProcessing = true);

    try {
      final Uint8List? imageBytes = await _captureWallpaper();

      if (imageBytes == null) {
        _showSnackBar('이미지 생성에 실패했습니다', isError: true);
        return;
      }

      final result = await WallpaperService.saveToGallery(imageBytes);

      if (result != null) {
        _showSnackBar('갤러리에 저장되었습니다! 🎉');
      } else {
        _showSnackBar('저장에 실패했습니다. 권한을 확인해주세요.', isError: true);
      }
    } catch (e) {
      _showSnackBar('오류가 발생했습니다: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _setAsWallpaper(WallpaperLocation location) async {
    setState(() => _isProcessing = true);

    try {
      final Uint8List? imageBytes = await _captureWallpaper();

      if (imageBytes == null) {
        _showSnackBar('이미지 생성에 실패했습니다', isError: true);
        return;
      }

      final success = await WallpaperService.setAsWallpaper(
        imageBytes,
        location: location,
      );

      if (success) {
        String locationText;
        switch (location) {
          case WallpaperLocation.homeScreen:
            locationText = '홈 화면';
            break;
          case WallpaperLocation.lockScreen:
            locationText = '잠금 화면';
            break;
          case WallpaperLocation.both:
            locationText = '홈 화면과 잠금 화면';
            break;
        }
        _showSnackBar('$locationText 배경화면이 설정되었습니다! 🎉');
      } else {
        _showSnackBar('배경화면 설정에 실패했습니다.', isError: true);
      }
    } catch (e) {
      _showSnackBar('오류가 발생했습니다: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showWallpaperOptions() {
    final supportsDirectSet = WallpaperService.supportsDirectWallpaperSet();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '저장 및 설정',
              style: GoogleFonts.notoSans(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            
            // 갤러리에 저장
            _buildOptionTile(
              icon: Icons.photo_library_outlined,
              title: '갤러리에 저장',
              subtitle: '이미지를 갤러리에 저장합니다',
              onTap: () {
                Navigator.pop(context);
                _saveWallpaper();
              },
            ),
            
            if (supportsDirectSet) ...[
              const Divider(color: Colors.white12, height: 24),
              
              // 홈 화면 배경화면으로 설정
              _buildOptionTile(
                icon: Icons.home_outlined,
                title: '홈 화면 배경화면으로 설정',
                subtitle: '홈 화면 배경화면을 바로 변경합니다',
                onTap: () {
                  Navigator.pop(context);
                  _setAsWallpaper(WallpaperLocation.homeScreen);
                },
              ),
              
              const SizedBox(height: 8),
              
              // 잠금 화면 배경화면으로 설정
              _buildOptionTile(
                icon: Icons.lock_outline,
                title: '잠금 화면 배경화면으로 설정',
                subtitle: '잠금 화면 배경화면을 바로 변경합니다',
                onTap: () {
                  Navigator.pop(context);
                  _setAsWallpaper(WallpaperLocation.lockScreen);
                },
              ),
              
              const SizedBox(height: 8),
              
              // 둘 다 설정
              _buildOptionTile(
                icon: Icons.wallpaper,
                title: '둘 다 배경화면으로 설정',
                subtitle: '홈 화면과 잠금 화면 모두 변경합니다',
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFFFF6B9D)],
                ),
                onTap: () {
                  Navigator.pop(context);
                  _setAsWallpaper(WallpaperLocation.both);
                },
              ),
            ] else ...[
              const Divider(color: Colors.white12, height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'iOS에서는 갤러리에 저장 후 설정 앱에서 배경화면을 변경해주세요.',
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Gradient? gradient,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? const Color(0xFF2A2A3A) : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.notoSans(),
        ),
        backgroundColor: isError ? const Color(0xFFE74C3C) : const Color(0xFF2ECC71),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showColorPicker() {
    Color pickerColor = _style.textColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '텍스트 색상',
          style: GoogleFonts.notoSans(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
            enableAlpha: true,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: GoogleFonts.notoSans()),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _style = _style.copyWith(textColor: pickerColor);
              });
              Navigator.pop(context);
            },
            child: Text('적용', style: GoogleFonts.notoSans()),
          ),
        ],
      ),
    );
  }

  void _showFontPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '폰트 선택',
              style: GoogleFonts.notoSans(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _availableFonts.length,
                itemBuilder: (context, index) {
                  final font = _availableFonts[index];
                  final isSelected = _style.fontFamily == font;

                  return ListTile(
                    onTap: () {
                      setState(() {
                        _style = _style.copyWith(fontFamily: font);
                      });
                      Navigator.pop(context);
                    },
                    title: Text(
                      '오늘 하루도 화이팅',
                      style: GoogleFonts.getFont(
                        font,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      font,
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Color(0xFF7C4DFF))
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '스타일 편집',
          style: GoogleFonts.notoSans(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF7C4DFF),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFF7C4DFF)),
              onPressed: _showWallpaperOptions,
            ),
        ],
      ),
      body: Column(
        children: [
          // 미리보기 영역
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Screenshot(
                  controller: _screenshotController,
                  child: _buildWallpaperPreview(),
                ),
              ),
            ),
          ),

          // 컨트롤 패널
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF151520),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 스타일 프리셋
                    _buildSectionTitle('스타일 프리셋'),
                    const SizedBox(height: 12),
                    _buildPresetSelector(),
                    const SizedBox(height: 24),

                    // 배경 선택 (이미지가 없을 때만)
                    if (widget.backgroundImage == null) ...[
                      _buildSectionTitle('배경 색상'),
                      const SizedBox(height: 12),
                      _buildGradientSelector(),
                      const SizedBox(height: 24),
                    ],

                    // 텍스트 옵션
                    _buildSectionTitle('텍스트 옵션'),
                    const SizedBox(height: 12),
                    _buildTextOptions(),
                    const SizedBox(height: 24),

                    // 폰트 크기 슬라이더
                    _buildSectionTitle('폰트 크기: ${_style.fontSize.toInt()}'),
                    Slider(
                      value: _style.fontSize,
                      min: 14,
                      max: 48,
                      activeColor: const Color(0xFF7C4DFF),
                      inactiveColor: const Color(0xFF2A2A3A),
                      onChanged: (value) {
                        setState(() {
                          _style = _style.copyWith(fontSize: value);
                        });
                      },
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperPreview() {
    return GestureDetector(
      onPanUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        setState(() {
          _textPosition = Offset(
            (localPosition.dx / box.size.width).clamp(0.1, 0.9),
            (localPosition.dy / box.size.height).clamp(0.1, 0.9),
          );
          _style = _style.copyWith(textPosition: _textPosition);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          image: widget.backgroundImage != null
              ? DecorationImage(
                  image: FileImage(widget.backgroundImage!),
                  fit: BoxFit.cover,
                )
              : null,
          gradient: widget.backgroundImage == null
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _backgroundGradients[_selectedGradientIndex],
                )
              : null,
        ),
        child: Stack(
          children: [
            // 오버레이 (이미지가 있을 때 텍스트 가독성 향상)
            if (widget.backgroundImage != null)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),

            // 텍스트
            Positioned(
              left: 24,
              right: 24,
              top: MediaQuery.of(context).size.height * _textPosition.dy * 0.4,
              child: Text(
                widget.sentence,
                textAlign: _style.textAlign,
                style: GoogleFonts.getFont(
                  _style.fontFamily,
                  fontSize: _style.fontSize,
                  fontWeight: _style.fontWeight,
                  color: _style.textColor,
                  letterSpacing: _style.letterSpacing,
                  height: _style.lineHeight,
                  shadows: [
                    Shadow(
                      color: _style.shadowColor,
                      blurRadius: _style.shadowBlur,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.notoSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildPresetSelector() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: StylePresets.presets.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedPresetIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPresetIndex = index;
                _style = StylePresets.presets[index].copyWith(
                  textPosition: _textPosition,
                );
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFFFF6B9D)],
                      )
                    : null,
                color: isSelected ? null : const Color(0xFF2A2A3A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Text(
                  StylePresets.presetNames[index],
                  style: GoogleFonts.notoSans(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradientSelector() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _backgroundGradients.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedGradientIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedGradientIndex = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              width: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _backgroundGradients[index],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF7C4DFF)
                      : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextOptions() {
    return Row(
      children: [
        // 폰트 선택
        _buildTextOptionButton(
          icon: Icons.font_download_outlined,
          label: '폰트',
          onTap: _showFontPicker,
        ),
        const SizedBox(width: 12),
        // 색상 선택
        _buildTextOptionButton(
          icon: Icons.palette_outlined,
          label: '색상',
          onTap: _showColorPicker,
          iconColor: _style.textColor,
        ),
        const SizedBox(width: 12),
        // 텍스트 정렬
        _buildTextOptionButton(
          icon: _style.textAlign == TextAlign.left
              ? Icons.format_align_left
              : _style.textAlign == TextAlign.right
                  ? Icons.format_align_right
                  : Icons.format_align_center,
          label: '정렬',
          onTap: () {
            setState(() {
              if (_style.textAlign == TextAlign.center) {
                _style = _style.copyWith(textAlign: TextAlign.left);
              } else if (_style.textAlign == TextAlign.left) {
                _style = _style.copyWith(textAlign: TextAlign.right);
              } else {
                _style = _style.copyWith(textAlign: TextAlign.center);
              }
            });
          },
        ),
        const SizedBox(width: 12),
        // 굵기
        _buildTextOptionButton(
          icon: Icons.format_bold,
          label: '굵기',
          isActive: _style.fontWeight == FontWeight.w700,
          onTap: () {
            setState(() {
              _style = _style.copyWith(
                fontWeight: _style.fontWeight == FontWeight.w700
                    ? FontWeight.w400
                    : FontWeight.w700,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildTextOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    bool isActive = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF7C4DFF).withValues(alpha: 0.2)
                : const Color(0xFF2A2A3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF7C4DFF)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: iconColor ?? (isActive ? const Color(0xFF7C4DFF) : Colors.white.withValues(alpha: 0.7)),
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.notoSans(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
