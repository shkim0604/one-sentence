import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/wallpaper_service.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _sentenceController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  List<String> _recentSentences = [];
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  bool _isLoadingWallpaper = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSentences();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _sentenceController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSentences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSentences = prefs.getStringList('recent_sentences') ?? [];
    });
  }

  Future<void> _saveSentence(String sentence) async {
    if (sentence.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _recentSentences.remove(sentence);
    _recentSentences.insert(0, sentence);
    if (_recentSentences.length > 10) {
      _recentSentences = _recentSentences.sublist(0, 10);
    }
    await prefs.setStringList('recent_sentences', _recentSentences);
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _loadCurrentWallpaper() async {
    if (!WallpaperService.supportsGetCurrentWallpaper()) {
      _showSnackBar('iOS에서는 현재 배경화면을 가져올 수 없습니다.\n갤러리에서 이미지를 선택해주세요.', isError: true);
      return;
    }

    setState(() => _isLoadingWallpaper = true);

    try {
      final wallpaperFile = await WallpaperService.getCurrentWallpaper();
      
      if (wallpaperFile != null) {
        setState(() {
          _selectedImage = wallpaperFile;
        });
        _showSnackBar('현재 배경화면을 불러왔습니다! ✨');
      } else {
        _showSnackBar('배경화면을 가져올 수 없습니다.', isError: true);
      }
    } catch (e) {
      _showSnackBar('오류가 발생했습니다: $e', isError: true);
    } finally {
      setState(() => _isLoadingWallpaper = false);
    }
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

  void _showImageSourcePicker() {
    final supportsCurrentWallpaper = WallpaperService.supportsGetCurrentWallpaper();

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
              '배경 이미지 선택',
              style: GoogleFonts.notoSans(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            
            // 현재 배경화면 사용 (Android만)
            if (supportsCurrentWallpaper)
              _buildImageSourceTile(
                icon: Icons.wallpaper,
                title: '현재 배경화면 사용',
                subtitle: '지금 사용 중인 배경화면을 불러옵니다',
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFFFF6B9D)],
                ),
                onTap: () {
                  Navigator.pop(context);
                  _loadCurrentWallpaper();
                },
              ),
            
            if (supportsCurrentWallpaper) const SizedBox(height: 12),
            
            // 갤러리에서 선택
            _buildImageSourceTile(
              icon: Icons.photo_library_outlined,
              title: '갤러리에서 선택',
              subtitle: '저장된 사진 중에서 선택합니다',
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            
            const SizedBox(height: 12),
            
            // 기본 배경 사용
            _buildImageSourceTile(
              icon: Icons.gradient,
              title: '기본 배경 사용',
              subtitle: '이미지 없이 그라데이션 배경을 사용합니다',
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedImage = null);
              },
            ),
            
            if (!supportsCurrentWallpaper) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'iOS에서는 보안상의 이유로 현재 배경화면을 직접 가져올 수 없습니다.',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceTile({
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

  void _goToEditor() {
    final sentence = _sentenceController.text.trim();
    if (sentence.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '문장을 입력해주세요',
            style: GoogleFonts.notoSans(),
          ),
          backgroundColor: const Color(0xFF1E1E2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    _saveSentence(sentence);

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => EditorScreen(
          sentence: sentence,
          backgroundImage: _selectedImage,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0F),
              Color(0xFF151525),
              Color(0xFF0D0D15),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        // 앱 타이틀
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF7C4DFF), Color(0xFFFF6B9D)],
                          ).createShader(bounds),
                          child: Text(
                            '한 문장',
                            style: GoogleFonts.notoSans(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '오늘 하루를 함께할 문장을 입력하세요',
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 48),

                        // 문장 입력 섹션
                        _buildSentenceInput(),
                        const SizedBox(height: 32),

                        // 배경 이미지 선택 섹션
                        _buildImageSelector(),
                        const SizedBox(height: 40),

                        // 배경화면 만들기 버튼
                        _buildCreateButton(),
                        const SizedBox(height: 48),

                        // 최근 문장 섹션
                        if (_recentSentences.isNotEmpty) _buildRecentSentences(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSentenceInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFFFF6B9D)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '오늘의 문장',
              style: GoogleFonts.notoSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E1E2E).withValues(alpha: 0.8),
                const Color(0xFF252535).withValues(alpha: 0.6),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: TextField(
            controller: _sentenceController,
            maxLines: 4,
            style: GoogleFonts.notoSans(
              fontSize: 18,
              color: Colors.white,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: '"오늘도 한 걸음씩 나아가자"',
              hintStyle: GoogleFonts.notoSans(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.3),
                fontStyle: FontStyle.italic,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFFB366)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '배경 이미지',
              style: GoogleFonts.notoSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            if (_selectedImage != null)
              TextButton(
                onPressed: () => setState(() => _selectedImage = null),
                child: Text(
                  '제거',
                  style: GoogleFonts.notoSans(
                    color: const Color(0xFFFF6B9D),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _showImageSourcePicker,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: _selectedImage == null
                  ? LinearGradient(
                      colors: [
                        const Color(0xFF1E1E2E).withValues(alpha: 0.6),
                        const Color(0xFF252535).withValues(alpha: 0.4),
                      ],
                    )
                  : null,
              border: Border.all(
                color: _selectedImage != null
                    ? const Color(0xFF7C4DFF).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.05),
                width: _selectedImage != null ? 2 : 1,
              ),
              image: _selectedImage != null
                  ? DecorationImage(
                      image: FileImage(_selectedImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _selectedImage == null
                ? Center(
                    child: _isLoadingWallpaper
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                color: Color(0xFF7C4DFF),
                                strokeWidth: 2,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '배경화면을 불러오는 중...',
                                style: GoogleFonts.notoSans(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                                ),
                                child: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: Color(0xFF7C4DFF),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '탭하여 배경 이미지 선택',
                                style: GoogleFonts.notoSans(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '현재 배경화면 또는 갤러리에서 선택',
                                style: GoogleFonts.notoSans(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  )
                : Stack(
                    children: [
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '변경',
                                style: GoogleFonts.notoSans(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _goToEditor,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFFFF6B9D)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, size: 22),
                const SizedBox(width: 12),
                Text(
                  '배경화면 만들기',
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSentences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF66D9EF), Color(0xFF7C4DFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '최근 문장',
              style: GoogleFonts.notoSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(
          _recentSentences.length > 5 ? 5 : _recentSentences.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                _sentenceController.text = _recentSentences[index];
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _recentSentences[index],
                        style: GoogleFonts.notoSans(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
