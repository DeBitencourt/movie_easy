import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_theme.dart';

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.card,
      highlightColor: AppTheme.cardHover,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class MediaCardSkeleton extends StatelessWidget {
  const MediaCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Expanded(
            child: ShimmerBox(width: double.infinity, height: double.infinity, borderRadius: 12),
          ),
          SizedBox(height: 8),
          ShimmerBox(width: 120, height: 14, borderRadius: 4),
          SizedBox(height: 4),
          ShimmerBox(width: 60, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}
