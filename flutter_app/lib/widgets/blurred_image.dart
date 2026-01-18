import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../config/theme.dart';

class BlurredImage extends StatefulWidget {
  final String imageUrl;
  final double width;
  final VoidCallback onTapFullScreen;

  const BlurredImage({
    super.key,
    required this.imageUrl,
    this.width = 200,
    required this.onTapFullScreen,
  });

  @override
  State<BlurredImage> createState() => _BlurredImageState();
}

class _BlurredImageState extends State<BlurredImage> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isRevealed) {
          widget.onTapFullScreen();
        } else {
          setState(() {
            _isRevealed = true;
          });
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 이미지
            CachedNetworkImage(
              imageUrl: widget.imageUrl,
              width: widget.width,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: widget.width,
                height: 150,
                color: AppTheme.darkCard,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: widget.width,
                height: 150,
                color: AppTheme.darkCard,
                child: const Icon(Icons.error, color: Colors.white54),
              ),
            ),
            // 블러 오버레이 (해제되지 않은 경우)
            if (!_isRevealed)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.visibility_off,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '터치하여 보기',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
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
            // 확대 아이콘 (블러 해제 후)
            if (_isRevealed)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
