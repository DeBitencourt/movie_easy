import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../models/download_item.dart';
import '../providers/downloads_provider.dart';
import 'player_view.dart';

class DownloadsView extends StatefulWidget {
  const DownloadsView({super.key});

  @override
  State<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends State<DownloadsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Downloads',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
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
                            const SizedBox(width: 8),
                            Text(
                              'Motor Libtorrent Nativo • ${downloads.downloadDirectory.split(RegExp(r'[\\/]')).last}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Ações do Cabeçalho (Velocidade Global e Remover Todos)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      // Pill de velocidade global
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_downward_rounded, color: AppTheme.badgeGreen, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              downloads.totalDownloadSpeed,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Botão Remover Todos os Downloads
                      if (downloads.allDownloads.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => _confirmRemoveAllDownloads(downloads),
                          icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
                          label: const Text('Remover Todos', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 3,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                dividerColor: AppTheme.border,
                tabs: [
                  Tab(text: 'Em Andamento (${downloads.activeCount})'),
                  Tab(text: 'Concluídos (${downloads.completedDownloads.length})'),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDownloadList(downloads.activeDownloads, downloads, isActiveTab: true),
                  _buildDownloadList(downloads.completedDownloads, downloads, isActiveTab: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadList(List<DownloadItem> items, DownloadsProvider provider, {required bool isActiveTab}) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActiveTab ? Icons.downloading_rounded : Icons.task_alt_rounded,
                color: AppTheme.border,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                isActiveTab ? 'Nenhum download em andamento' : 'Nenhum download concluído ainda',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isActiveTab
                    ? 'Ao navegar pelos filmes e séries, clique em "Baixar" no modal de torrents para iniciar.'
                    : 'Os arquivos salvos aparecerão aqui e na pasta MovieEasy_Downloads do seu dispositivo.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildDownloadCard(item, provider);
      },
    );
  }

  Widget _buildDownloadCard(DownloadItem item, DownloadsProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster ou ícone de mídia
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.posterUrl!,
                        width: 50,
                        height: 70,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildFallbackThumbnail(),
                      )
                    : _buildFallbackThumbnail(),
              ),
              const SizedBox(width: 14),

              // Título e detalhes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (item.quality != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Text(
                              item.quality!,
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (item.audio != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Text(
                              item.audio!,
                              style: const TextStyle(
                                color: AppTheme.badgeGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Text(
                          item.stateLabel,
                          style: TextStyle(
                            color: item.isPaused ? AppTheme.starRating : AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Botões de ação rápida
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!item.isFinished)
                    IconButton(
                      icon: Icon(
                        item.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: AppTheme.textPrimary,
                      ),
                      tooltip: item.isPaused ? 'Retomar' : 'Pausar',
                      onPressed: () {
                        if (item.isPaused) {
                          provider.resumeDownload(item.id);
                        } else {
                          provider.pauseDownload(item.id);
                        }
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.folder_open_rounded, color: AppTheme.textSecondary),
                      tooltip: 'Abrir pasta do arquivo',
                      onPressed: () {
                        final local = provider.getLocalVideoFilePathForItem(item);
                        provider.openDownloadFolder(filePath: local);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    tooltip: item.isFinished ? 'Remover' : 'Cancelar',
                    onPressed: () => _confirmCancel(item, provider),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Barra de Progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (!item.hasMetadata && !item.isPaused && !item.isFinished)
                  ? null
                  : (item.isFinished ? 1.0 : item.progress.clamp(0.0, 1.0)),
              backgroundColor: AppTheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                item.isFinished
                    ? AppTheme.badgeGreen
                    : item.isPaused
                        ? AppTheme.starRating
                        : (!item.hasMetadata ? Colors.amberAccent : AppTheme.primary),
              ),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 10),

          // Métricas em linha
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.hasMetadata
                    ? (item.isFinished ? item.formattedSize : '${item.formattedProgress} • ${item.formattedSize}')
                    : item.formattedSize,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              Row(
                children: [
                  if (!item.isFinished && !item.isPaused) ...[
                    if (item.hasMetadata)
                      Text(
                        '${item.formattedSpeed} • ',
                        style: const TextStyle(
                          color: AppTheme.badgeGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      item.hasMetadata
                          ? '${item.numSeeds < 0 ? 0 : item.numSeeds} seeds • ${item.formattedEta}'
                          : '${item.numSeeds < 0 ? 0 : item.numSeeds} seeds • ${item.numPeers < 0 ? 0 : item.numPeers} peers',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ] else if (item.isFinished) ...[
                    const Icon(Icons.check_circle_rounded, color: AppTheme.badgeGreen, size: 14),
                    const SizedBox(width: 4),
                    const Text(
                      'Download Concluído',
                      style: TextStyle(
                        color: AppTheme.badgeGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Pausado',
                      style: TextStyle(color: AppTheme.starRating, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Botão de Assistir / Streaming
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerView(
                      title: item.title,
                      subtitle: item.quality != null
                          ? '${item.quality} • ${item.audio ?? ""}'
                          : null,
                      posterUrl: item.posterUrl,
                      downloadItem: item,
                      torrentId: item.id,
                    ),
                  ),
                );
              },
              icon: Icon(
                item.isFinished ? Icons.play_arrow_rounded : Icons.play_circle_fill_rounded,
                size: 20,
              ),
              label: Text(
                item.isFinished
                    ? 'Assistir Agora (Arquivo Concluído)'
                    : 'Assistir Agora (Streaming Sequencial)',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: item.isFinished ? AppTheme.primary : AppTheme.surface,
                foregroundColor: item.isFinished ? Colors.white : AppTheme.textPrimary,
                side: item.isFinished ? BorderSide.none : const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      width: 50,
      height: 70,
      color: AppTheme.surface,
      child: const Icon(Icons.movie_rounded, color: AppTheme.textMuted, size: 24),
    );
  }

  void _confirmCancel(DownloadItem item, DownloadsProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar Download', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: Text(
          'Deseja realmente cancelar e excluir "${item.title}"?',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.cancelDownload(item.id, deleteFiles: true);
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

  void _confirmRemoveAllDownloads(DownloadsProvider provider) {
    final count = provider.allDownloads.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text('Remover Todos os Downloads', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
          ],
        ),
        content: Text(
          'Deseja cancelar todos os $count downloads e excluir permanentemente todos os arquivos do computador?\n\nEsta ação não poderá ser desfeita.',
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
              Navigator.pop(ctx);
              await provider.removeAllDownloads(deleteFiles: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Todos os downloads foram removidos com sucesso.'),
                    backgroundColor: Colors.redAccent,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Remover Tudo'),
          ),
        ],
      ),
    );
  }
}
