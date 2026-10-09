import 'dart:convert';
import 'dart:developer' as developer;
import '../models/torrent_item.dart';
import 'comando_torrents_service.dart';
import 'doh_service.dart';

/// Serviço de integração com o The Pirate Bay via API pública oficial (apibay.org).
/// Excelente repositório global para Doramas, Séries ocidentais, Filmes e Animes.
class PirateBayService {
  static const String baseUrl = 'https://apibay.org';

  /// Realiza busca por torrents no The Pirate Bay retornando uma lista estruturada de [TorrentItem].
  static Future<List<TorrentItem>> searchTorrents({
    required String title,
    String? originalTitle,
    String? englishTitle,
    int? season,
    int? episode,
  }) async {
    final candidateQueries = <String>[];

    final cleanMain = ComandoTorrentsService.cleanTitle(title);
    final cleanOrig = originalTitle != null ? ComandoTorrentsService.cleanTitle(originalTitle) : null;
    final cleanEng = englishTitle != null ? ComandoTorrentsService.cleanTitle(englishTitle) : null;

    final names = <String>[];
    if (cleanEng != null && cleanEng.isNotEmpty) names.add(cleanEng);
    if (cleanOrig != null && cleanOrig.isNotEmpty && !names.contains(cleanOrig)) names.add(cleanOrig);
    if (cleanMain.isNotEmpty && !names.contains(cleanMain)) names.add(cleanMain);

    // 1. Queries com temporada e episódio específicos
    if (season != null && episode != null) {
      final sStr = season < 10 ? '0$season' : '$season';
      final epStr = episode < 10 ? '0$episode' : '$episode';
      for (final name in names) {
        candidateQueries.add('$name S${sStr}E$epStr');
        candidateQueries.add('$name $epStr');
      }
    } else if (episode != null) {
      final epStr = episode < 10 ? '0$episode' : '$episode';
      for (final name in names) {
        candidateQueries.add('$name E$epStr');
        candidateQueries.add('$name $epStr');
      }
    } else if (season != null && season > 1) {
      final sStr = season < 10 ? '0$season' : '$season';
      for (final name in names) {
        candidateQueries.add('$name S$sStr');
        candidateQueries.add('$name Season $season');
      }
    }

    // 2. Queries gerais
    for (final name in names) {
      candidateQueries.add(name);
    }

    final rawResults = <Map<String, dynamic>>[];
    final visitedHashes = <String>{};

    for (final q in candidateQueries) {
      final cleanQ = q.trim();
      if (cleanQ.isEmpty) continue;

      final url = '$baseUrl/q.php?q=${Uri.encodeComponent(cleanQ)}&cat=0';
      try {
        final body = await DohService.getHtml(url);
        if (body.isEmpty || !body.trim().startsWith('[')) continue;

        final decoded = jsonDecode(body) as List<dynamic>;
        for (final entry in decoded) {
          if (entry is Map<String, dynamic>) {
            final id = entry['id']?.toString() ?? '';
            final hash = (entry['info_hash'] as String? ?? '').trim().toUpperCase();

            // apibay retorna id "0" ou hash cheio de zeros quando não há resultados
            if (id == '0' || hash.isEmpty || hash.startsWith('00000000')) continue;

            if (!visitedHashes.contains(hash)) {
              visitedHashes.add(hash);
              rawResults.add(entry);
            }
          }
        }

        // Se encontrou bons resultados para a query específica de episódio, não precisa buscar tudo
        if (rawResults.length >= 10) {
          break;
        }
      } catch (e) {
        developer.log('Erro ao consultar The Pirate Bay ($url): $e');
      }
    }

    if (rawResults.isEmpty) return [];

    final torrents = <TorrentItem>[];

    for (final json in rawResults) {
      final name = json['name'] as String? ?? '';
      final infoHash = (json['info_hash'] as String? ?? '').trim().toUpperCase();
      final seeders = int.tryParse(json['seeders']?.toString() ?? '0');
      final leechers = int.tryParse(json['leechers']?.toString() ?? '0');
      final sizeBytes = int.tryParse(json['size']?.toString() ?? '0');

      if (name.isEmpty || infoHash.isEmpty) continue;

      final magnetUrl = ComandoTorrentsService.injectFastTrackers(
        'magnet:?xt=urn:btih:$infoHash&dn=${Uri.encodeComponent(name)}',
      );

      // Extração de Episódio e Temporada
      final epNumber = _extractEpisode(name);
      final sNumber = _extractSeason(name) ?? season;

      // Filtro estrito se usuário pediu episódio específico
      if (episode != null) {
        if (epNumber != null && epNumber != episode) {
          continue; // Episódio diferente
        }
        if (epNumber == null) {
          final isBatch = RegExp(r'batch|complete|temporada|season\s*\d+|s0?\d+(?!\s*e\d+)', caseSensitive: false).hasMatch(name);
          if (!isBatch) continue;
        }
      }

      // Extração de Qualidade
      final quality = _extractQuality(name);

      // Extração de Áudio e Legendas
      final isDubbed = RegExp(r'dual[- ]?audio|dublado|dub', caseSensitive: false).hasMatch(name);
      final isSubbed = RegExp(r'sub|subs|legendado|multi|vostfr|nf\s*web', caseSensitive: false).hasMatch(name) || !isDubbed;

      // Formato
      final format = name.toLowerCase().contains('.mp4') ? 'MP4' : 'MKV';

      // Tamanho formatado
      final formattedSize = sizeBytes != null && sizeBytes > 0 ? _formatBytes(sizeBytes) : null;

      torrents.add(
        TorrentItem(
          title: name,
          rawLabel: name,
          magnetUrl: magnetUrl,
          infoHash: infoHash,
          quality: quality,
          size: formattedSize,
          isDubbed: isDubbed,
          isSubbed: isSubbed,
          format: format,
          seasonNumber: sNumber,
          episodeNumber: epNumber,
          source: 'The Pirate Bay',
          seeders: seeders,
          leechers: leechers,
        ),
      );
    }

    // Ordenação:
    // 1. Episódio exato antes de batch
    // 2. Mais seeders primeiro
    // 3. Maior resolução (1080p > 720p > 480p)
    torrents.sort((a, b) {
      if (episode != null) {
        final aExact = a.episodeNumber == episode;
        final bExact = b.episodeNumber == episode;
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;
      }

      final seedsA = a.seeders ?? 0;
      final seedsB = b.seeders ?? 0;
      if (seedsA != seedsB) {
        return seedsB.compareTo(seedsA);
      }

      return _qualityScore(b.quality).compareTo(_qualityScore(a.quality));
    });

    return torrents;
  }

