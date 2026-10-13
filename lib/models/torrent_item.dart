/// Representa um resultado de torrent extraído de um indexador/tracker.
class TorrentItem {
  final String title;
  final String rawLabel;
  final String magnetUrl;
  final String infoHash;
  final String quality;
  final String? size;
  final bool isDubbed;
  final bool isSubbed;
  final String? format;
  final int? seasonNumber;
  final int? episodeNumber;
  final String source;
  final String? pageUrl;
  final int? seeders;
  final int? leechers;

  const TorrentItem({
    required this.title,
    required this.rawLabel,
    required this.magnetUrl,
    required this.infoHash,
    required this.quality,
    this.size,
    required this.isDubbed,
    required this.isSubbed,
    this.format,
    this.seasonNumber,
    this.episodeNumber,
    required this.source,
    this.pageUrl,
    this.seeders,
    this.leechers,
  });

  /// Extrai o hash BTIH a partir do link magnético.
  static String extractInfoHash(String magnetUrl) {
    final match = RegExp(r'urn:btih:([a-zA-Z0-9]+)', caseSensitive: false).firstMatch(magnetUrl);
    return match != null ? match.group(1)!.toUpperCase() : '';
  }

  /// Converte string de tamanho (ex: "3.78 GB", "500 MB") para bytes inteiros.
  static int parseSizeToBytes(String? sizeStr) {
    if (sizeStr == null || sizeStr.isEmpty) return 0;
    final match = RegExp(r'([\d\.,]+)\s*(GB|MB|KB|B)', caseSensitive: false).firstMatch(sizeStr);
    if (match == null) return 0;
    final numStr = match.group(1)!.replaceAll(',', '.');
    final val = double.tryParse(numStr);
    if (val == null) return 0;
    final unit = match.group(2)!.toUpperCase();
    if (unit == 'GB') {
      return (val * 1024 * 1024 * 1024).round();
    } else if (unit == 'MB') {
      return (val * 1024 * 1024).round();
    } else if (unit == 'KB') {
      return (val * 1024).round();
    }
    return val.round();
  }

  /// Retorna o nome amigável do áudio
  String get audioLabel {
    if (isDubbed && isSubbed) return 'Dual Áudio (Dub/Leg)';
    if (isDubbed) return 'Dublado (PT-BR)';
    if (isSubbed) return 'Legendado';
    return 'Áudio Original';
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'rawLabel': rawLabel,
      'magnetUrl': magnetUrl,
      'infoHash': infoHash,
      'quality': quality,
      'size': size,
      'isDubbed': isDubbed,
      'isSubbed': isSubbed,
      'format': format,
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'source': source,
      'pageUrl': pageUrl,
    };
  }

  factory TorrentItem.fromJson(Map<String, dynamic> json) {
    return TorrentItem(
      title: json['title'] as String,
      rawLabel: json['rawLabel'] as String,
      magnetUrl: json['magnetUrl'] as String,
      infoHash: json['infoHash'] as String,
      quality: json['quality'] as String,
      size: json['size'] as String?,
      isDubbed: json['isDubbed'] as bool? ?? false,
      isSubbed: json['isSubbed'] as bool? ?? false,
      format: json['format'] as String?,
      seasonNumber: json['seasonNumber'] as int?,
      episodeNumber: json['episodeNumber'] as int?,
      source: json['source'] as String,
      pageUrl: json['pageUrl'] as String?,
    );
  }
}
