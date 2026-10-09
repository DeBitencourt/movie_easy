import 'dart:developer' as developer;
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/torrent_item.dart';
import 'doh_service.dart';

/// Resultado simplificado da listagem de postagens encontradas na pesquisa.
class ComandoPost {
  final String title;
  final String url;
  final String? thumbnail;

  const ComandoPost({
    required this.title,
    required this.url,
    this.thumbnail,
  });
}

/// Serviço de busca e extração de links de torrents do Comando Torrents (comandotorrents.to).
/// Utiliza DoH (DNS-over-HTTPS) para garantir funcionamento mesmo em redes com bloqueio de DNS.
class ComandoTorrentsService {
  static const String baseUrl = 'https://comandotorrents.to';

  /// Trackers públicos de alta velocidade para acelerar descoberta de pares
  static final List<String> _fastTrackers = [
    'udp://tracker.opentrackr.org:1337/announce',
    'udp://open.tracker.cl:1337/announce',
    'udp://open.demonii.com:1337/announce',
    'udp://open.stealth.si:80/announce',
    'udp://tracker.torrent.eu.org:451/announce',
    'udp://explodie.org:6969/announce',
    'udp://tracker.skynetcloud.site:6969/announce',
    'udp://tracker.bittor.pw:1337/announce',
    'udp://exodus.desync.com:6969/announce',
    'udp://tracker.dler.org:6969/announce',
    'udp://p4p.arenabg.com:1337/announce',
    'udp://tracker.moeking.me:6969/announce',
    'udp://opentor.org:2710/announce',
    'udp://tracker.openbittorrent.com:80/announce',
    'http://tracker.openbittorrent.com:80/announce',
  ];

