import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/settings_provider.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _apiKeyController = TextEditingController(text: settings.tmdbApiKey);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Configurações'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('METADADOS & CATÁLOGO'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chave de API do TMDB',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Usada para carregar pôsteres, sinopses em PT-BR e episódios de filmes, séries e doramas.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _apiKeyController,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Insira sua chave do TMDB...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          settings.setTmdbApiKey(_apiKeyController.text);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Chave do TMDB salva com sucesso!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader('PREFERÊNCIAS DE REPRODUÇÃO & TORRENT'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Áudio Preferencial', style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: const Text(
                    'Filmes e Séries buscarão prioritariamente arquivos dublados',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: settings.preferredAudio,
                    dropdownColor: AppTheme.card,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'dublado', child: Text('Dublado (PT-BR)')),
                      DropdownMenuItem(value: 'legendado', child: Text('Original Legendado')),
                    ],
                    onChanged: (val) {
                      if (val != null) settings.setPreferredAudio(val);
                    },
                  ),
                ),
                const Divider(color: AppTheme.border, height: 1),
                ListTile(
                  title: const Text('Resolução Padrão', style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: const Text(
                    'Filtro padrão ao resolver links de torrent',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: settings.preferredQuality,
                    dropdownColor: AppTheme.card,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: '720p', child: Text('720p HD')),
                      DropdownMenuItem(value: '1080p', child: Text('1080p Full HD')),
                      DropdownMenuItem(value: '4k', child: Text('4K Ultra HD')),
                    ],
                    onChanged: (val) {
                      if (val != null) settings.setPreferredQuality(val);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader('STATUS DOS INDEXADORES & FONTES'),
          Card(
            child: Column(
              children: [
                _buildSourceStatusTile(
                  name: 'TMDB API',
                  category: 'Filmes, Séries & Doramas',
                  status: 'Ativo',
                  color: AppTheme.badgeGreen,
                ),
                const Divider(color: AppTheme.border, height: 1),
                _buildSourceStatusTile(
                  name: 'AniList GraphQL',
                  category: 'Catálogo de Animes',
                  status: 'Ativo (Público)',
                  color: AppTheme.badgeGreen,
                ),
                const Divider(color: AppTheme.border, height: 1),
                _buildSourceStatusTile(
                  name: 'Comando Torrents',
                  category: 'Fonte: Filmes/Séries Dublados',
                  status: 'Configurado',
                  color: AppTheme.secondary,
                ),
                const Divider(color: AppTheme.border, height: 1),
                _buildSourceStatusTile(
                  name: 'Nyaa.si (Anime & Live Action)',
                  category: 'Fonte: Animes & Doramas Legendados',
                  status: 'Configurado',
                  color: AppTheme.secondary,
                ),
                const Divider(color: AppTheme.border, height: 1),
                _buildSourceStatusTile(
                  name: 'OpenSubtitles API',
                  category: 'Legendas Complementares em PT-BR',
                  status: 'Pronto',
                  color: AppTheme.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSourceStatusTile({
    required String name,
    required String category,
    required String status,
    required Color color,
  }) {
    return ListTile(
      dense: true,
      title: Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(category, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          status,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
