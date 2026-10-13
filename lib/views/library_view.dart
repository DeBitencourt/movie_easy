import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../models/download_item.dart';
import '../models/library_entry.dart';
import '../models/media_item.dart';
import '../providers/downloads_provider.dart';
import 'library_series_view.dart';
import 'player_view.dart';

/// Aba "Biblioteca" — exibe e organiza todos os filmes, séries e doramas
/// baixados ou prontos para reprodução offline no dispositivo, agrupando
/// séries com múltiplos episódios sob um único card consolidado.
class LibraryView extends StatefulWidget {
  final VoidCallback? onExploreCatalog;

  const LibraryView({
    super.key,
    this.onExploreCatalog,
  });

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  late final TextEditingController _searchController;

  final List<String> _categories = [
    'Todos',
    'Filmes',
    'Séries',
    'Doramas',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  MediaTypeEnum? _getCategoryType(String category) {
    switch (category) {
      case 'Filmes':
        return MediaTypeEnum.movie;
      case 'Séries':
        return MediaTypeEnum.tv;
      case 'Doramas':
        return MediaTypeEnum.dorama;
      default:
        return null;
    }
  }

  int _countForCategory(List<LibraryEntry> entries, String category) {
    if (category == 'Todos') return entries.length;
    final type = _getCategoryType(category);
    return entries.where((e) => e.mediaType == type).length;
  }

  List<LibraryEntry> _filterEntries(List<LibraryEntry> entries) {
    var filtered = entries;

    // Filtro por Categoria
    final targetType = _getCategoryType(_selectedCategory);
    if (targetType != null) {
      filtered = filtered.where((e) => e.mediaType == targetType).toList();
    }

    // Filtro por Pesquisa de Texto
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((e) {
        if (e.title.toLowerCase().contains(q)) return true;
        return e.episodes.any((ep) => ep.title.toLowerCase().contains(q));
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();
    final allEntries = downloads.libraryEntries;
    final totalVideoFiles = downloads.libraryItems.length;
    final filteredEntries = _filterEntries(allEntries);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Top Bar & Header da Biblioteca
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                                    ),
                                    child: const Icon(
                                      Icons.video_library_rounded,
                                      color: AppTheme.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Minha Biblioteca',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${allEntries.length} título${allEntries.length == 1 ? '' : 's'} salvo${allEntries.length == 1 ? '' : 's'}'
                                '${totalVideoFiles > allEntries.length ? ' ($totalVideoFiles episódios/vídeos)' : ''}'
                                ' • ${downloads.totalLibraryDiskUsage} em disco',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Ações da Biblioteca (Excluir Todos os Episódios / Abrir Pasta)
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (allEntries.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () => _confirmDeleteAllLibrary(downloads),
                                icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
                                label: const Text('Excluir Todos os Episódios', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => downloads.openDownloadFolder(),
                              icon: const Icon(Icons.folder_open_rounded, size: 18),
                              label: const Text('Abrir Pasta'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textPrimary,
                                side: const BorderSide(color: AppTheme.border),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Barra de Busca Rápida
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Buscar título na biblioteca...',
                              hintStyle: const TextStyle(color: AppTheme.textMuted),
                              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                              filled: true,
                              fillColor: AppTheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Chips de Categorias com Contagens Agrupadas (Todos, Filmes, Séries, Doramas)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          final count = _countForCategory(allEntries, cat);

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text('$cat ($count)'),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              },
                              backgroundColor: AppTheme.surface,
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? AppTheme.primary : AppTheme.border,
                                ),
                              ),
                              showCheckmark: false,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Conteúdo: Grid de Mídias Agrupadas ou Estado Vazio
            if (filteredEntries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(allEntries.isEmpty),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.58,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 18,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) => _buildLibraryEntryCard(filteredEntries[idx], downloads),
                    childCount: filteredEntries.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryEntryCard(LibraryEntry entry, DownloadsProvider downloads) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openEntry(entry),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pôster com Overlay de Play e Badges
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    entry.posterUrl != null && entry.posterUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: entry.posterUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _buildFallbackPoster(),
                          )
                        : _buildFallbackPoster(),

                    // Gradiente escuro para legibilidade
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                            Colors.black.withOpacity(0.85),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),

                    // Badge de Categoria no Topo Esquerdo
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildCategoryBadge(entry.mediaType),
                    ),

                    // Badge de Quantidade de Episódios ou Qualidade no Topo Direito
                    Positioned(
                      top: 8,
                      right: 8,
                      child: entry.isSeries
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.layers_rounded, color: Colors.amberAccent, size: 11),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${entry.episodeCount} ${entry.episodeCount == 1 ? 'EP' : 'EPS'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : (entry.quality != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Text(
                                    entry.quality!,
                                    style: const TextStyle(
                                      color: Colors.cyanAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : const SizedBox()),
                    ),



                    // Detalhes no rodapé do Pôster (Tamanho em disco total e Áudio)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.sd_storage_rounded, color: AppTheme.textMuted, size: 10),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      entry.formattedSize,
                                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (entry.audio != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.audio!,
                                style: const TextStyle(color: AppTheme.badgeGreen, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Informações do Título e Ações
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.isSeries
                          ? '${entry.episodeCount} episódio${entry.episodeCount == 1 ? '' : 's'} baixado${entry.episodeCount == 1 ? '' : 's'}'
                          : (entry.quality != null ? '${entry.quality!} • Filme' : 'Filme Completo'),
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Botão Principal (Ver Episódios para Séries / Assistir para Filmes)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (entry.isSeries) {
                            _openEntry(entry);
                          } else {
                            _playItem(entry.firstEpisode);
                          }
                        },
                        icon: Icon(
                          entry.isSeries ? Icons.video_library_rounded : Icons.play_arrow_rounded,
                          size: 15,
                        ),
                        label: Text(
                          entry.isSeries ? 'Ver Episódios (${entry.episodeCount})' : 'Assistir',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Linha de ações secundárias (Abrir pasta / Excluir)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () {
                            if (entry.isSeries) {
                              downloads.openSeriesFolder(entry);
                            } else {
                              final localFile = downloads.getLocalVideoFilePathForItem(entry.firstEpisode);
                              downloads.openDownloadFolder(filePath: localFile);
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Row(
                              children: const [
                                Icon(Icons.folder_open_rounded, size: 14, color: AppTheme.textMuted),
                                SizedBox(width: 4),
                                Text('Pasta', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _confirmDeleteEntry(entry, downloads),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Row(
                              children: const [
                                Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                                SizedBox(width: 4),
                                Text('Excluir', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                              ],
                            ),
                          ),
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
  }

  void _openEntry(LibraryEntry entry) {
    if (entry.isSeries) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LibrarySeriesView(entry: entry),
        ),
      );
    } else {
      _playItem(entry.firstEpisode);
    }
  }

  Widget _buildCategoryBadge(MediaTypeEnum? type) {
    String label = 'FILME';
    Color bg = Colors.redAccent;

    switch (type) {
      case MediaTypeEnum.movie:
        label = 'FILME';
        bg = Colors.redAccent;
        break;
      case MediaTypeEnum.tv:
        label = 'SÉRIE';
        bg = Colors.blueAccent;
        break;
      case MediaTypeEnum.dorama:
        label = 'DORAMA';
        bg = Colors.pinkAccent;
        break;
      default:
        label = 'VÍDEO';
        bg = AppTheme.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFallbackPoster() {
    return Container(
      color: AppTheme.surface,
      child: const Center(
        child: Icon(Icons.movie_rounded, color: AppTheme.textMuted, size: 40),
      ),
    );
  }

  Widget _buildEmptyState(bool isTotallyEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(
                Icons.video_library_outlined,
                color: AppTheme.textMuted,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isTotallyEmpty ? 'Sua Biblioteca está vazia' : 'Nenhum resultado encontrado',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isTotallyEmpty
                  ? 'Os filmes, séries, doramas e animes baixados ficarão organizados aqui para você assistir offline a qualquer momento.'
                  : 'Nenhum título corresponde ao filtro ou busca selecionada.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            if (isTotallyEmpty && widget.onExploreCatalog != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: widget.onExploreCatalog,
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: const Text('Explorar Catálogo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _playItem(DownloadItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerView(
          title: item.cleanMediaTitle,
          subtitle: item.quality != null ? '${item.quality} • ${item.audio ?? ""}' : null,
          posterUrl: item.posterUrl,
          backdropUrl: item.backdropUrl,
          downloadItem: item,
          torrentId: item.id,
        ),
      ),
    );
  }

  void _confirmDeleteEntry(LibraryEntry entry, DownloadsProvider downloads) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          entry.isSeries ? 'Excluir Série' : 'Excluir da Biblioteca',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17),
        ),
        content: Text(
          entry.isSeries
              ? 'Deseja realmente excluir "${entry.title}" (${entry.episodeCount} episódios) da sua biblioteca?'
              : 'Deseja realmente excluir "${entry.title}" da sua biblioteca?',
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
              if (entry.isSeries) {
                downloads.deleteSeries(entry, deleteFiles: true);
              } else {
                downloads.cancelDownload(entry.firstEpisode.id, deleteFiles: true);
              }
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

  void _confirmDeleteAllLibrary(DownloadsProvider downloads) {
    final epCount = downloads.libraryItems.length;
    final titlesCount = downloads.libraryTitlesCount;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text('Excluir Todos os Episódios', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
          ],
        ),
        content: Text(
          'Deseja realmente excluir todos os episódios e vídeos da biblioteca ($epCount arquivo${epCount == 1 ? '' : 's'} em $titlesCount título${titlesCount == 1 ? '' : 's'}) e liberar ${downloads.totalLibraryDiskUsage} de espaço em disco?\n\nEsta ação apagará permanentemente os arquivos locais do computador.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await downloads.deleteAllLibraryItems(deleteFiles: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Todos os episódios e vídeos da biblioteca foram excluídos.'),
                    backgroundColor: Colors.redAccent,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Excluir Tudo'),
          ),
        ],
      ),
    );
  }
}
