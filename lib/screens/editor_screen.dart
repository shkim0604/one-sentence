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

  const EditorScreen({super.key, required this.sentence, this.backgroundImage});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin {
  late WallpaperStyle _style;
  int _selectedPresetIndex = 0;
  bool _isProcessing = false;

  // 드래그 위치 (0.0 ~ 1.0 비율)
  Offset _textPosition = const Offset(0.5, 0.4);

  // 텍스트 GlobalKey (경계 체크용)
  final GlobalKey _textKey = GlobalKey();

  // 배경 이미지 조정
  double _imageScale = 1.0;
  Offset _imageOffset = Offset.zero;
  Offset _lastFocalPoint = Offset.zero;
  double _lastScale = 1.0;

  // 현재 편집 모드 (텍스트 vs 이미지)
  bool _isEditingImage = false;

  // 미리보기 컨테이너 크기 (스케일 계산용)
  Size _previewSize = Size.zero;

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
    // 실제 기기 화면 크기 가져오기
    final screenSize = MediaQuery.of(context).size;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    // 실제 픽셀 크기 계산
    final actualWidth = screenSize.width * pixelRatio;
    final actualHeight = screenSize.height * pixelRatio;

    debugPrint('Screen size: ${screenSize.width}x${screenSize.height}');
    debugPrint('Pixel ratio: $pixelRatio');
    debugPrint('Actual pixels: ${actualWidth}x$actualHeight');

    // 풀스크린 배경화면 위젯을 캡처
    final fullScreenController = ScreenshotController();

    return await fullScreenController.captureFromLongWidget(
      _buildFullScreenWallpaper(screenSize),
      pixelRatio: pixelRatio,
      delay: const Duration(milliseconds: 100),
      context: context,
    );
  }

  /// 실제 저장될 풀스크린 배경화면 위젯
  Widget _buildFullScreenWallpaper(Size screenSize) {
    // 스케일 계산 (미리보기 대비 실제 화면 비율)
    final scale = _previewSize.height > 0
        ? screenSize.height / _previewSize.height
        : 1.0;

    debugPrint('Preview size: $_previewSize');
    debugPrint('Screen size: $screenSize');
    debugPrint('Scale factor: $scale');

    // 스케일 적용된 값들
    final scaledFontSize = _style.fontSize * scale;
    final scaledPadding = 24.0 * scale;
    final scaledShadowBlur = _style.shadowBlur * scale;
    final scaledLetterSpacing = _style.letterSpacing * scale;
    final scaledShadowOffset = 2.0 * scale;

    // 텍스트 위치 계산 (비율 기반이라 스케일 불필요)
    final textTop = screenSize.height * _textPosition.dy;

    // 이미지 오프셋도 스케일 적용
    final scaledImageOffset = Offset(
      _imageOffset.dx * scale,
      _imageOffset.dy * scale,
    );

    return SizedBox(
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        children: [
          // 배경 이미지 또는 그라데이션
          if (widget.backgroundImage != null)
            Positioned.fill(
              child: Transform(
                transform: Matrix4.identity()
                  ..translate(scaledImageOffset.dx, scaledImageOffset.dy)
                  ..scale(_imageScale),
                alignment: Alignment.center,
                child: Image.file(
                  widget.backgroundImage!,
                  fit: BoxFit.cover,
                  width: screenSize.width,
                  height: screenSize.height,
                ),
              ),
            )
          else
            Container(
              width: screenSize.width,
              height: screenSize.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _backgroundGradients[_selectedGradientIndex],
                ),
              ),
            ),

          // 오버레이 (이미지가 있을 때)
          if (widget.backgroundImage != null)
            Container(
              width: screenSize.width,
              height: screenSize.height,
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
            left: scaledPadding,
            right: scaledPadding,
            top: textTop.clamp(40.0 * scale, screenSize.height - 100 * scale),
            child: Text(
              widget.sentence,
              textAlign: _style.textAlign,
              style: GoogleFonts.getFont(
                _style.fontFamily,
                fontSize: scaledFontSize,
                fontWeight: _style.fontWeight,
                color: _style.textColor,
                letterSpacing: scaledLetterSpacing,
                height: _style.lineHeight,
                shadows: [
                  Shadow(
                    color: _style.shadowColor,
                    blurRadius: scaledShadowBlur,
                    offset: Offset(0, scaledShadowOffset),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

      if (result['success'] == true) {
        _showSnackBar('갤러리에 저장되었습니다! 🎉');
      } else {
        _showSnackBar(result['error'] ?? '저장에 실패했습니다.', isError: true);
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
        content: Text(message, style: GoogleFonts.notoSans()),
        backgroundColor: isError
            ? const Color(0xFFE74C3C)
            : const Color(0xFF2ECC71),
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
        title: Text('텍스트 색상', style: GoogleFonts.notoSans(color: Colors.white)),
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
                      widget.sentence.length > 20
                          ? '${widget.sentence.substring(0, 20)}...'
                          : widget.sentence,
                      style: GoogleFonts.getFont(
                        font,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      font,
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFF7C4DFF),
                          )
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
          style: GoogleFonts.notoSans(fontWeight: FontWeight.w600),
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
          // 미리보기 영역 - 실제 화면 비율로 표시
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: Center(
                child: AspectRatio(
                  // 실제 폰 화면 비율 사용
                  aspectRatio: MediaQuery.of(context).size.width /
                      MediaQuery.of(context).size.height,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // 미리보기 (스크린샷용 아님, 표시용)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildWallpaperPreview(),
                        ),
                        // 드래그 힌트
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 12,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isEditingImage
                                        ? Icons.zoom_out_map
                                        : Icons.open_with,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isEditingImage
                                        ? '핀치로 확대, 드래그로 위치 조절'
                                        : '텍스트를 드래그하여 위치 조절',
                                    style: GoogleFonts.notoSans(
                                      fontSize: 10,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 편집 모드 토글 버튼 (이미지가 있을 때만)
                        if (widget.backgroundImage != null)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildModeButton(
                                    icon: Icons.text_fields,
                                    label: '텍스트',
                                    isSelected: !_isEditingImage,
                                    onTap: () =>
                                        setState(() => _isEditingImage = false),
                                  ),
                                  _buildModeButton(
                                    icon: Icons.image,
                                    label: '이미지',
                                    isSelected: _isEditingImage,
                                    onTap: () =>
                                        setState(() => _isEditingImage = true),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
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

                    // 이미지 조정 (이미지가 있을 때만)
                    if (widget.backgroundImage != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle(
                            '이미지 확대: ${(_imageScale * 100).toInt()}%',
                          ),
                          if (_imageScale != 1.0 || _imageOffset != Offset.zero)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _imageScale = 1.0;
                                  _imageOffset = Offset.zero;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF7C4DFF,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '초기화',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 12,
                                    color: const Color(0xFF7C4DFF),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Slider(
                        value: _imageScale,
                        min: 1.0,
                        max: 3.0,
                        activeColor: const Color(0xFFFF6B9D),
                        inactiveColor: const Color(0xFF2A2A3A),
                        onChanged: (value) {
                          setState(() {
                            _imageScale = value;
                            // 축소할 때 오프셋도 비율에 맞게 조정
                            final maxOffset =
                                (MediaQuery.of(context).size.width *
                                    (_imageScale - 1)) /
                                2;
                            _imageOffset = Offset(
                              _imageOffset.dx.clamp(-maxOffset, maxOffset),
                              _imageOffset.dy.clamp(-maxOffset, maxOffset),
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 16),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        final containerHeight = constraints.maxHeight;

        // 미리보기 크기 저장 (저장 시 스케일 계산용)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_previewSize.width != containerWidth ||
              _previewSize.height != containerHeight) {
            _previewSize = Size(containerWidth, containerHeight);
          }
        });

        // 패딩 값
        const horizontalPadding = 24.0;

        // 텍스트 위치 계산 (비율 -> 실제 좌표)
        // 텍스트가 화면 밖으로 나가지 않도록 제한
        const minY = 20.0;
        final maxY = containerHeight - 60.0; // 텍스트 높이 여유분

        final textTop = (containerHeight * _textPosition.dy).clamp(minY, maxY);

        return GestureDetector(
          // 이미지 편집 모드일 때만 이미지 조작
          onScaleStart: widget.backgroundImage != null && _isEditingImage
              ? (details) {
                  _lastFocalPoint = details.focalPoint;
                  _lastScale = _imageScale;
                }
              : null,
          onScaleUpdate: widget.backgroundImage != null && _isEditingImage
              ? (details) {
                  setState(() {
                    // 확대/축소
                    _imageScale = (_lastScale * details.scale).clamp(1.0, 3.0);

                    // 이동
                    final delta = details.focalPoint - _lastFocalPoint;
                    _lastFocalPoint = details.focalPoint;

                    // 이미지 이동 범위 제한
                    final maxOffset = (containerWidth * (_imageScale - 1)) / 2;
                    final maxOffsetY =
                        (containerHeight * (_imageScale - 1)) / 2;

                    _imageOffset = Offset(
                      (_imageOffset.dx + delta.dx).clamp(-maxOffset, maxOffset),
                      (_imageOffset.dy + delta.dy).clamp(
                        -maxOffsetY,
                        maxOffsetY,
                      ),
                    );
                  });
                }
              : null,
          child: ClipRect(
            child: Stack(
              children: [
                // 배경 이미지 (확대/이동 가능)
                if (widget.backgroundImage != null)
                  Positioned.fill(
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translate(_imageOffset.dx, _imageOffset.dy)
                        ..scale(_imageScale),
                      alignment: Alignment.center,
                      child: Image.file(
                        widget.backgroundImage!,
                        fit: BoxFit.cover,
                        width: containerWidth,
                        height: containerHeight,
                      ),
                    ),
                  )
                else
                  // 그라데이션 배경
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _backgroundGradients[_selectedGradientIndex],
                      ),
                    ),
                  ),

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

                // 드래그 가능한 텍스트 (텍스트 편집 모드일 때만)
                Positioned(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  top: textTop,
                  child: GestureDetector(
                    onPanUpdate: !_isEditingImage
                        ? (details) {
                            setState(() {
                              // 새 위치 계산
                              double newDy =
                                  _textPosition.dy +
                                  (details.delta.dy / containerHeight);

                              // 경계 체크: 텍스트가 화면 밖으로 나가지 않도록
                              // 상단 최소 5%, 하단 최대 85%
                              newDy = newDy.clamp(0.05, 0.85);

                              _textPosition = Offset(_textPosition.dx, newDy);
                              _style = _style.copyWith(
                                textPosition: _textPosition,
                              );
                            });
                          }
                        : null,
                    child: Container(
                      key: _textKey,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        // 텍스트 편집 모드일 때 테두리 표시
                        border:
                            !_isEditingImage && widget.backgroundImage != null
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C4DFF).withValues(alpha: 0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.6),
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.notoSans(
                fontSize: 12,
                color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.6),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
                color:
                    iconColor ??
                    (isActive
                        ? const Color(0xFF7C4DFF)
                        : Colors.white.withValues(alpha: 0.7)),
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
