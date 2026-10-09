import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/media_item.dart';
import '../models/torrent_item.dart';
import '../providers/downloads_provider.dart';
import '../services/comando_torrents_service.dart';
import '../services/kisskh_service.dart';
import '../services/pirate_bay_service.dart';
import '../services/tmdb_service.dart';
import '../views/player_view.dart';

class TorrentResolverSheet extends StatefulWidget {
  final MediaItem item;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? englishTitle;

  const TorrentResolverSheet({
    super.key,
    required this.item,
    this.seasonNumber,
    this.episodeNumber,
    this.englishTitle,
  });

  @override
  State<TorrentResolverSheet> createState() => _TorrentResolverSheetState();
}

class _TorrentResolverSheetState extends State<TorrentResolverSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<TorrentItem> _torrents = [];
  String _selectedFilter = 'Todos';
  late String _selectedSource;
  late TextEditingController _searchController;

  // Suporte a multi-seleção e downloads simultâneos
  bool _isMultiSelect = false;
  final Set<TorrentItem> _selectedTorrents = {};
  final Set<String> _startedInfoHashes = {};

  List<String> get _sourceList {
    if (widget.item.type == MediaTypeEnum.dorama) {
      return const ['KissKH (CDN)'];
    }
    return const ['Todos', 'Comando Torrents', 'The Pirate Bay'];
  }

  @override
  void initState() {
    super.initState();
    _selectedSource = (widget.item.type == MediaTypeEnum.dorama)
        ? 'KissKH (CDN)'
        : 'Todos';
    _searchController = TextEditingController(
      text: ComandoTorrentsService.cleanTitle(widget.item.title),
    );
    _loadTorrents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTorrents({String? customQuery}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedTorrents.clear();
    });

    int? parsedYear;
    if (widget.item.releaseDate != null && widget.item.releaseDate!.length >= 4) {
      parsedYear = int.tryParse(widget.item.releaseDate!.substring(0, 4));
    }

    final queryTitle = (customQuery != null && customQuery.trim().isNotEmpty)
        ? customQuery.trim()
        : widget.item.title;

    try {
      String? engTitle = widget.englishTitle ?? widget.item.englishTitle;
      if (engTitle == null || engTitle.isEmpty) {
        try {
          final tmdb = TmdbService();
          final details = widget.item.type == MediaTypeEnum.movie
              ? await tmdb.getMovieDetails(widget.item.id)
              : await tmdb.getTvDetails(widget.item.id, isDorama: widget.item.type == MediaTypeEnum.dorama);
          engTitle = details.englishTitle;
        } catch (_) {}
      }

      final List<TorrentItem> aggregated = [];
      final futures = <Future<List<TorrentItem>>>[];

      // Regra de fontes:
      // Doramas -> Apenas KissKH CDN
      // Filmes e Séries -> Apenas Comando Torrents e The Pirate Bay
      if (widget.item.type == MediaTypeEnum.dorama) {
        futures.add(
          KisskhService.searchTorrents(
            title: queryTitle,
            originalTitle: widget.item.originalTitle,
            englishTitle: engTitle,
            season: widget.seasonNumber,
            episode: widget.episodeNumber,
          ).catchError((e) {
            debugPrint('Erro KissKH: $e');
            return <TorrentItem>[];
          }),
        );
      } else {
        final queryComando = _selectedSource == 'Todos' || _selectedSource == 'Comando Torrents';
        final queryPirateBay = _selectedSource == 'Todos' || _selectedSource == 'The Pirate Bay';

        if (queryComando) {
          futures.add(
            ComandoTorrentsService.searchTorrents(
              title: queryTitle,
              originalTitle: widget.item.originalTitle,
              year: parsedYear,
              season: widget.seasonNumber,
              episode: widget.episodeNumber,
            ).catchError((e) {
              debugPrint('Erro ComandoTorrents: $e');
              return <TorrentItem>[];
            }),
          );
        }

        if (queryPirateBay) {
          futures.add(
            PirateBayService.searchTorrents(
              title: queryTitle,
              originalTitle: widget.item.originalTitle,
              englishTitle: engTitle,
              season: widget.seasonNumber,
              episode: widget.episodeNumber,
            ).catchError((e) {
              debugPrint('Erro The Pirate Bay: $e');
              return <TorrentItem>[];
            }),
          );
        }
      }

      final results = await Future.wait(futures);
      for (final list in results) {
        aggregated.addAll(list);
      }

      // Deduplicação por infoHash ou título normalizado
      final Map<String, TorrentItem> uniqueMap = {};
      for (final t in aggregated) {
        final key = t.infoHash.isNotEmpty ? t.infoHash.toUpperCase() : t.title.toLowerCase();
        if (!uniqueMap.containsKey(key)) {
          uniqueMap[key] = t;
        } else {
          final existing = uniqueMap[key]!;
          if ((existing.seeders ?? 0) < (t.seeders ?? 0)) {
            uniqueMap[key] = t;
          }
        }
      }

      final sorted = uniqueMap.values.toList();

      // Ordenação:
      // 1. Episódio exato se foi solicitado
      // 2. Maior quantidade de seeders
      // 3. Maior resolução (4K > 1080p > 720p)
      sorted.sort((a, b) {
        if (widget.episodeNumber != null) {
          final aExact = a.episodeNumber == widget.episodeNumber;
          final bExact = b.episodeNumber == widget.episodeNumber;
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

      if (mounted) {
        setState(() {
          _torrents = sorted;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Falha ao buscar torrents: $e';
          _isLoading = false;
        });
      }
    }
  }

  int _qualityScore(String quality) {
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

  List<TorrentItem> get _filteredTorrents {
    switch (_selectedFilter) {
      case 'Dublado':
        return _torrents.where((t) => t.isDubbed).toList();
      case 'Legendado':
        return _torrents.where((t) => t.isSubbed).toList();
      case '1080p':
        return _torrents.where((t) => t.quality == '1080p').toList();
      case '4K':
        return _torrents.where((t) => t.quality == '4K').toList();
      default:
        return _torrents;
    }
  }

  void _copyMagnet(TorrentItem torrent) {
    Clipboard.setData(ClipboardData(text: torrent.magnetUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: AppTheme.badgeGreen, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('Link magnético copiado para a área de transferência!'),
            ),
          ],
        ),
        backgroundColor: AppTheme.cardHover,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _startDownload(TorrentItem torrent) {
    setState(() {
      _startedInfoHashes.add(torrent.infoHash.toUpperCase());
    });

    context.read<DownloadsProvider>().addDownload(
      torrent: torrent,
      media: widget.item,
      seasonNumber: widget.seasonNumber,
      episodeNumber: widget.episodeNumber,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_done_rounded, color: AppTheme.badgeGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Download de "${torrent.title}" iniciado! Acompanhe na aba Downloads.'),
            ),
          ],
        ),
        backgroundColor: AppTheme.cardHover,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _startMultipleDownloads() async {
    if (_selectedTorrents.isEmpty) return;

    final torrentsToStart = _selectedTorrents.toList();
    final count = torrentsToStart.length;

    setState(() {
      for (final t in torrentsToStart) {
        _startedInfoHashes.add(t.infoHash.toUpperCase());
      }
      _selectedTorrents.clear();
      _isMultiSelect = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.downloading_rounded, color: AppTheme.badgeGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Iniciando $count downloads simultâneos...'),
            ),
          ],
        ),
        backgroundColor: AppTheme.cardHover,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );

    await context.read<DownloadsProvider>().addMultipleDownloads(
      torrents: torrentsToStart,
      media: widget.item,
      seasonNumber: widget.seasonNumber,
    );
  }

  void _startStreaming(TorrentItem torrent) async {
    if (torrent.source.contains('KissKH') || torrent.magnetUrl.startsWith('kisskh://')) {
      _startKisskhDirectStreaming(torrent);
      return;
    }

    final downloads = context.read<DownloadsProvider>();
    final item = await downloads.addDownload(
      torrent: torrent,
      media: widget.item,
      seasonNumber: widget.seasonNumber,
      episodeNumber: widget.episodeNumber,
    );
    if (!mounted) return;

    Navigator.pop(context);

    final epSubtitle = widget.episodeNumber != null
        ? 'T${widget.seasonNumber ?? 1} E${widget.episodeNumber} • ${torrent.quality} • ${torrent.source}'
        : '${torrent.quality} • ${torrent.source}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerView(
          title: widget.item.title,
          subtitle: epSubtitle,
          posterUrl: widget.item.posterUrl,
          backdropUrl: widget.item.backdropUrl,
          downloadItem: item,
          torrentId: item.id,
        ),
      ),
    );
  }

  void _startKisskhDirectStreaming(TorrentItem torrent) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text(
                'Conectando ao CDN de alta velocidade do KissKH...',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );

    final downloads = context.read<DownloadsProvider>();
    final item = await downloads.addDownload(
      torrent: torrent,
      media: widget.item,
      seasonNumber: widget.seasonNumber,
      episodeNumber: widget.episodeNumber,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // fecha dialog de carregamento
    Navigator.pop(context); // fecha sheet de seleção

    final epSubtitle = widget.episodeNumber != null
        ? 'T${widget.seasonNumber ?? 1} E${widget.episodeNumber} • KissKH CDN'
        : 'KissKH CDN';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerView(
          title: widget.item.title,
          subtitle: epSubtitle,
          posterUrl: widget.item.posterUrl,
          backdropUrl: widget.item.backdropUrl,
          downloadItem: item,
          torrentId: item.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.item;
    final epLabel = widget.episodeNumber != null
        ? ' (T${widget.seasonNumber ?? 1}:E${widget.episodeNumber})'
        : '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_download_rounded, color: AppTheme.primary, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${media.title}$epLabel',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.badgeGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.item.type == MediaTypeEnum.dorama
                                  ? 'Fonte: KissKH (CDN Ultra Rápido)'
                                  : (_selectedSource == 'Todos'
                                      ? 'Fontes: Comando Torrents • The Pirate Bay'
                                      : 'Fonte: $_selectedSource'),
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Botão de alternar multi-seleção
                if (!_isLoading && _torrents.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isMultiSelect = !_isMultiSelect;
                        if (!_isMultiSelect) _selectedTorrents.clear();
                      });
                    },
                    icon: Icon(
                      _isMultiSelect ? Icons.close_rounded : Icons.checklist_rounded,
                      size: 18,
                      color: _isMultiSelect ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    label: Text(
                      _isMultiSelect ? 'Cancelar' : 'Selecionar Vários',
                      style: TextStyle(
                        color: _isMultiSelect ? AppTheme.primary : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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

          // Barra de pesquisa
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar termo específico...',
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                    onSubmitted: (val) => _loadTorrents(customQuery: val),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _loadTorrents(customQuery: _searchController.text),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Chips de Fonte (Apenas para Filmes/Séries onde há mais de uma fonte)
          if (_sourceList.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Text(
                    'Fonte:',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  for (final source in _sourceList) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Icon(_getSourceIcon(source), size: 14, color: _getSourceColor(source)),
                        label: Text(source),
                        selected: _selectedSource == source,
                        selectedColor: AppTheme.primary.withOpacity(0.2),
                        backgroundColor: AppTheme.surface,
                        labelStyle: TextStyle(
                          color: _selectedSource == source ? AppTheme.primary : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: _selectedSource == source ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: _selectedSource == source ? AppTheme.primary : AppTheme.border,
                        ),
                        onSelected: (selected) {
                          if (selected && _selectedSource != source) {
                            setState(() => _selectedSource = source);
                            _loadTorrents(customQuery: _searchController.text);
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Chips de Filtro Secundário (Qualidade / Áudio)
          if (!_isLoading && _torrents.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  for (final filter in ['Todos', 'Dublado', 'Legendado', '1080p', '4K']) ...[
                    ChoiceChip(
                      label: Text(filter),
                      selected: _selectedFilter == filter,
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.surface,
                      labelStyle: TextStyle(
                        color: _selectedFilter == filter ? Colors.white : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: _selectedFilter == filter ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: _selectedFilter == filter ? AppTheme.primary : AppTheme.border,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedFilter = filter);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 6),

          // Lista de resultados
          Expanded(
            child: _buildBody(),
          ),

          // Barra inferior de ação para Downloads Múltiplos
          if (_isMultiSelect)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedTorrents.length == _filteredTorrents.length) {
                            _selectedTorrents.clear();
                          } else {
                            _selectedTorrents.addAll(_filteredTorrents);
                          }
                        });
                      },
                      child: Text(
                        _selectedTorrents.length == _filteredTorrents.length
                            ? 'Desmarcar Todos'
                            : 'Selecionar Todos',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _selectedTorrents.isNotEmpty ? _startMultipleDownloads : null,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text('Baixar (${_selectedTorrents.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              widget.item.type == MediaTypeEnum.dorama
                  ? 'Buscando episódios no KissKH CDN...'
                  : 'Consultando ${_selectedSource == 'Todos' ? 'Comando Torrents e The Pirate Bay' : _selectedSource}...',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.primary, size: 40),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadTorrents(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar Novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surface,
                  foregroundColor: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final list = _filteredTorrents;

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, color: AppTheme.textMuted, size: 48),
              const SizedBox(height: 12),
              Text(
                'Nenhum resultado encontrado em "$_selectedSource"',
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tente pesquisar pelo título original ou termo específico.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return _buildTorrentCard(item);
      },
    );
  }

  Widget _buildTorrentCard(TorrentItem torrent) {
    final downloads = context.watch<DownloadsProvider>();
    final isAlreadyInDownloads = _startedInfoHashes.contains(torrent.infoHash.toUpperCase()) ||
        downloads.allDownloads.any((d) => d.infoHash.toUpperCase() == torrent.infoHash.toUpperCase());
    final isSelected = _selectedTorrents.contains(torrent);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withOpacity(0.08) : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppTheme.primary : AppTheme.border,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isMultiSelect
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedTorrents.remove(torrent);
                  } else {
                    _selectedTorrents.add(torrent);
                  }
                });
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isMultiSelect) ...[
                    Checkbox(
                      value: isSelected,
                      activeColor: AppTheme.primary,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedTorrents.add(torrent);
                          } else {
                            _selectedTorrents.remove(torrent);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      torrent.rawLabel.isNotEmpty ? torrent.rawLabel : torrent.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Copiar Magnet Link',
                    icon: const Icon(Icons.copy_rounded, color: AppTheme.textMuted, size: 20),
                    onPressed: () => _copyMagnet(torrent),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Badge de Fonte
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getSourceColor(torrent.source).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _getSourceColor(torrent.source)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getSourceIcon(torrent.source), size: 12, color: _getSourceColor(torrent.source)),
                        const SizedBox(width: 4),
                        Text(
                          torrent.source,
                          style: TextStyle(
                            color: _getSourceColor(torrent.source),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Badge de Velocidade / Seeders
                  if (torrent.source.contains('KissKH'))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.bolt_rounded, size: 13, color: Colors.amber),
                          SizedBox(width: 3),
                          Text(
                            'CDN Ultra Rápido',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (torrent.seeders != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_upward_rounded, size: 12, color: AppTheme.badgeGreen),
                          const SizedBox(width: 2),
                          Text(
                            '${torrent.seeders} seeds',
                            style: const TextStyle(
                              color: AppTheme.badgeGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Resolução
                  if (torrent.quality.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getQualityColor(torrent.quality).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _getQualityColor(torrent.quality).withOpacity(0.4)),
                      ),
                      child: Text(
                        torrent.quality,
                        style: TextStyle(
                          color: _getQualityColor(torrent.quality),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Tamanho
                  if (torrent.size != null && torrent.size!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        torrent.size!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // Áudio
                  if (torrent.audioLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: torrent.isDubbed
                            ? AppTheme.badgeGreen.withOpacity(0.15)
                            : AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: torrent.isDubbed ? AppTheme.badgeGreen : AppTheme.primary,
                        ),
                      ),
                      child: Text(
                        torrent.audioLabel,
                        style: TextStyle(
                          color: torrent.isDubbed ? AppTheme.badgeGreen : AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Episódio
                  if (torrent.episodeNumber != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        'EP ${torrent.episodeNumber}',
                        style: const TextStyle(
                          color: AppTheme.starRating,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_isMultiSelect)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isAlreadyInDownloads ? null : () => _startDownload(torrent),
                        icon: Icon(
                          isAlreadyInDownloads ? Icons.check_circle_rounded : Icons.download_rounded,
                          size: 18,
                        ),
                        label: Text(isAlreadyInDownloads ? 'Baixando' : 'Baixar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAlreadyInDownloads ? AppTheme.cardHover : AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _startStreaming(torrent),
                        icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                        label: const Text('Assistir (Stream)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSourceColor(String source) {
    final lower = source.toLowerCase();
    if (lower.contains('kisskh')) {
      return Colors.pinkAccent;
    }
    switch (lower) {
      case 'the pirate bay':
        return Colors.deepOrangeAccent;
      case 'todos':
        return AppTheme.primary;
      case 'comando torrents':
      default:
        return AppTheme.badgeGreen;
    }
  }

  IconData _getSourceIcon(String source) {
    final lower = source.toLowerCase();
    if (lower.contains('kisskh')) {
      return Icons.cloud_download_rounded;
    }
    switch (lower) {
      case 'the pirate bay':
        return Icons.sailing_rounded;
      case 'todos':
        return Icons.hub_rounded;
      case 'comando torrents':
      default:
        return Icons.movie_filter_rounded;
    }
  }

  Color _getQualityColor(String quality) {
    switch (quality.toUpperCase()) {
      case '4K':
        return AppTheme.starRating;
      case '1080P':
        return Colors.cyanAccent;
      case '720P':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textMuted;
    }
  }
}
