import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:http/http.dart' as http;
import '../models/torrent_item.dart';

class KisskhEpisode {
  final int id;
  final int number;
  final int subCount;

  const KisskhEpisode({
    required this.id,
    required this.number,
    required this.subCount,
  });

  factory KisskhEpisode.fromJson(Map<String, dynamic> json) {
    return KisskhEpisode(
      id: json['id'] as int? ?? 0,
      number: (json['number'] as num?)?.toInt() ?? 1,
      subCount: (json['sub'] as num?)?.toInt() ?? 0,
    );
  }
}

class KisskhDrama {
  final int id;
  final String title;
  final int episodesCount;
  final String? thumbnail;

  const KisskhDrama({
    required this.id,
    required this.title,
    required this.episodesCount,
    this.thumbnail,
  });

  factory KisskhDrama.fromJson(Map<String, dynamic> json) {
    return KisskhDrama(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      episodesCount: (json['episodesCount'] as num?)?.toInt() ?? 0,
      thumbnail: json['thumbnail'] as String?,
    );
  }
}

class KisskhSubtitle {
  final String src;
  final String label;
  final String lang;
  final bool isDefault;

  const KisskhSubtitle({
    required this.src,
    required this.label,
    required this.lang,
    required this.isDefault,
  });

  factory KisskhSubtitle.fromJson(Map<String, dynamic> json) {
    return KisskhSubtitle(
      src: json['src'] as String? ?? '',
      label: json['label'] as String? ?? 'Legenda',
      lang: json['land'] as String? ?? 'en',
      isDefault: json['default'] as bool? ?? false,
    );
  }
}

class KisskhStreamSource {
  final String m3u8Url;
  final String? directTsUrl;
  final List<KisskhSubtitle> subtitles;

  const KisskhStreamSource({
    required this.m3u8Url,
    this.directTsUrl,
    this.subtitles = const [],
  });
}

/// Serviço integrado para a plataforma KissKH (doramas asiáticos, K-Dramas, J-Dramas, C-Dramas).
/// Implementa descriptografia/assinatura própria e extração de vídeo direto e legendas via CDN de alta velocidade.
class KisskhService {
  static const String _baseUrl = 'https://kisskh.co/api';
  static const String _videoGuid = '62f176f3bb1b5b8e70e39932ad34a0c7';
  static const String _subGuid = 'VgV52sWhwvBSf8BsM3BRY9weWiiCbtGp';
  static const String _appVer = '2.8.10';
  static const String _platformVer = '4830201';
  static const String _appName = 'kisskh';

