import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/media_item.dart';
import '../models/media_details.dart';
import '../models/torrent_item.dart';
import '../providers/downloads_provider.dart';
import '../providers/watch_later_provider.dart';
import '../services/tmdb_service.dart';
import '../services/kisskh_service.dart';
import '../services/comando_torrents_service.dart';
import '../services/pirate_bay_service.dart';
import '../widgets/torrent_resolver_sheet.dart';
import 'watch_later_view.dart';

class DetailsView extends StatefulWidget {
  final MediaItem item;

  const DetailsView({super.key, required this.item});

  @override
  State<DetailsView> createState() => _DetailsViewState();
}

class _DetailsViewState extends State<DetailsView> {
  final TmdbService _tmdbService = TmdbService();

  bool _isLoading = true;
  MediaDetails? _details;
  int _selectedSeason = 1;
  List<EpisodeItem> _episodes = [];
  bool _isLoadingEpisodes = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      if (widget.item.type == MediaTypeEnum.movie) {
        final d = await _tmdbService.getMovieDetails(widget.item.id);
        setState(() {
          _details = d;
          _isLoading = false;
        });
      } else {
        // TV ou Dorama
        final isDorama = widget.item.type == MediaTypeEnum.dorama;
        final d = await _tmdbService.getTvDetails(widget.item.id, isDorama: isDorama);
        setState(() {
          _details = d;
          _isLoading = false;
        });
        if (d.seasons.isNotEmpty) {
          _selectedSeason = d.seasons.first.seasonNumber;
          _loadEpisodes(_selectedSeason);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEpisodes(int seasonNumber) async {
    setState(() => _isLoadingEpisodes = true);
    try {
      final eps = await _tmdbService.getSeasonEpisodes(widget.item.id, seasonNumber);
      setState(() {
        _episodes = eps;
        _isLoadingEpisodes = false;
      });
    } catch (_) {
      setState(() => _isLoadingEpisodes = false);
    }
  }

  void _showTorrentModal({int? episodeNumber}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TorrentResolverSheet(
        item: widget.item,
        seasonNumber: widget.item.type == MediaTypeEnum.movie ? null : _selectedSeason,
        episodeNumber: episodeNumber,
        englishTitle: _details?.englishTitle ?? widget.item.englishTitle,
      ),
    );
  }

  void _openBatchDownloadModal() {
    if (_episodes.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BatchEpisodeDownloadSheet(
        item: widget.item,
        seasonNumber: _selectedSeason,
        episodes: _episodes,
        englishTitle: _details?.englishTitle ?? widget.item.englishTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _details == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final media = _details?.item ?? widget.item;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final watchLater = context.watch<WatchLaterProvider>();
    final isSaved = watchLater.isSaved(media.id);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // AppBar Dinâmica com Imagem de Fundo (Backdrop)
          SliverAppBar(
            expandedHeight: isDesktop ? 400 : 280,
            pinned: true,
            backgroundColor: AppTheme.surface,
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  tooltip: isSaved ? 'Remover de Assistir Mais Tarde' : 'Salvar em Assistir Mais Tarde',
                  icon: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: Icon(
                      isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                      color: isSaved ? AppTheme.primary : Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () => _toggleWatchLater(context, media),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (media.backdropUrl != null && media.backdropUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: media.backdropUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorWidget: (_, __, ___) => Container(color: AppTheme.card),
                    )
                  else
                    Container(color: AppTheme.card),
                  // Gradiente escuro
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          AppTheme.background.withOpacity(0.7),
                          AppTheme.background,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Informações do Item
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha com Badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          media.type.label.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (media.rating > 0) ...[
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
                        const SizedBox(width: 10),
                      ],
                      if (media.releaseDate != null && media.releaseDate!.isNotEmpty)
                        Text(
                          media.releaseDate!.split('-').first,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      if (_details?.runtimeMinutes != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• ${_details!.runtimeMinutes} min',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Título Principal (PT-BR)
                  Text(
                    media.title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: isDesktop ? 32 : 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),

                  // Título Original (Importante para o rastreador torrent)
                  if (media.originalTitle.isNotEmpty && media.originalTitle != media.title) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Título Original: ${media.originalTitle}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  // Gêneros
                  if (_details?.genres.isNotEmpty ?? false) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _details!.genres.map((g) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(
                            g,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Ações Principais: Busca de Torrents e Assistir Mais Tarde
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: isDesktop ? 280 : double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showTorrentModal(),
                          icon: const Icon(Icons.download_rounded, size: 22),
                          label: Text(
                            media.type == MediaTypeEnum.movie
                                ? 'Buscar Torrent Dublado'
                                : 'Opções de Download / Torrent',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 4,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: isDesktop ? 220 : double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleWatchLater(context, media),
                          icon: Icon(
                            isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                            size: 20,
                            color: isSaved ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                          label: Text(isSaved ? 'Salvo na Lista' : 'Assistir Mais Tarde'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isSaved ? AppTheme.primary : AppTheme.textPrimary,
                            backgroundColor: isSaved
                                ? AppTheme.primary.withOpacity(0.12)
                                : AppTheme.card.withOpacity(0.6),
                            side: BorderSide(
                              color: isSaved ? AppTheme.primary : AppTheme.border,
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Sinopse
                  const Text(
                    'Sinopse',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    media.overview,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  // Elenco / Personagens
                  if (_details?.cast.isNotEmpty ?? false) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Elenco Principal',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _details!.cast.map((c) {
                        return Chip(
                          backgroundColor: AppTheme.card,
                          side: const BorderSide(color: AppTheme.border),
                          avatar: const Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                          label: Text(c, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                        );
                      }).toList(),
                    ),
                  ],

                  // Seção de Temporadas e Episódios (Para Séries e Doramas)
                  if ((_details?.seasons.isNotEmpty ?? false) || _episodes.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Episódios',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_episodes.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: _openBatchDownloadModal,
                                icon: const Icon(Icons.download_for_offline_rounded, size: 16),
                                label: const Text(
                                  'Baixar Vários',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.surface,
                                  foregroundColor: AppTheme.primary,
                                  side: const BorderSide(color: AppTheme.primary),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Dropdown de Temporada se houver temporadas cadastradas
                        if (_details?.seasons.isNotEmpty ?? false)
                          DropdownButton<int>(
                            value: _selectedSeason,
                            dropdownColor: AppTheme.card,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                            underline: const SizedBox(),
                            items: _details!.seasons.map((s) {
                              return DropdownMenuItem<int>(
                                value: s.seasonNumber,
                                child: Text(s.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedSeason = val);
                                _loadEpisodes(val);
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_isLoadingEpisodes)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: AppTheme.primary),
                        ),
                      )
                    else if (_episodes.isEmpty)
                      const Text(
                        'Nenhum episódio encontrado para esta temporada.',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _episodes.length,
                        separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 24),
                        itemBuilder: (ctx, idx) {
                          final ep = _episodes[idx];
                          return InkWell(
                            onTap: () => _showTorrentModal(episodeNumber: ep.episodeNumber),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Imagem do episódio
                                  Container(
                                    width: 110,
                                    height: 65,
                                    decoration: BoxDecoration(
                                      color: AppTheme.card,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: ep.stillUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: ep.stillUrl!,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => const Icon(
                                                Icons.play_circle_outline,
                                                color: AppTheme.textMuted,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.play_circle_outline,
                                              color: AppTheme.textMuted,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Detalhes do episódio
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${ep.episodeNumber}. ${ep.title}',
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (ep.overview != null && ep.overview!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            ep.overview!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.download_rounded, color: AppTheme.primary),
                                    tooltip: 'Baixar Episódio',
                                    onPressed: () => _showTorrentModal(episodeNumber: ep.episodeNumber),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleWatchLater(BuildContext context, MediaItem media) async {
    final watchLater = context.read<WatchLaterProvider>();
    final added = await watchLater.toggleWatchLater(media);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? '"${media.title}" adicionado a Assistir Mais Tarde.'
              : '"${media.title}" removido de Assistir Mais Tarde.',
        ),
        backgroundColor: AppTheme.card,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: added
            ? SnackBarAction(
                label: 'Ver Lista',
                textColor: AppTheme.primary,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WatchLaterView()),
                  );
                },
              )
            : SnackBarAction(
                label: 'Desfazer',
                textColor: AppTheme.primary,
                onPressed: () {
                  watchLater.addToWatchLater(media);
                },
              ),
      ),
    );
  }
}

class _BatchEpisodeDownloadSheet extends StatefulWidget {
  final MediaItem item;
  final int seasonNumber;
  final List<EpisodeItem> episodes;
  final String? englishTitle;

  const _BatchEpisodeDownloadSheet({
    required this.item,
    required this.seasonNumber,
    required this.episodes,
    this.englishTitle,
  });

  @override
  State<_BatchEpisodeDownloadSheet> createState() => _BatchEpisodeDownloadSheetState();
}

class _BatchEpisodeDownloadSheetState extends State<_BatchEpisodeDownloadSheet> {
  late final Set<int> _selectedEpisodeNumbers;
  bool _isResolving = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _selectedEpisodeNumbers = widget.episodes.map((e) => e.episodeNumber).toSet();
  }

  void _startBatchDownload() async {
    if (_selectedEpisodeNumbers.isEmpty) return;

    setState(() {
      _isResolving = true;
      _statusMessage = 'Obtendo fontes para ${_selectedEpisodeNumbers.length} episódios...';
    });

    final downloads = context.read<DownloadsProvider>();
    final List<TorrentItem> torrentsToDownload = [];

    try {
      if (widget.item.type == MediaTypeEnum.dorama) {
        // KissKH CDN
        final allKisskh = await KisskhService.searchTorrents(
          title: widget.item.title,
          originalTitle: widget.item.originalTitle,
          englishTitle: widget.englishTitle,
          season: widget.seasonNumber,
        );

        for (final epNum in _selectedEpisodeNumbers) {
          final match = allKisskh.firstWhere(
            (t) => t.episodeNumber == epNum,
            orElse: () => TorrentItem(
              title: '',
              rawLabel: '',
              magnetUrl: '',
              infoHash: '',
              quality: '1080p',
              size: '',
              isDubbed: false,
              isSubbed: true,
              format: 'MPEG-TS',
              source: 'KissKH (CDN)',
            ),
          );
          if (match.magnetUrl.isNotEmpty) {
            torrentsToDownload.add(match);
          }
        }
      } else {
        // Séries: Comando Torrents e The Pirate Bay
        for (final epNum in _selectedEpisodeNumbers) {
          setState(() {
            _statusMessage = 'Buscando episódio $epNum de ${_selectedEpisodeNumbers.length}...';
          });
          final results = await Future.wait([
            ComandoTorrentsService.searchTorrents(
              title: widget.item.title,
              originalTitle: widget.item.originalTitle,
              season: widget.seasonNumber,
              episode: epNum,
            ).catchError((_) => <TorrentItem>[]),
            PirateBayService.searchTorrents(
              title: widget.item.title,
              originalTitle: widget.item.originalTitle,
              englishTitle: widget.englishTitle,
              season: widget.seasonNumber,
              episode: epNum,
            ).catchError((_) => <TorrentItem>[]),
          ]);
          final epTorrents = [...results[0], ...results[1]];
          if (epTorrents.isNotEmpty) {
            epTorrents.sort((a, b) => (b.seeders ?? 0).compareTo(a.seeders ?? 0));
            torrentsToDownload.add(epTorrents.first);
          }
        }
      }

      if (!mounted) return;

      if (torrentsToDownload.isEmpty) {
        setState(() {
          _isResolving = false;
          _statusMessage = 'Nenhuma fonte encontrada para os episódios selecionados.';
        });
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.download_done_rounded, color: AppTheme.badgeGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Download de ${torrentsToDownload.length} episódios iniciado simultaneamente! Acompanhe na aba Downloads.'),
              ),
            ],
          ),
          backgroundColor: AppTheme.cardHover,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );

      await downloads.addMultipleDownloads(
        torrents: torrentsToDownload,
        media: widget.item,
        seasonNumber: widget.seasonNumber,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResolving = false;
          _statusMessage = 'Erro: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Baixar Episódios em Lote',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.item.title} • ${widget.seasonNumber}ª Temporada',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.border, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Text(
                  '${_selectedEpisodeNumbers.length} de ${widget.episodes.length} selecionados',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isResolving
                      ? null
                      : () {
                          setState(() {
                            if (_selectedEpisodeNumbers.length == widget.episodes.length) {
                              _selectedEpisodeNumbers.clear();
                            } else {
                              _selectedEpisodeNumbers.addAll(widget.episodes.map((e) => e.episodeNumber));
                            }
                          });
                        },
                  child: Text(
                    _selectedEpisodeNumbers.length == widget.episodes.length
                        ? 'Desmarcar Todos'
                        : 'Selecionar Todos',
                    style: const TextStyle(color: AppTheme.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          if (_statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  if (_isResolving) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              itemCount: widget.episodes.length,
              separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
              itemBuilder: (ctx, idx) {
                final ep = widget.episodes[idx];
                final isSelected = _selectedEpisodeNumbers.contains(ep.episodeNumber);
                return CheckboxListTile(
                  value: isSelected,
                  activeColor: AppTheme.primary,
                  checkColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                  enabled: !_isResolving,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedEpisodeNumbers.add(ep.episodeNumber);
                      } else {
                        _selectedEpisodeNumbers.remove(ep.episodeNumber);
                      }
                    });
                  },
                  title: Text(
                    'Episódio ${ep.episodeNumber}: ${ep.title}',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: (ep.overview != null && ep.overview!.isNotEmpty)
                      ? Text(
                          ep.overview!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        )
                      : null,
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_selectedEpisodeNumbers.isNotEmpty && !_isResolving)
                      ? _startBatchDownload
                      : null,
                  icon: _isResolving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, size: 20),
                  label: Text(
                    _isResolving
                        ? 'Iniciando Downloads...'
                        : 'Baixar ${_selectedEpisodeNumbers.length} Episódios Selecionados',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
