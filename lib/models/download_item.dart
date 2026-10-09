import 'media_item.dart';

/// Representa um download ativo ou concluído gerenciado pelo motor libtorrent.
class DownloadItem {
  int id;
  final String infoHash;
  final String title;
  final String magnetUrl;
  final String savePath;
  final String? posterUrl;
  final String? backdropUrl;
  final String? quality;
  final String? audio;
  final MediaTypeEnum? mediaType;
  final String? mediaId;
  final String? mediaTitle;
  final int? seasonNumber;
  final int? episodeNumber;
  double progress;
  int downloadRate;
  int uploadRate;
  int totalDone;
  int totalWanted;
  int numSeeds;
  int numPeers;
  String stateLabel;
  bool isPaused;
  bool isFinished;
  bool hasMetadata;
  String? streamUrl;
  final DateTime addedAt;

  DownloadItem({
    required this.id,
    required this.infoHash,
    required this.title,
    required this.magnetUrl,
    required this.savePath,
    this.posterUrl,
    this.backdropUrl,
    this.quality,
    this.audio,
    this.mediaType,
    this.mediaId,
    this.mediaTitle,
    this.seasonNumber,
    this.episodeNumber,
    this.progress = 0.0,
    this.downloadRate = 0,
    this.uploadRate = 0,
    this.totalDone = 0,
    this.totalWanted = 0,
    this.numSeeds = 0,
    this.numPeers = 0,
    this.stateLabel = 'Iniciando',
    this.isPaused = false,
    this.isFinished = false,
    this.hasMetadata = false,
    this.streamUrl,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  /// Velocidade de download formatada (ex: "3.5 MB/s")
  String get formattedSpeed {
    if (isPaused || isFinished || downloadRate <= 0) return '0 KB/s';
    if (downloadRate >= 1024 * 1024) {
      return '${(downloadRate / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(downloadRate / 1024).toStringAsFixed(0)} KB/s';
  }

  /// Progresso percentual formatado (ex: "45.8%")
  String get formattedProgress {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  /// Tamanho transferido vs tamanho total
  String get formattedSize {
    if (!hasMetadata || totalWanted <= 0) {
      if (totalDone > 0) return _formatBytes(totalDone);
      return (numSeeds + numPeers > 0) ? 'Obtendo metadados...' : 'Buscando pares...';
    }
    return '${_formatBytes(totalDone)} / ${_formatBytes(totalWanted)}';
  }

  /// Tempo estimado restante (ETA)
  String get formattedEta {
    if (isFinished) return 'Concluído';
    if (isPaused) return 'Pausado';
    if (downloadRate <= 0 || totalWanted <= 0 || totalDone >= totalWanted) {
      return '--';
    }
    final remainingBytes = totalWanted - totalDone;
    final seconds = remainingBytes ~/ downloadRate;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ${seconds % 60}s';
    final hours = minutes ~/ 60;
    return '${hours}h ${minutes % 60}m';
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  /// Retorna o título da obra/série limpo (sem tags de episódio ou codec).
  String get cleanMediaTitle {
    if (mediaTitle != null && mediaTitle!.trim().isNotEmpty) {
      return mediaTitle!.trim();
    }
    return extractCleanTitle(title);
  }

  /// Remove sufixos como "[1080p - KissKH CDN]", "(T1:E1)", "(1ª Temporada)" do título bruto.
  static String extractCleanTitle(String rawTitle) {
    var clean = rawTitle;
    clean = clean.replaceAll(RegExp(r'\s*\[.*?\]$'), '').trim();
    clean = clean.replaceAll(
      RegExp(r'\s*\((?:T\d+(?::E\d+)?|\d+ª\s*Temporada|Season\s*\d+|S\d+(?:E\d+)?)\)$', caseSensitive: false),
      '',
    ).trim();
    return clean.isNotEmpty ? clean : rawTitle;
  }

  /// Temporada resolvida (ou extraída do título)
  int? get resolvedSeasonNumber {
    if (mediaType == MediaTypeEnum.movie) return null;
    if (seasonNumber != null) return seasonNumber;
    final match = RegExp(r'\(T(\d+)(?::E\d+)?\)', caseSensitive: false).firstMatch(title);
    if (match != null) return int.tryParse(match.group(1)!);
    final matchS = RegExp(r'\bS(\d+)', caseSensitive: false).firstMatch(title);
    if (matchS != null) return int.tryParse(matchS.group(1)!);
    return null;
  }

  /// Episódio resolvido (ou extraído do título)
  int? get resolvedEpisodeNumber {
    if (mediaType == MediaTypeEnum.movie) return null;
    if (episodeNumber != null) return episodeNumber;
    final match = RegExp(r'\(T\d+:E(\d+)\)', caseSensitive: false).firstMatch(title);
    if (match != null) return int.tryParse(match.group(1)!);
    final matchE = RegExp(r'\bE(\d+)\b', caseSensitive: false).firstMatch(title);
    if (matchE != null) return int.tryParse(matchE.group(1)!);
    final matchEp = RegExp(r'Epis[oó]dio\s*(\d+)', caseSensitive: false).firstMatch(title);
    if (matchEp != null) return int.tryParse(matchEp.group(1)!);
    return null;
  }

  /// Rótulo curto de exibição do episódio (ex: "T1 : Ep 1" ou "Episódio 1")
  String get episodeDisplayLabel {
    final s = resolvedSeasonNumber;
    final e = resolvedEpisodeNumber;
    if (s != null && e != null) return 'T$s : Ep $e';
    if (e != null) return 'Episódio $e';
    if (s != null) return 'Temporada $s';
    return title;
  }

  /// Título legível do episódio (ex: "Episódio 1")
  String get episodeCleanName {
    final e = resolvedEpisodeNumber;
    final s = resolvedSeasonNumber;
    if (e != null && s != null) return 'Episódio $e (Temporada $s)';
    if (e != null) return 'Episódio $e';
    return title;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'infoHash': infoHash,
    'title': title,
    'magnetUrl': magnetUrl,
    'savePath': savePath,
    'posterUrl': posterUrl,
    'backdropUrl': backdropUrl,
    'quality': quality,
    'audio': audio,
    'mediaType': mediaType?.name,
    'mediaId': mediaId,
    'mediaTitle': mediaTitle,
    'seasonNumber': seasonNumber,
    'episodeNumber': episodeNumber,
    'progress': progress,
    'totalDone': totalDone,
    'totalWanted': totalWanted,
    'isFinished': isFinished,
    'hasMetadata': hasMetadata,
    'addedAt': addedAt.toIso8601String(),
  };

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    MediaTypeEnum? type;
    if (json['mediaType'] != null) {
      try {
        type = MediaTypeEnum.values.firstWhere(
          (t) => t.name == json['mediaType'],
        );
      } catch (_) {}
    }

    final isMovie = type == MediaTypeEnum.movie;
    final season = isMovie ? null : json['seasonNumber'] as int?;
    final episode = isMovie ? null : json['episodeNumber'] as int?;

    return DownloadItem(
      id: json['id'] as int? ?? -1,
      infoHash: json['infoHash'] as String? ?? '',
      title: json['title'] as String? ?? 'Vídeo',
      magnetUrl: json['magnetUrl'] as String? ?? '',
      savePath: json['savePath'] as String? ?? '',
      posterUrl: json['posterUrl'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      quality: json['quality'] as String?,
      audio: json['audio'] as String?,
      mediaType: type,
      mediaId: json['mediaId'] as String?,
      mediaTitle: json['mediaTitle'] as String?,
      seasonNumber: season,
      episodeNumber: episode,
      progress: (json['progress'] as num?)?.toDouble() ?? (json['isFinished'] == true ? 1.0 : 0.0),
      totalDone: json['totalDone'] as int? ?? 0,
      totalWanted: json['totalWanted'] as int? ?? 0,
      isFinished: json['isFinished'] as bool? ?? false,
      hasMetadata: json['hasMetadata'] as bool? ?? false,
      stateLabel: json['isFinished'] == true ? 'Download Concluído' : 'Pausado',
      addedAt: json['addedAt'] != null ? DateTime.tryParse(json['addedAt']) : null,
    );
  }
}
