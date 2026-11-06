import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/themes/responsive.dart';
import 'package:flutter/material.dart';

class NetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final Widget? errorWidget;
  final BoxFit? fit;
  final double? borderRadius;
  final Color? color;

  const NetworkImageWidget({
    super.key,
    this.height,
    this.width,
    this.fit,
    required this.imageUrl,
    this.borderRadius,
    this.errorWidget,
    this.color,
  });

  bool get _hasValidUrl {
    final url = imageUrl.trim();
    return url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));
  }

  bool get _hasValidPlaceholder {
    final url = Constant.placeHolderImage.trim();
    return url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));
  }

  Widget _fallback(BuildContext context) {
    if (errorWidget != null) return errorWidget!;
    final h = height ?? Responsive.height(8, context);
    final w = width ?? Responsive.width(15, context);
    if (_hasValidPlaceholder) {
      return Image.network(
        Constant.placeHolderImage,
        fit: fit ?? BoxFit.fitWidth,
        height: h,
        width: w,
        errorBuilder: (_, __, ___) => _iconFallback(h, w),
      );
    }
    return _iconFallback(h, w);
  }

  Widget _iconFallback(double h, double w) {
    return Container(
      height: h,
      width: w,
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: (h < w ? h : w) * 0.5, color: Colors.grey.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidUrl) {
      return _fallback(context);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl.trim(),
      fit: fit ?? BoxFit.fitWidth,
      height: height ?? Responsive.height(8, context),
      width: width ?? Responsive.width(15, context),
      color: color,
      progressIndicatorBuilder: (context, url, downloadProgress) =>
          Constant.loader(),
      errorWidget: (context, url, error) => _fallback(context),
    );
  }
}
