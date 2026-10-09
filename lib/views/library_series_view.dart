import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../models/download_item.dart';
import '../models/library_entry.dart';
import '../models/media_item.dart';
import '../providers/downloads_provider.dart';
import 'details_view.dart';
import 'player_view.dart';

/// Tela dedicada para visualizar uma série ou dorama da biblioteca,
/// listando todos os episódios salvos offline de forma organizada.
class LibrarySeriesView extends StatefulWidget {
  final LibraryEntry entry;

  const LibrarySeriesView({
    super.key,
    required this.entry,
  });

  @override
  State<LibrarySeriesView> createState() => _LibrarySeriesViewState();
}

class _LibrarySeriesViewState extends State<LibrarySeriesView> {
  int? _selectedSeason;

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();

    // Buscar entrada atualizada no provider (reativo caso episódios sejam deletados ou baixados)
    final currentEntry = downloads.libraryEntries.firstWhere(
      (e) => e.key == widget.entry.key,
      orElse: () => widget.entry,
    );

    // Se todos os episódios foram removidos, voltar à tela anterior
    if (!downloads.libraryEntries.any((e) => e.key == widget.entry.key)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const Scaffold(backgroundColor: AppTheme.background);
    }

    final episodes = currentEntry.episodes;

    // Detectar todas as temporadas presentes
    final seasons = episodes
        .map((e) => e.resolvedSeasonNumber ?? 1)
        .toSet()
        .toList()
      ..sort();