  /// Remove subtítulos (ex: "Brooklyn Nine-Nine: Lei e Desordem" -> "Brooklyn Nine-Nine")
  static String cleanTitle(String rawTitle) {
    var title = rawTitle;
    if (title.contains(':')) {
      final parts = title.split(':');
      if (parts.first.trim().isNotEmpty) {
        title = parts.first.trim();
      }
    }
    // Remove pontuações desnecessárias que possam atrapalhar a busca
    return title.replaceAll(RegExp(r'[^\w\s\u00C0-\u00FF-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Extrai o número da temporada contido no título da postagem, se houver
  static int? extractSeasonFromTitle(String title) {
    final match = RegExp(
      r'(\d+)[ªa°º]\s*Temporada|Season\s*(\d+)|S0?(\d+)',
      caseSensitive: false,
    ).firstMatch(title);
    if (match != null) {
      final s = match.group(1) ?? match.group(2) ?? match.group(3);
      if (s != null) return int.tryParse(s);
    }
    return null;
  }

  /// Injeta trackers ativos de alta velocidade no link magnético para acelerar conexão
  static String injectFastTrackers(String magnetUrl) {
    var uri = magnetUrl;
    for (final tr in _fastTrackers) {
      final encoded = Uri.encodeComponent(tr);
      if (!uri.contains(encoded)) {
        uri += '&tr=$encoded';
      }
    }
    return uri;
  }

  /// Realiza uma pesquisa por termo no site e retorna a lista de postagens encontradas.
  static Future<List<ComandoPost>> searchPosts(String query) async {
    final cleanQuery = query.replaceAll(RegExp(r'[^\w\s\u00C0-\u00FF-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanQuery.isEmpty) return [];

    final searchUrl = '$baseUrl/?s=${Uri.encodeComponent(cleanQuery)}';
    try {
      final html = await DohService.getHtml(searchUrl);
      final document = html_parser.parse(html);
      final articles = document.querySelectorAll('article');

      final posts = <ComandoPost>[];
      for (final article in articles) {
        final titleElement = article.querySelector('h2.entry-title a');
        final title = titleElement?.text.trim() ?? '';
        final url = titleElement?.attributes['href'] ?? '';
        if (url.isEmpty || title.isEmpty) continue;

        final img = article.querySelector('img')?.attributes['src'];
        posts.add(ComandoPost(
          title: title,
          url: url,
          thumbnail: img,
        ));
      }
      return posts;
    } catch (e, st) {
      developer.log('Erro ao buscar posts no ComandoTorrents: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Extrai todos os links magnéticos e metadados de uma página de postagem específica.
  static Future<List<TorrentItem>> getTorrentsFromPost(
    String postUrl, {
    String? postTitle,
    int? targetSeason,
    int? targetEpisode,
  }) async {
    try {
      final html = await DohService.getHtml(postUrl);
      final document = html_parser.parse(html);

      final title = postTitle ?? document.querySelector('h1.entry-title')?.text.trim() ?? 'Torrent';
      final magnetElements = document.querySelectorAll('a[href^="magnet:?"]');
      final torrents = <TorrentItem>[];

      for (final a in magnetElements) {
        final magnet = a.attributes['href'] ?? '';
        if (magnet.isEmpty) continue;

        final item = _parseMagnetElement(
          element: a,
          postTitle: title,
          postUrl: postUrl,
          targetSeason: targetSeason,
          targetEpisode: targetEpisode,
        );

        if (item != null) {
          torrents.add(item);
        }
      }

      return torrents;
    } catch (e, st) {
      developer.log('Erro ao extrair torrents do post ($postUrl): $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Busca torrents com estratégias avançadas para isolamento correto de temporada e episódio.
  static Future<List<TorrentItem>> searchTorrents({
    required String title,
    String? originalTitle,
    int? year,
    int? season,
    int? episode,
    bool preferDubbed = true,
  }) async {
    final mainClean = cleanTitle(title);
    final origClean = originalTitle != null ? cleanTitle(originalTitle) : null;

    final candidateQueries = <String>[];

    // Se uma temporada específica foi solicitada, priorizar termos explícitos da temporada
    if (season != null && !RegExp('temporada|season|s0?$season', caseSensitive: false).hasMatch(mainClean)) {
      candidateQueries.add('$mainClean $seasonª Temporada');
      candidateQueries.add('$mainClean S0$season');
      candidateQueries.add('$mainClean Temporada $season');
      if (origClean != null && origClean != mainClean && !RegExp('temporada|season|s0?$season', caseSensitive: false).hasMatch(origClean)) {
        candidateQueries.add('$origClean $seasonª Temporada');
        candidateQueries.add('$origClean S0$season');
      }
    }

    // Termos gerais de busca
    candidateQueries.add(mainClean);
    if (origClean != null && origClean != mainClean) {
      candidateQueries.add(origClean);
    }

    final validPosts = <ComandoPost>[];

    for (final query in candidateQueries) {
      final postsFound = await searchPosts(query);
      if (postsFound.isEmpty) continue;

      for (final p in postsFound) {
        // Se uma temporada específica foi requisitada, descartar posts explicitamente de OUTRAS temporadas
        if (season != null) {
          final postSeason = extractSeasonFromTitle(p.title);
          if (postSeason != null && postSeason != season) {
            // É de outra temporada, ignorar
            continue;
          }
        }

        if (!validPosts.any((existing) => existing.url == p.url)) {
          validPosts.add(p);
        }
      }

      // Se a query era específica para a temporada e encontramos posts válidos, podemos parar
      if (season != null && validPosts.isNotEmpty) {
        break;
      }
    }

    if (validPosts.isEmpty) {
      return [];
    }

    // Extrair torrents dos posts selecionados
    final allTorrents = <TorrentItem>[];
    for (final post in validPosts.take(3)) {
      final items = await getTorrentsFromPost(
        post.url,
        postTitle: post.title,
        targetSeason: season,
        targetEpisode: episode,
      );
      allTorrents.addAll(items);
    }

    // Remover duplicatas de infoHash
    final uniqueMap = <String, TorrentItem>{};
    for (final t in allTorrents) {
      if (!uniqueMap.containsKey(t.infoHash)) {
        uniqueMap[t.infoHash] = t;
      }
    }

    final sortedList = uniqueMap.values.toList();

    // Ordenação por relevância:
    // 1. Se pediu episódio, o episódio individual vem ANTES do pack completo
    // 2. Dublado primeiro (se preferDubbed)
    // 3. Maior resolução (4K > 1080p > 720p)
    sortedList.sort((a, b) {
      if (episode != null) {
        final aIsExact = a.episodeNumber == episode;
        final bIsExact = b.episodeNumber == episode;
        if (aIsExact && !bIsExact) return -1;
        if (!aIsExact && bIsExact) return 1;
      }

      if (preferDubbed) {
        if (a.isDubbed && !b.isDubbed) return -1;
        if (!a.isDubbed && b.isDubbed) return 1;
      }

      final scoreA = _qualityScore(a.quality);
      final scoreB = _qualityScore(b.quality);
      return scoreB.compareTo(scoreA);
    });

    return sortedList;
  }

  static TorrentItem? _parseMagnetElement({
    required Element element,
    required String postTitle,
    required String postUrl,
    int? targetSeason,
    int? targetEpisode,
  }) {
    final rawMagnet = element.attributes['href'] ?? '';
    final enhancedMagnet = injectFastTrackers(rawMagnet);

    final parent = element.parent;
    final prev = parent?.previousElementSibling;

    var combinedText = '${prev?.text ?? ''} ${parent?.text ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Extração de Qualidade
    String quality = 'HD';
    if (RegExp(r'4K|2160p', caseSensitive: false).hasMatch(combinedText)) {
      quality = '4K';
    } else if (RegExp(r'1080p', caseSensitive: false).hasMatch(combinedText)) {
      quality = '1080p';
    } else if (RegExp(r'720p', caseSensitive: false).hasMatch(combinedText)) {
      quality = '720p';
    } else if (RegExp(r'480p', caseSensitive: false).hasMatch(combinedText)) {
      quality = '480p';
    }

    // Extração de Áudio
    final isDubbed = RegExp(r'dual|dublado', caseSensitive: false).hasMatch(combinedText) ||
        RegExp(r'dual|dublado', caseSensitive: false).hasMatch(postTitle);
    final isSubbed = RegExp(r'legendado|sub', caseSensitive: false).hasMatch(combinedText) ||
        RegExp(r'dual', caseSensitive: false).hasMatch(combinedText);

    // Extração de Tamanho
    final sizeMatch = RegExp(
      r'\((\d+(?:\.\d+)?\s*(?:GB|MB))\)|\|\s*\(?(\d+(?:\.\d+)?\s*(?:GB|MB))\)?',
      caseSensitive: false,
    ).firstMatch(combinedText);
    final size = sizeMatch != null ? (sizeMatch.group(1) ?? sizeMatch.group(2)) : null;

    // Formato de arquivo
    String? format;
    if (RegExp(r'mkv', caseSensitive: false).hasMatch(combinedText)) {
      format = 'MKV';
    } else if (RegExp(r'mp4', caseSensitive: false).hasMatch(combinedText)) {
      format = 'MP4';
    }

    // Extração de Episódio
    final epMatch = RegExp(r'(?:Epis[oó]dio|EP|E)\s*0?(\d+)', caseSensitive: false).firstMatch(combinedText);
    final epNumber = epMatch != null ? int.tryParse(epMatch.group(1)!) : null;

    // Filtro estrito se o usuário solicitou um episódio específico
    if (targetEpisode != null) {
      if (epNumber != null && epNumber != targetEpisode) {
        // Link de outro episódio individual, ignorar!
        return null;
      }
      if (epNumber == null) {
        // Se não tem número de episódio explícito, só mantemos se for "Temporada Completa"
        final isPack = RegExp(r'completa|pack', caseSensitive: false).hasMatch(combinedText) ||
            RegExp(r'completa|pack', caseSensitive: false).hasMatch(postTitle);
        if (!isPack) {
          return null;
        }
      }
    }

    // Formatar label mais limpo para exibição
    String displayLabel = combinedText;
    if (epNumber != null) {
      displayLabel = 'Episódio $epNumber [$quality]${size != null ? ' • $size' : ''}';
    } else if (RegExp(r'completa', caseSensitive: false).hasMatch(combinedText)) {
      displayLabel = 'Temporada Completa [$quality]${size != null ? ' • $size' : ''}';
    }

    return TorrentItem(
      title: postTitle,
      rawLabel: displayLabel.isNotEmpty ? displayLabel : combinedText,
      magnetUrl: enhancedMagnet,
      infoHash: TorrentItem.extractInfoHash(rawMagnet),
      quality: quality,
      size: size,
      isDubbed: isDubbed,
      isSubbed: isSubbed,
      format: format,
      episodeNumber: epNumber,
      source: 'Comando Torrents',
      pageUrl: postUrl,
    );
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
}
