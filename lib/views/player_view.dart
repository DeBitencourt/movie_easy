import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/download_item.dart';
import '../providers/downloads_provider.dart';
import '../services/kisskh_service.dart';
import '../services/subtitle_translation_service.dart';

enum PlayerScreenStatus {
  initializing,
  playing,
  error,
}

class SubtitleTrackInfo {
  final String title;
  final String language;
  final String url;

  const SubtitleTrackInfo({
    required this.title,
    required this.language,
    required this.url,
  });
}

/// Player de vídeo moderno e imersivo com suporte a aceleração por hardware (libmpv),
/// reprodução direta de arquivos locais (.mkv, .mp4, etc.) e streaming sequencial P2P via libtorrent.
class PlayerView extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? posterUrl;
  final String? backdropUrl;
  final String? videoUrl; // URL direto ou path local opcional
  final DownloadItem? downloadItem;
  final int? torrentId;
  final List<SubtitleTrackInfo>? externalSubtitles;

  const PlayerView({
    super.key,
    required this.title,
    this.subtitle,
    this.posterUrl,
    this.backdropUrl,
    this.videoUrl,
    this.downloadItem,
    this.torrentId,
    this.externalSubtitles,
  });

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  late final Player _player;
  late final VideoController _controller;

  PlayerScreenStatus _status = PlayerScreenStatus.initializing;
  String _statusMessage = 'Preparando reprodução...';
  String? _errorMessage;
  BoxFit _videoFit = BoxFit.contain;
  List<SubtitleTrackInfo> _activeExternalSubs = [];

  Timer? _pollingTimer;
  StreamSubscription? _bufferingSub;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() {
          _isBuffering = buffering;
        });
      }
    });

    _startPlaybackFlow();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _bufferingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startPlaybackFlow() async {
    // Caso 1: Foi fornecida uma URL direta ou caminho de arquivo local
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      await _openMedia(widget.videoUrl!);
      return;
    }

    // Caso 2: Veio de um DownloadItem / Torrent
    if (widget.downloadItem != null) {
      final provider = context.read<DownloadsProvider>();
      final item = widget.downloadItem!;

      // Se o torrent ainda não tem metadados carregados
      if (!item.hasMetadata) {
        setState(() {
          _status = PlayerScreenStatus.initializing;
          _statusMessage = 'Conectando ao enxame P2P e obtendo metadados...';
        });

        // Aguardar periodicamente até que os metadados estejam disponíveis
        int attempts = 0;
        _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
          attempts++;
          final freshList = provider.allDownloads;
          final freshItem = freshList.firstWhere(
            (d) => d.id == item.id,
            orElse: () => item,
          );

          if (mounted) {
            setState(() {
              final count = freshItem.numSeeds + freshItem.numPeers;
              _statusMessage = count > 0
                  ? 'Obtendo metadados ($count pares conectados)...'
                  : 'Buscando pares na rede DHT ($attempts s)...';
            });
          }

          if (freshItem.hasMetadata) {
            timer.cancel();
            _resolveAndPlay(freshItem);
          } else if (attempts > 90) {
            timer.cancel();
            if (mounted) {
              setState(() {
                _status = PlayerScreenStatus.error;
                _errorMessage =
                    'Tempo limite ao aguardar metadados do torrent. Verifique sua conexão com a internet.';
              });
            }
          }
        });
        return;
      }

      await _resolveAndPlay(item);
      return;
    }

    // Se nenhum parâmetro foi passado
    setState(() {
      _status = PlayerScreenStatus.error;
      _errorMessage = 'Nenhuma fonte de vídeo informada para reprodução.';
    });
  }

  Future<void> _resolveAndPlay(DownloadItem item) async {
    setState(() {
      _status = PlayerScreenStatus.initializing;
      _statusMessage = 'Iniciando buffer sequencial de streaming...';
    });

    try {
      final provider = context.read<DownloadsProvider>();
      final source = await provider.resolvePlaybackSource(item);

      if (source == null || source.isEmpty) {
        setState(() {
          _status = PlayerScreenStatus.error;
          _errorMessage = 'Não foi possível iniciar o servidor de streaming do torrent.';
        });
        return;
      }

      final List<SubtitleTrackInfo> resolvedSubs = widget.externalSubtitles != null
          ? List.from(widget.externalSubtitles!)
          : [];

      // Verificar se há legendas salvas localmente
      final safeName = item.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final ptSub = File('${item.savePath}${Platform.pathSeparator}$safeName.pt-BR.srt');
      final mainSub = File('${item.savePath}${Platform.pathSeparator}$safeName.srt');
      final enSub = File('${item.savePath}${Platform.pathSeparator}$safeName.en.srt');

      if (ptSub.existsSync()) {
        resolvedSubs.add(
          SubtitleTrackInfo(
            title: 'Português (Brasil)',
            language: 'pt-BR',
            url: ptSub.path,
          ),
        );
      } else if (mainSub.existsSync()) {
        resolvedSubs.add(
          SubtitleTrackInfo(
            title: 'Português (Brasil)',
            language: 'pt-BR',
            url: mainSub.path,
          ),
        );
      }

      if (enSub.existsSync()) {
        resolvedSubs.add(
          SubtitleTrackInfo(
            title: 'Inglês (Original)',
            language: 'en',
            url: enSub.path,
          ),
        );
      }

      if (resolvedSubs.isEmpty && (item.id < 0 || item.magnetUrl.startsWith('kisskh://'))) {
        // Se for KissKH, buscar faixas de legenda da CDN se não foram passadas
        final epId = KisskhService.extractEpisodeId(item.magnetUrl, item.infoHash);
        if (epId != null) {
          final stream = await KisskhService.resolveStream(epId);
          if (stream != null && stream.subtitles.isNotEmpty) {
            resolvedSubs.addAll(
              stream.subtitles.map((s) => SubtitleTrackInfo(
                    title: s.label,
                    language: s.lang,
                    url: s.src,
                  )),
            );
          }
        }
      }

      await _openMedia(source, externalSubtitles: resolvedSubs);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = PlayerScreenStatus.error;
          _errorMessage = 'Falha ao iniciar streaming: $e';
        });
      }
    }
  }

  Future<void> _openMedia(String source, {List<SubtitleTrackInfo>? externalSubtitles}) async {
    try {
      setState(() {
        _status = PlayerScreenStatus.initializing;
        _statusMessage = 'Carregando decodificadores de vídeo...';
      });

      if (externalSubtitles != null && externalSubtitles.isNotEmpty) {
        _activeExternalSubs = List.from(externalSubtitles);
      } else if (widget.externalSubtitles != null && widget.externalSubtitles!.isNotEmpty) {
        _activeExternalSubs = List.from(widget.externalSubtitles!);
      }

      // Abre a mídia (seja URL http://... ou caminho C:\... no disco)
      await _player.open(
        Media(
          source,
          httpHeaders: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://kisskh.co/',
          },
        ),
      );

      // Ativar legenda externa preferencial (Português > Inglês > primeira disponível)
      if (_activeExternalSubs.isNotEmpty) {
        final hasPt = _activeExternalSubs.any((s) => s.language.toLowerCase().startsWith('pt'));
        if (!hasPt) {
          final enSub = _activeExternalSubs.firstWhere(
            (s) => s.language.toLowerCase().startsWith('en'),
            orElse: () => _activeExternalSubs.first,
          );
          SubtitleTranslationService.getOrTranslateSrtFromUrl(
            enSub.url,
            cacheKey: '${widget.title}_${widget.subtitle ?? ""}',
          ).then((cachedPtFile) {
            if (cachedPtFile != null && mounted) {
              final ptTrack = SubtitleTrackInfo(
                title: 'Português (Brasil)',
                language: 'pt-BR',
                url: cachedPtFile.path,
              );
              _activeExternalSubs.insert(0, ptTrack);
              _player.setSubtitleTrack(
                SubtitleTrack.uri(cachedPtFile.path, title: 'Português (Brasil)', language: 'pt-BR'),
              );
            }
          });
        }

        final prefSub = _activeExternalSubs.firstWhere(
          (s) => s.language.toLowerCase().startsWith('pt') || s.title.toLowerCase().contains('portugu'),
          orElse: () => _activeExternalSubs.firstWhere(
            (s) => s.language.toLowerCase().startsWith('en') || s.title.toLowerCase().contains('eng'),
            orElse: () => _activeExternalSubs.first,
          ),
        );
        Future.delayed(const Duration(milliseconds: 600), () async {
          try {
            await _player.setSubtitleTrack(
              SubtitleTrack.uri(prefSub.url, title: prefSub.title, language: prefSub.language),
            );
          } catch (_) {}
        });
      }

      if (mounted) {
        setState(() {
          _status = PlayerScreenStatus.playing;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = PlayerScreenStatus.error;
          _errorMessage = 'Erro ao abrir vídeo no player: $e';
        });
      }
    }
  }

  void _toggleFit() {
    setState(() {
      _videoFit = _videoFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
    });
  }

  void _showTracksSheet() {
    final audioTracks = _player.state.tracks.audio;
    final currentAudio = _player.state.track.audio;
    final subTracks = _player.state.tracks.subtitle;
    final currentSub = _player.state.track.subtitle;

    final List<SubtitleTrack> uniqueSubTracks = [];
    final Set<String> seenNames = {};

    for (final track in subTracks) {
      if (track.id == 'no') continue;
      final formattedName = _formatSubtitleTrackName(track);
      if (!seenNames.contains(formattedName)) {
        seenNames.add(formattedName);
        uniqueSubTracks.add(track);
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return DefaultTabController(
              length: 2,
              child: SafeArea(
                child: SizedBox(
                  height: 420,
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const TabBar(
                        indicatorColor: AppTheme.primary,
                        labelColor: AppTheme.textPrimary,
                        unselectedLabelColor: AppTheme.textMuted,
                        indicatorWeight: 3,
                        tabs: [
                          Tab(icon: Icon(Icons.audiotrack_rounded), text: 'Áudio'),
                          Tab(icon: Icon(Icons.subtitles_rounded), text: 'Legendas'),
                        ],
                      ),
                      const Divider(color: AppTheme.border, height: 1),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Faixas de Áudio
                            ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              children: [
                                if (audioTracks.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(32),
                                      child: Text(
                                        'Nenhuma faixa de áudio detectada',
                                        style: TextStyle(color: AppTheme.textMuted),
                                      ),
                                    ),
                                  ),
                                for (final track in audioTracks)
                                  ListTile(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    selected: track == currentAudio,
                                    selectedTileColor: AppTheme.primary.withOpacity(0.12),
                                    leading: Icon(
                                      track == currentAudio
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      color: track == currentAudio ? AppTheme.primary : AppTheme.textMuted,
                                    ),
                                    title: Text(
                                      _formatAudioTrackName(track),
                                      style: TextStyle(
                                        color: track == currentAudio ? AppTheme.primary : AppTheme.textPrimary,
                                        fontWeight: track == currentAudio ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: track.codec != null
                                        ? Text(
                                            'Codec: ${track.codec!.toUpperCase()}${track.channels != null ? ' • ${track.channels}' : ''}',
                                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                          )
                                        : null,
                                    onTap: () {
                                      _player.setAudioTrack(track);
                                      Navigator.pop(ctx);
                                    },
                                  ),
                              ],
                            ),

                            // Faixas de Legenda
                            ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              children: [
                                ListTile(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  selected: currentSub.id == 'no',
                                  selectedTileColor: AppTheme.primary.withOpacity(0.12),
                                  leading: Icon(
                                    currentSub.id == 'no'
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: currentSub.id == 'no' ? AppTheme.primary : AppTheme.textMuted,
                                  ),
                                  title: const Text('Desativada', style: TextStyle(color: AppTheme.textPrimary)),
                                  onTap: () {
                                    _player.setSubtitleTrack(SubtitleTrack.no());
                                    Navigator.pop(ctx);
                                  },
                                ),
                                for (final track in uniqueSubTracks)
                                  ListTile(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    selected: currentSub.id == track.id ||
                                        _formatSubtitleTrackName(currentSub) == _formatSubtitleTrackName(track),
                                    selectedTileColor: AppTheme.primary.withOpacity(0.12),
                                    leading: Icon(
                                      (currentSub.id == track.id ||
                                              _formatSubtitleTrackName(currentSub) == _formatSubtitleTrackName(track))
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      color: (currentSub.id == track.id ||
                                              _formatSubtitleTrackName(currentSub) == _formatSubtitleTrackName(track))
                                          ? AppTheme.primary
                                          : AppTheme.textMuted,
                                    ),
                                    title: Text(
                                      _formatSubtitleTrackName(track),
                                      style: TextStyle(
                                        color: (currentSub.id == track.id ||
                                                _formatSubtitleTrackName(currentSub) == _formatSubtitleTrackName(track))
                                            ? AppTheme.primary
                                            : AppTheme.textPrimary,
                                        fontWeight: (currentSub.id == track.id ||
                                                _formatSubtitleTrackName(currentSub) == _formatSubtitleTrackName(track))
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    onTap: () {
                                      _player.setSubtitleTrack(track);
                                      Navigator.pop(ctx);
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSpeedDialog() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentRate = _player.state.rate;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Velocidade de Reprodução',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((s) {
            final isSelected = (currentRate - s).abs() < 0.05;
            return ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              selected: isSelected,
              selectedTileColor: AppTheme.primary.withOpacity(0.12),
              leading: Icon(
                isSelected ? Icons.check_rounded : Icons.speed_rounded,
                color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                size: 20,
              ),
              title: Text(
                '${s}x${s == 1.0 ? ' (Normal)' : ''}',
                style: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onTap: () {
                _player.setRate(s);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatAudioTrackName(AudioTrack track) {
    if (track.title != null && track.title!.trim().isNotEmpty) {
      return track.title!;
    }
    if (track.language != null && track.language!.trim().isNotEmpty) {
      return _translateLanguage(track.language!);
    }
    return 'Áudio (${track.id})';
  }

  String _formatSubtitleTrackName(SubtitleTrack track) {
    if (track.id == 'no') return 'Desativada';
    if (track.id == 'auto') return 'Seleção Automática';

    final title = track.title ?? '';
    final lowerTitle = title.toLowerCase();

    if (lowerTitle.contains('pt-br') || lowerTitle.contains('portugu')) {
      return 'Português (Brasil)';
    }
    if (lowerTitle.contains('.en.srt') || lowerTitle.contains('inglês') || lowerTitle.contains('english')) {
      return 'Inglês (Original)';
    }
    if (lowerTitle.endsWith('.srt') || lowerTitle.endsWith('.vtt')) {
      if (lowerTitle.contains('kisskh') || lowerTitle.contains('hong')) {
        return 'Português (Brasil • Baixada)';
      }
      return title.split(Platform.pathSeparator).last;
    }

    if (track.language != null && track.language!.trim().isNotEmpty) {
      final lang = _translateLanguage(track.language!);
      return title.isNotEmpty ? '$title ($lang)' : lang;
    }

    if (title.isNotEmpty) return title;
    return 'Faixa de Legenda ${track.id}';
  }

  String _translateLanguage(String code) {
    final lower = code.toLowerCase();
    if (lower.startsWith('por') || lower.startsWith('pt')) return 'Português';
    if (lower.startsWith('eng') || lower.startsWith('en')) return 'Inglês';
    if (lower.startsWith('spa') || lower.startsWith('es')) return 'Espanhol';
    if (lower.startsWith('jpn') || lower.startsWith('ja')) return 'Japonês';
    if (lower.startsWith('fra') || lower.startsWith('fr')) return 'Francês';
    if (lower.startsWith('ita') || lower.startsWith('it')) return 'Italiano';
    if (lower.startsWith('ger') || lower.startsWith('de')) return 'Alemão';
    return code.toUpperCase();
  }

  Widget _buildP2PBadge() {
    if (widget.downloadItem == null) return const SizedBox.shrink();

    return Consumer<DownloadsProvider>(
      builder: (_, provider, __) {
        final current = provider.allDownloads.firstWhere(
          (d) => d.id == widget.downloadItem!.id,
          orElse: () => widget.downloadItem!,
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: current.downloadRate > 0 ? AppTheme.badgeGreen : Colors.amberAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${current.numSeeds} seeds • ${current.formattedSpeed}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_status == PlayerScreenStatus.initializing) {
      return _buildLoadingScreen();
    }

    if (_status == PlayerScreenStatus.error) {
      return _buildErrorScreen();
    }

    // Configuração dos controles desktop e mobile do media_kit
    final topBar = [
      MaterialDesktopCustomButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.subtitle!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
      _buildP2PBadge(),
      MaterialDesktopCustomButton(
        icon: Icon(
          _videoFit == BoxFit.contain ? Icons.aspect_ratio_rounded : Icons.fit_screen_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: _toggleFit,
      ),
    ];

    final bottomBar = [
      const MaterialDesktopPlayOrPauseButton(),
      const MaterialDesktopVolumeButton(),
      const MaterialDesktopPositionIndicator(),
      const Spacer(),
      MaterialDesktopCustomButton(
        icon: const Icon(Icons.speed_rounded, color: Colors.white, size: 20),
        onPressed: _showSpeedDialog,
      ),
      MaterialDesktopCustomButton(
        icon: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 20),
        onPressed: _showTracksSheet,
      ),
      const MaterialDesktopFullscreenButton(),
    ];

    // Mobile equivalentes
    final mobileTopBar = [
      MaterialCustomButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      MaterialCustomButton(
        icon: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 20),
        onPressed: _showTracksSheet,
      ),
    ];

    final mobileBottomBar = [
      const MaterialPositionIndicator(),
      const Spacer(),
      MaterialCustomButton(
        icon: const Icon(Icons.speed_rounded, color: Colors.white, size: 20),
        onPressed: _showSpeedDialog,
      ),
      const MaterialFullscreenButton(),
    ];

    final desktopTheme = MaterialDesktopVideoControlsThemeData(
      topButtonBar: topBar,
      bottomButtonBar: bottomBar,
      seekBarPositionColor: AppTheme.primary,
      seekBarThumbColor: AppTheme.primary,
      seekBarBufferColor: AppTheme.primary.withOpacity(0.35),
      volumeBarActiveColor: AppTheme.primary,
      volumeBarThumbColor: AppTheme.primary,
      controlsHoverDuration: const Duration(seconds: 3),
      bufferingIndicatorBuilder: (_) => _buildBufferingWidget(),
    );

    final mobileTheme = MaterialVideoControlsThemeData(
      topButtonBar: mobileTopBar,
      bottomButtonBar: mobileBottomBar,
      seekBarPositionColor: AppTheme.primary,
      seekBarThumbColor: AppTheme.primary,
      seekBarBufferColor: AppTheme.primary.withOpacity(0.35),
      controlsHoverDuration: const Duration(seconds: 3),
      bufferingIndicatorBuilder: (_) => _buildBufferingWidget(),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: MaterialDesktopVideoControlsTheme(
        normal: desktopTheme,
        fullscreen: desktopTheme,
        child: MaterialVideoControlsTheme(
          normal: mobileTheme,
          fullscreen: mobileTheme,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Video(
                controller: _controller,
                controls: AdaptiveVideoControls,
                fit: _videoFit,
                subtitleViewConfiguration: const SubtitleViewConfiguration(
                  style: TextStyle(
                    height: 1.4,
                    fontSize: 22.0,
                    letterSpacing: 0.2,
                    wordSpacing: 0.5,
                    color: Color(0xffffffff),
                    fontWeight: FontWeight.bold,
                    backgroundColor: Color(0xaa000000),
                  ),
                ),
              ),
              if (_isBuffering)
                Center(child: _buildBufferingWidget()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBufferingWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 3.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Carregando Buffer...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.downloadItem != null) ...[
            const SizedBox(height: 4),
            Text(
              '${widget.downloadItem!.numSeeds} seeds • ${widget.downloadItem!.formattedSpeed}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poster ou thumbnail com brilho sutil
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 3.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),

              const SizedBox(height: 28),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textMuted,
                  side: const BorderSide(color: AppTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancelar e Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Falha na Reprodução',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ?? 'Ocorreu um erro inesperado ao carregar o vídeo.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    child: const Text('Voltar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _status = PlayerScreenStatus.initializing;
                        _errorMessage = null;
                      });
                      _startPlaybackFlow();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
