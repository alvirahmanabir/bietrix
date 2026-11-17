import 'package:flutter/material.dart';

/// Offline-friendly placeholder imagery. `imageKey` is what an upload service would
/// later replace with a cloud-storage URL (swap this widget's body for Image.network).
class MockImage extends StatelessWidget {
  const MockImage({super.key, required this.imageKey, this.height, this.width, this.radius = 0, this.iconSize = 40});
  final String imageKey;
  final double? height;
  final double? width;
  final double radius;
  final double iconSize;

  static const Map<String, (List<Color>, IconData)> styles = {
    'wedding': ([Color(0xFFEC4899), Color(0xFF7C3AED)], Icons.favorite),
    'portrait': ([Color(0xFF6366F1), Color(0xFFA855F7)], Icons.person),
    'corporate': ([Color(0xFF0EA5E9), Color(0xFF4F46E5)], Icons.business_center),
    'birthday': ([Color(0xFFF59E0B), Color(0xFFEC4899)], Icons.cake),
    'drone': ([Color(0xFF14B8A6), Color(0xFF2563EB)], Icons.flight),
    'video': ([Color(0xFFEF4444), Color(0xFF7C3AED)], Icons.videocam),
    'album': ([Color(0xFF8B5CF6), Color(0xFFDB2777)], Icons.photo_album),
    'studio': ([Color(0xFF475569), Color(0xFF7C3AED)], Icons.lightbulb),
    'camera': ([Color(0xFF7C3AED), Color(0xFF2563EB)], Icons.camera_alt),
    'editing': ([Color(0xFF10B981), Color(0xFF6366F1)], Icons.tune),
    'festival': ([Color(0xFFF97316), Color(0xFFDB2777)], Icons.celebration),
    'live': ([Color(0xFFE11D48), Color(0xFF9333EA)], Icons.live_tv),
  };

  @override
  Widget build(BuildContext context) {
    final s = styles[imageKey] ?? styles['studio']!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(gradient: LinearGradient(colors: s.$1, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Center(child: Icon(s.$2, size: iconSize, color: Colors.white.withValues(alpha: 0.9))),
      ),
    );
  }
}
