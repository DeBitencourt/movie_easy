import 'download_item.dart';
import 'media_item.dart';

/// Representa um título agregado na Biblioteca do usuário (um filme único ou uma série completa com múltiplos episódios).
class LibraryEntry {
  final String key;
  final String title;
  final MediaTypeEnum mediaType;
  final String? mediaId;
  final String? posterUrl;
  final String? backdropUrl;
  final List<DownloadItem> episodes;

  LibraryEntry({
    required this.key,
    required this.title,
    required this.mediaType,
    this.mediaId,
    this.posterUrl,
    this.backdropUrl,
    required this.episodes,
  });

  /// Determina se a entrada é uma série / dorama episódico.
  bool get isSeries =>
      mediaType != MediaTypeEnum.movie &&
      (mediaType == MediaTypeEnum.tv ||
       mediaType == MediaTypeEnum.dorama ||
       episodes.length > 1 ||
       episodes.any((e) => e.resolvedEpisodeNumber != null));

  /// Quantidade total de episódios/vídeos baixados para este título.
  int get episodeCount => episodes.length;

  /// Total de bytes ocupados no disco por todos os episódios desta entrada.
  int get totalDiskUsage {
    int total = 0;
    for (final e in episodes) {
      total += e.totalDone > 0 ? e.totalDone : e.totalWanted;
    }
    return total;
  }

  /// Tamanho total formatado (ex: "4.5 GB" ou "380 MB").
  String get formattedSize {
    final bytes = totalDiskUsage;
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  /// Melhor qualidade encontrada nos episódios.
  String? get quality {
    for (final e in episodes) {
      if (e.quality != null && e.quality!.isNotEmpty) return e.quality;
    }
    return null;
  }

  /// Tipo de áudio / legenda predominante.
  String? get audio {
    for (final e in episodes) {
      if (e.audio != null && e.audio!.isNotEmpty) return e.audio;
    }
    return null;
  }

  /// Primeiro episódio para início rápido de reprodução.
  DownloadItem get firstEpisode {
    if (episodes.isEmpty) {
      throw StateError('Nenhum episódio disponível para $title');
    }
    return episodes.first;
  }

  /// Converte a entrada em um MediaItem para navegação ao catálogo online (DetailsView).
  MediaItem toMediaItem() {
    return MediaItem(
      id: mediaId ?? title.hashCode.toString(),
      title: title,
      originalTitle: title,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      overview: 'Item salvo na sua biblioteca offline.',
      rating: 0.0,
      type: mediaType,
      episodeCount: isSeries ? episodeCount : null,
    );
  }

  /// Agrupa uma lista plana de DownloadItems em LibraryEntrys organizadas por obra/série.
  static List<LibraryEntry> groupFromDownloadItems(List<DownloadItem> rawItems) {
    if (rawItems.isEmpty) return [];

    final Map<String, List<DownloadItem>> grouped = {};

    for (final item in rawItems) {
      final cleanTitle = item.cleanMediaTitle;
      final type = item.mediaType ?? (
        (item.resolvedEpisodeNumber != null || item.resolvedSeasonNumber != null)
            ? MediaTypeEnum.tv
            : MediaTypeEnum.movie
      );

      // Chave de agrupamento: usar mediaId quando disponível; caso contrário, tipo + título limpo
      final groupKey = (item.mediaId != null && item.mediaId!.isNotEmpty)
          ? '${type.name}_${item.mediaId}'
          : '${type.name}_${cleanTitle.toLowerCase().trim()}';

      grouped.putIfAbsent(groupKey, () => []).add(item);
    }

    final List<LibraryEntry> entries = [];

    for (final entry in grouped.entries) {
      final list = entry.value;
      if (list.isEmpty) continue;

      // Ordenar episódios numericamente por temporada e número do episódio
      list.sort((a, b) {
        final sA = a.resolvedSeasonNumber ?? 1;
        final sB = b.resolvedSeasonNumber ?? 1;
        if (sA != sB) return sA.compareTo(sB);

        final eA = a.resolvedEpisodeNumber ?? 0;
        final eB = b.resolvedEpisodeNumber ?? 0;
        if (eA != eB) return eA.compareTo(eB);

        return a.title.compareTo(b.title);
      });

      final first = list.first;
      final cleanTitle = first.cleanMediaTitle;
      final type = first.mediaType ?? (
        (first.resolvedEpisodeNumber != null || first.resolvedSeasonNumber != null)
            ? MediaTypeEnum.tv
            : MediaTypeEnum.movie
      );

      String? poster = list.firstWhere((i) => i.posterUrl != null && i.posterUrl!.isNotEmpty, orElse: () => first).posterUrl;
      String? backdrop = list.firstWhere((i) => i.backdropUrl != null && i.backdropUrl!.isNotEmpty, orElse: () => first).backdropUrl;

      entries.add(
        LibraryEntry(
          key: entry.key,
          title: cleanTitle,
          mediaType: type,
          mediaId: first.mediaId,
          posterUrl: poster,
          backdropUrl: backdrop,
          episodes: list,
        ),
      );
    }

    // Ordenar as obras: as mais recentes primeiro
    entries.sort((a, b) {
      final dateA = a.episodes.map((e) => e.addedAt).reduce((val, el) => val.isAfter(el) ? val : el);
      final dateB = b.episodes.map((e) => e.addedAt).reduce((val, el) => val.isAfter(el) ? val : el);
      return dateB.compareTo(dateA);
    });

    return entries;
  }
}