  static int? _extractEpisode(String title) {
    // S01E05, E05, EP05, - 05
    final match = RegExp(
      r'(?:s\d{1,2}e|ep|e|\s-\s*|episode\s+|\[)(0?\d{1,3})(?:v\d)?(?:\s|\]|\.|\)|$)',
      caseSensitive: false,
    ).firstMatch(title);

    if (match != null) {
      final numStr = match.group(1);
      if (numStr != null) {
        final parsed = int.tryParse(numStr);
        if (parsed != null && parsed <= 300 && parsed != 720 && parsed != 1080) {
          return parsed;
        }
      }
    }
    return null;
  }

  static int? _extractSeason(String title) {
    final match = RegExp(r's(0?\d{1,2})', caseSensitive: false).firstMatch(title);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  static String _extractQuality(String title) {
    if (RegExp(r'4K|2160p', caseSensitive: false).hasMatch(title)) return '4K';
    if (RegExp(r'1080p', caseSensitive: false).hasMatch(title)) return '1080p';
    if (RegExp(r'720p', caseSensitive: false).hasMatch(title)) return '720p';
    if (RegExp(r'480p', caseSensitive: false).hasMatch(title)) return '480p';
    return '1080p';
  }

  static int _qualityScore(String quality) {
    switch (quality.toUpperCase()) {
      case '4K':
        return 4;
      case '1080P':
        return 3;
      case '720P':
        return 2;
      case '480P':
        return 1;
      default:
        return 0;
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
