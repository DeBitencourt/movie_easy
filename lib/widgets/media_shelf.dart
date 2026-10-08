import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/media_item.dart';
import 'media_card.dart';
import 'custom_shimmer.dart';

class MediaShelf extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final bool isLoading;
  final Function(MediaItem) onSelect;
  final VoidCallback? onSeeAll;

  const MediaShelf({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    this.isLoading = false,
    required this.onSelect,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho da Seção
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              if (onSeeAll != null)
                TextButton.icon(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const SizedBox.shrink(),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Ver todos',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 12),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Lista Horizontal de Itens
        SizedBox(
          height: 245,
          child: isLoading
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 6,
                  itemBuilder: (_, __) => const MediaCardSkeleton(),
                )
              : items.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum item encontrado nesta seção.',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      clipBehavior: Clip.none,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: MediaCard(
                            item: item,
                            onTap: () => onSelect(item),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