  static final Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://kisskh.co/',
  };

  /// Calcula o hash da carga útil da requisição para verificação no servidor KissKH.
  static int _calcHash(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      int shifted = ((hash & 0xFFFFFFFF).toSigned(32) << 5).toSigned(32);
      hash = shifted - hash + str.codeUnitAt(i);
    }
    return hash;
  }

  /// Gera a chave de autenticação (kkey) para requisições de episódios e legendas
  /// utilizando criptografia AES-128-CBC compatível com o cliente web do KissKH.
  static String generateKey(int episodeId, String guid) {
    final parts = [
      '',
      episodeId.toString(),
      '',
      'mg3c3b04ba',
      _appVer,
      guid,
      _platformVer,
      _appName,
      _appName,
      _appName,
      _appName,
      _appName,
      _appName,
      '00',
      ''
    ];

    final initialJoin = parts.join('|');
    final hashVal = _calcHash(initialJoin);
    parts.insert(1, hashVal.toString());
    final fullPayload = parts.join('|');

    final keyBytes = Uint8List.fromList([
      0x4f, 0x6b, 0xda, 0xa3,
      0x9e, 0x2f, 0x8c, 0xb0,
      0x7f, 0x5e, 0x72, 0x2d,
      0x9e, 0xde, 0xf3, 0x14
    ]);

    final ivBytes = Uint8List.fromList([
      0x01, 0x50, 0x4a, 0xf3,
      0x56, 0xe6, 0x19, 0xcf,
      0x2e, 0x42, 0xbb, 0xa6,
      0x8c, 0x3f, 0x70, 0xf9
    ]);

    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encrypt(fullPayload, iv: iv);
    return encrypted.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toUpperCase();
  }

  /// Extrai com segurança o ID interno do episódio do KissKH (ex: 203271).
  static int? extractEpisodeId(String magnetUrl, String infoHash) {
    // 1. Tentar de infoHash: KISSKH_12188_203271
    final parts = infoHash.split('_');
    if (parts.length >= 3) {
      final id = int.tryParse(parts[2]);
      if (id != null && id > 100) return id;
    }

    // 2. Tentar da magnetUrl: kisskh://dramaId/episodeId/epNumber
    final uri = Uri.tryParse(magnetUrl);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final id = int.tryParse(uri.pathSegments[0]);
      if (id != null && id > 100) return id;
    }

    return null;
  }

  /// Busca doramas por termo de pesquisa.
  static Future<List<KisskhDrama>> searchDrama(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    try {
      final uri = Uri.parse('$_baseUrl/DramaList/Search?q=${Uri.encodeComponent(clean)}&type=0');
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return [];
      final dynamic decoded = jsonDecode(resp.body);
      if (decoded is! List) return [];

      return decoded
          .map((item) => KisskhDrama.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Erro KisskhService.searchDrama: $e');
      return [];
    }
  }

  /// Obtém detalhes de um dorama e sua lista de episódios disponíveis.
  static Future<List<KisskhEpisode>> getDramaEpisodes(int dramaId) async {
    try {
      final uri = Uri.parse('$_baseUrl/DramaList/Drama/$dramaId');
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return [];
      final dynamic decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return [];

      final eps = decoded['episodes'];
      if (eps is! List) return [];

      final list = eps
          .map((e) => KisskhEpisode.fromJson(e as Map<String, dynamic>))
          .toList();

      // Ordenar episódios numericamente em ordem crescente
      list.sort((a, b) => a.number.compareTo(b.number));
      return list;
    } catch (e) {
      developer.log('Erro KisskhService.getDramaEpisodes: $e');
      return [];
    }
  }

  /// Resolve a URL de streaming (HLS .m3u8), a URL direta do vídeo (.ts) e as legendas para um episódio.
  static Future<KisskhStreamSource?> resolveStream(int episodeId) async {
    try {
      final videoKey = generateKey(episodeId, _videoGuid);
      final epUri = Uri.parse('$_baseUrl/DramaList/Episode/$episodeId.png?err=false&kkey=$videoKey');
      final epResp = await http.get(epUri, headers: _headers).timeout(const Duration(seconds: 8));

      if (epResp.statusCode != 200) return null;
      final epData = jsonDecode(epResp.body) as Map<String, dynamic>;
      final m3u8Url = (epData['Video'] as String?) ?? (epData['ThirdParty'] as String?);

      if (m3u8Url == null || m3u8Url.isEmpty) return null;

      // Buscar legendas em paralelo
      final subKey = generateKey(episodeId, _subGuid);
      final subUri = Uri.parse('$_baseUrl/Sub/$episodeId?kkey=$subKey');
      List<KisskhSubtitle> subtitles = [];

      try {
        final subResp = await http.get(subUri, headers: _headers).timeout(const Duration(seconds: 6));
        if (subResp.statusCode == 200) {
          final subData = jsonDecode(subResp.body);
          if (subData is List) {
            subtitles = subData
                .map((s) => KisskhSubtitle.fromJson(s as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (_) {}

      // Tentar resolver a URL do arquivo direto de transporte (.ts contínuo) a partir do manifesto .m3u8
      String? directTsUrl;
      try {
        final m3u8Resp = await http.get(Uri.parse(m3u8Url), headers: _headers).timeout(const Duration(seconds: 6));
        if (m3u8Resp.statusCode == 200) {
          final m3u8Uri = Uri.parse(m3u8Url);
          final lines = m3u8Resp.body.split('\n');
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
              if (trimmed.contains('.ts') || trimmed.endsWith('.ts')) {
                directTsUrl = m3u8Uri.resolve(trimmed).toString();
                break;
              }
            }
          }
        }
      } catch (_) {}

      return KisskhStreamSource(
        m3u8Url: m3u8Url,
        directTsUrl: directTsUrl,
        subtitles: subtitles,
      );
    } catch (e) {
      developer.log('Erro KisskhService.resolveStream: $e');
      return null;
    }
  }

  /// Retorna os resultados do KissKH formatados como TorrentItem para integração harmoniosa
  /// com o catálogo de opções do aplicativo (com badge CDN de alta velocidade).
  static Future<List<TorrentItem>> searchTorrents({
    required String title,
    String? originalTitle,
    String? englishTitle,
    int? season,
    int? episode,
  }) async {
    final List<TorrentItem> results = [];

    // Priorizar buscas: EnglishTitle > Title > OriginalTitle
    final searchQueries = <String>{};
    if (englishTitle != null && englishTitle.trim().isNotEmpty) {
      searchQueries.add(englishTitle.trim());
    }
    if (title.trim().isNotEmpty) {
      searchQueries.add(title.trim());
    }
    if (originalTitle != null && originalTitle.trim().isNotEmpty) {
      searchQueries.add(originalTitle.trim());
    }

    KisskhDrama? matchedDrama;
    for (final q in searchQueries) {
      final dramas = await searchDrama(q);
      if (dramas.isNotEmpty) {
        // Encontrar a correspondência mais próxima
        final cleanQ = q.toLowerCase();
        matchedDrama = dramas.firstWhere(
          (d) => d.title.toLowerCase().contains(cleanQ) || cleanQ.contains(d.title.toLowerCase()),
          orElse: () => dramas.first,
        );
        break;
      }
    }

    if (matchedDrama == null) return [];

    final episodes = await getDramaEpisodes(matchedDrama.id);
    if (episodes.isEmpty) return [];

    List<KisskhEpisode> targetEpisodes = [];
    if (episode != null) {
      targetEpisodes = episodes.where((e) => e.number == episode).toList();
    }
    if (targetEpisodes.isEmpty) {
      targetEpisodes = episodes;
    }

    for (final ep in targetEpisodes) {
      results.add(
        TorrentItem(
          title: '${matchedDrama.title} - T${season ?? 1}:E${ep.number} [1080p CDN Direto]',
          rawLabel: 'KissKH CDN (Ultra Rápido • Direto)',
          magnetUrl: 'kisskh://${matchedDrama.id}/${ep.id}/${ep.number}',
          infoHash: 'KISSKH_${matchedDrama.id}_${ep.id}',
          quality: '1080p',
          size: '~400 MB',
          isDubbed: false,
          isSubbed: true,
          format: 'MPEG-TS / HLS',
          seasonNumber: season ?? 1,
          episodeNumber: ep.number,
          source: 'KissKH (CDN)',
          seeders: 999, // Indica disponibilidade de CDN em alta velocidade
          leechers: 0,
          pageUrl: 'https://kisskh.co/Drama/${matchedDrama.id}',
        ),
      );
    }

    return results;
  }
}