    // Filtrar episódios pela temporada selecionada, se houver múltiplas temporadas
    final displayedEpisodes = _selectedSeason == null
        ? episodes
        : episodes.where((e) => (e.resolvedSeasonNumber ?? 1) == _selectedSeason).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Header Imersivo com Backdrop da Série
          SliverAppBar(
            expandedHeight: isDesktop ? 340 : 260,
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
                  if (currentEntry.backdropUrl != null && currentEntry.backdropUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: currentEntry.backdropUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorWidget: (_, __, ___) => _buildFallbackBackdrop(currentEntry),
                    )
                  else
                    _buildFallbackBackdrop(currentEntry),

                  // Gradiente escuro para legibilidade
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.35),
                          AppTheme.background.withOpacity(0.7),
                          AppTheme.background,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),

                  // Conteúdo do cabeçalho
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 18,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Pôster pequeno
                        if (currentEntry.posterUrl != null && currentEntry.posterUrl!.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: currentEntry.posterUrl!,
                                width: isDesktop ? 100 : 70,
                                height: isDesktop ? 150 : 105,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const SizedBox(),
                              ),
                            ),
                          ),
                        const SizedBox(width: 18),

                        // Detalhes textuais
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  _buildCategoryBadge(currentEntry.mediaType),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Text(
                                      '${currentEntry.episodeCount} EPISÓDIO${currentEntry.episodeCount == 1 ? '' : 'S'}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentEntry.title,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: isDesktop ? 28 : 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.sd_storage_rounded, size: 14, color: AppTheme.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${currentEntry.formattedSize} em disco',
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                  ),
                                  if (currentEntry.audio != null) ...[
                                    const Text(' • ', style: TextStyle(color: AppTheme.textMuted)),
                                    Text(
                                      currentEntry.audio!,
                                      style: const TextStyle(color: AppTheme.badgeGreen, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Barra de Ações Principais da Série
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Botão principal: Assistir Primeiro Episódio
                  ElevatedButton.icon(
                    onPressed: episodes.isNotEmpty
                        ? () => _playEpisode(context, episodes.first)
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text('Assistir Ep. ${episodes.first.resolvedEpisodeNumber ?? 1}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  // Botão: Abrir Pasta da Série
                  OutlinedButton.icon(
                    onPressed: () => downloads.openSeriesFolder(currentEntry),
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('Abrir Pasta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  // Botão: Ver no Catálogo Online (para baixar mais episódios ou ver sinopse)
                  if (currentEntry.mediaId != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailsView(item: currentEntry.toMediaItem()),
                          ),
                        );
                      },
                      icon: const Icon(Icons.explore_outlined, size: 18),
                      label: const Text('Ver no Catálogo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                  // Botão: Excluir Série Completa
                  OutlinedButton.icon(
                    onPressed: () => _confirmDeleteSeries(context, currentEntry, downloads),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    label: const Text('Excluir Série', style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Seletor de Temporadas (quando houver mais de uma temporada salva)
          if (seasons.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('Todas (${episodes.length})'),
                          selected: _selectedSeason == null,
                          onSelected: (_) => setState(() => _selectedSeason = null),
                          selectedColor: AppTheme.primary,
                          backgroundColor: AppTheme.surface,
                          labelStyle: TextStyle(
                            color: _selectedSeason == null ? Colors.white : AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...seasons.map((season) {
                        final count = episodes.where((e) => (e.resolvedSeasonNumber ?? 1) == season).length;
                        final isSelected = _selectedSeason == season;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('Temporada $season ($count)'),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedSeason = season),
                            selectedColor: AppTheme.primary,
                            backgroundColor: AppTheme.surface,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

          // Lista de Episódios
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) {
                  final episode = displayedEpisodes[idx];
                  return _buildEpisodeRow(ctx, episode, downloads, currentEntry);
                },
                childCount: displayedEpisodes.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeRow(
    BuildContext context,
    DownloadItem episode,
    DownloadsProvider downloads,
    LibraryEntry seriesEntry,
  ) {
    final epNum = episode.resolvedEpisodeNumber;
    final seasonNum = episode.resolvedSeasonNumber ?? 1;
    final epBadge = epNum != null ? 'EP ${epNum.toString().padLeft(2, '0')}' : 'VÍDEO';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _playEpisode(context, episode),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Badge de número do episódio com ícone de Play
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            epBadge,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (epNum != null)
                            Text(
                              'T$seasonNum',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 28),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Informações do Episódio
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.episodeCleanName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (episode.quality != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Text(
                                episode.quality!,
                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (episode.audio != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Text(
                                episode.audio!,
                                style: const TextStyle(color: AppTheme.badgeGreen, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          Text(
                            episode.formattedSize.contains('/')
                                ? episode.formattedSize.split('/').last.trim()
                                : episode.formattedSize,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                          const Text('•', style: TextStyle(color: AppTheme.textMuted)),
                          const Text(
                            'Disponível Offline',
                            style: TextStyle(color: AppTheme.badgeGreen, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Botão Assistir
                ElevatedButton.icon(
                  onPressed: () => _playEpisode(context, episode),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Assistir', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),

                // Menu de mais opções (Abrir pasta / Excluir episódio)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted),
                  color: AppTheme.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onSelected: (val) {
                    if (val == 'folder') {
                      final localFile = downloads.getLocalVideoFilePathForItem(episode);
                      downloads.openDownloadFolder(filePath: localFile);
                    } else if (val == 'delete') {
                      _confirmDeleteEpisode(context, episode, downloads);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'folder',
                      child: Row(
                        children: [
                          Icon(Icons.folder_open_rounded, size: 16, color: AppTheme.textPrimary),
                          SizedBox(width: 8),
                          Text('Abrir no Explorador', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Excluir Episódio', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(MediaTypeEnum type) {
    String label = 'SÉRIE';
    Color bg = Colors.blueAccent;

    if (type == MediaTypeEnum.dorama) {
      label = 'DORAMA';
      bg = Colors.pinkAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFallbackBackdrop(LibraryEntry entry) {
    return Container(
      color: AppTheme.surface,
      child: const Center(
        child: Icon(Icons.tv_rounded, color: AppTheme.border, size: 80),
      ),
    );
  }

  void _playEpisode(BuildContext context, DownloadItem episode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerView(
          title: episode.cleanMediaTitle,
          subtitle: '${episode.episodeCleanName} • ${episode.quality ?? ""} • ${episode.audio ?? ""}',
          posterUrl: episode.posterUrl,
          backdropUrl: episode.backdropUrl,
          downloadItem: episode,
          torrentId: episode.id,
        ),
      ),
    );
  }

  void _confirmDeleteEpisode(BuildContext context, DownloadItem episode, DownloadsProvider downloads) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir Episódio', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: Text(
          'Deseja realmente excluir "${episode.episodeCleanName}" da biblioteca?',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              downloads.cancelDownload(episode.id, deleteFiles: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSeries(BuildContext context, LibraryEntry series, DownloadsProvider downloads) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir Série Completa', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: Text(
          'Deseja realmente excluir "${series.title}" e todos os seus ${series.episodeCount} episódios da biblioteca?',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              downloads.deleteSeries(series, deleteFiles: true);
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir Tudo'),
          ),
        ],
      ),
    );
  }
}
