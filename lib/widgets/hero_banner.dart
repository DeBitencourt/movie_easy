import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/media_item.dart';
import '../providers/watch_later_provider.dart';

class HeroBanner extends StatelessWidget {
  final MediaItem? item;
  final Function(MediaItem) onPlay;
  final Function(MediaItem) onDetails;

  const HeroBanner({
    super.key,
    required this.item,
    required this.onPlay,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return const SizedBox(
        height: 380,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final media = item!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final watchLater = context.watch<WatchLaterProvider>();
    final isSaved = watchLater.isSaved(media.id);

    return Container(
      height: isDesktop ? 440 : 360,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagem de Fundo (Backdrop)
          if (media.backdropUrl != null && media.backdropUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: media.backdropUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorWidget: (_, __, ___) => Container(color: AppTheme.card),
            )
          else
            Container(color: AppTheme.card),

          // Gradiente Escuro Radial e Vertical para misturar perfeitamente com o fundo
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppTheme.background.withOpacity(0.5),
                  AppTheme.background.withOpacity(0.95),
                  AppTheme.background,
                ],
                stops: const [0.0, 0.45, 0.8, 1.0],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppTheme.background.withOpacity(0.95),
                  AppTheme.background.withOpacity(0.6),
                  Colors.transparent,
                ],
                stops: [0.0, isDesktop ? 0.45 : 0.7, 1.0],
              ),
            ),
          ),

          // Conteúdo do Banner
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 650 : double.infinity),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badges (Destaque e Tipo)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'EM DESTAQUE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.card.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          media.type.label.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (media.rating > 0) ...[
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: AppTheme.starRating),
                            const SizedBox(width: 3),
                            Text(
                              media.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Título Principal
                  Text(
                    media.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: isDesktop ? 32 : 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Sinopse Curta
                  Text(
                    media.overview,
                    maxLines: isDesktop ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Botões de Ação
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => onPlay(media),
                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                        label: const Text('Assistir / Torrents'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 4,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => onDetails(media),
                        icon: const Icon(Icons.info_outline_rounded, size: 20),
                        label: const Text('Mais Detalhes'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          backgroundColor: AppTheme.card.withOpacity(0.7),
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final added = await watchLater.toggleWatchLater(media);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).removeCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(added
                                    ? '"${media.title}" adicionado a Assistir Mais Tarde.'
                                    : '"${media.title}" removido de Assistir Mais Tarde.'),
                                backgroundColor: AppTheme.card,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                          size: 20,
                          color: isSaved ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                        label: Text(isSaved ? 'Na Lista' : 'Salvar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isSaved ? AppTheme.primary : AppTheme.textPrimary,
                          backgroundColor: isSaved
                              ? AppTheme.primary.withOpacity(0.15)
                              : AppTheme.card.withOpacity(0.7),
                          side: BorderSide(
                            color: isSaved ? AppTheme.primary : AppTheme.border,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
