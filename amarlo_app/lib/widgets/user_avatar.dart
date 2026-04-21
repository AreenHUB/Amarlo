// lib/widgets/user_avatar.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════
//  UserAvatar — صورة دائرية
// ══════════════════════════════════════════════
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.radius = 25,
    this.fallbackIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            // لا تُخزّن الأخطاء في الـ cache
            cacheKey: url,
            placeholder: (_, __) => SizedBox(
              width: radius,
              height: radius,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (_, __, ___) {
              // امسح الـ cache عند الخطأ لإعادة المحاولة عند التحديث
              CachedNetworkImage.evictFromCache(url);
              return Icon(fallbackIcon, size: radius, color: Colors.grey[500]);
            },
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: Icon(fallbackIcon, size: radius, color: Colors.grey[500]),
    );
  }
}

// ══════════════════════════════════════════════
//  AppNetworkImage — صورة مستطيلة
// ══════════════════════════════════════════════
class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final BorderRadius? borderRadius;

  const AppNetworkImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    Widget _fallback() =>
        placeholder ??
        Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.image_outlined, color: Colors.grey),
        );

    if (url == null || url.isEmpty) return _fallback();

    Widget img = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      cacheKey: url,
      placeholder: (_, __) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      errorWidget: (_, __, ___) {
        CachedNetworkImage.evictFromCache(url);
        return _fallback();
      },
    );

    if (borderRadius != null) {
      img = ClipRRect(borderRadius: borderRadius!, child: img);
    }

    return img;
  }
}
