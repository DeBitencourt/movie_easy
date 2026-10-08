import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../models/media_item.dart';
import '../models/media_details.dart';
import '../services/tmdb_service.dart';
import '../services/anilist_service.dart';

class DetailsView extends StatefulWidget {
  final MediaItem item;

  const DetailsView({super.key, required this.item});

  @override
  State<DetailsView> createState() => _DetailsViewState();
}

class _DetailsViewState extends State<DetailsView> {
  final TmdbService _tmdbService = TmdbService();
  final AniListService _aniListService = AniListService();

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
      if (widget.item.type == MediaTypeEnum.anime) {
        final d = await _aniListService.getAnimeDetails(widget.item.id);
        setState(() {
          _details = d;
          _isLoading = false;
        });
      } else if (widget.item.type == MediaTypeEnum.movie) {
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
    final media = widget.item;
    final isDubbedTarget = media.type == MediaTypeEnum.movie || media.type == MediaTypeEnum.tv;
    final sourceName = isDubbedTarget ? 'ComandoTorrents (Dual/Dublado)' : 'Nyaa.si (Legendado/Multi-sub)';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fontes de Torrent Disponíveis',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_download_outlined, color: AppTheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fonte Configurada: $sourceName',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Termo de busca: "${media.originalTitle}" ${episodeNumber != null ? 'E$episodeNumber' : ''}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'O resolvedor de torrents conectará diretamente à fonte selecionada no próximo módulo para download sequencial e reprodução via player.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Buscando magnet links para ${media.title}...'),
                        backgroundColor: AppTheme.cardHover,
                      ),
                    );
                  },
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Iniciar Busca de Torrents'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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

                  // Botão de Busca de Torrents Principal
                  SizedBox(
                    width: isDesktop ? 300 : double.infinity,
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
                  if (_details?.seasons.isNotEmpty ?? false) ...[
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Episódios',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Dropdown de Temporada
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
}
