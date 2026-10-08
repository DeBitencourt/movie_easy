import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/media_item.dart';
import 'home_view.dart';
import 'category_view.dart';
import 'search_view.dart';
import 'settings_view.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeView(),
    CategoryView(type: MediaTypeEnum.movie),
    CategoryView(type: MediaTypeEnum.tv),
    CategoryView(type: MediaTypeEnum.dorama),
    CategoryView(type: MediaTypeEnum.anime),
    SearchView(),
    SettingsView(),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Row(
          children: [
            // Sidebar Lateral para Desktop
            _buildDesktopSidebar(),
            // Divisor sutil
            Container(width: 1, color: AppTheme.border),
            // Conteúdo Principal
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _pages,
              ),
            ),
          ],
        ),
      );
    }

    // Layout para Telas Estreitas / Mobile
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: NavigationBar(
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.primary.withOpacity(0.2),
          selectedIndex: _currentIndex > 4 ? 0 : _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppTheme.textSecondary),
              selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primary),
              label: 'Início',
            ),
            NavigationDestination(
              icon: Icon(Icons.movie_outlined, color: AppTheme.textSecondary),
              selectedIcon: Icon(Icons.movie_rounded, color: AppTheme.primary),
              label: 'Filmes',
            ),
            NavigationDestination(
              icon: Icon(Icons.tv_outlined, color: AppTheme.textSecondary),
              selectedIcon: Icon(Icons.tv_rounded, color: AppTheme.primary),
              label: 'Séries',
            ),
            NavigationDestination(
              icon: Icon(Icons.spa_outlined, color: AppTheme.textSecondary),
              selectedIcon: Icon(Icons.spa_rounded, color: AppTheme.primary),
              label: 'Doramas',
            ),
            NavigationDestination(
              icon: Icon(Icons.bolt_outlined, color: AppTheme.textSecondary),
              selectedIcon: Icon(Icons.bolt_rounded, color: AppTheme.primary),
              label: 'Animes',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 230,
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo da Aplicação
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'MovieEasy',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Streaming & Torrents',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 12),

          // Itens de Navegação
          _buildSidebarItem(0, Icons.home_rounded, 'Início'),
          _buildSidebarItem(1, Icons.movie_rounded, 'Filmes'),
          _buildSidebarItem(2, Icons.tv_rounded, 'Séries'),
          _buildSidebarItem(3, Icons.spa_rounded, 'Doramas'),
          _buildSidebarItem(4, Icons.bolt_rounded, 'Animes'),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Divider(color: AppTheme.border, height: 1),
          ),

          _buildSidebarItem(5, Icons.search_rounded, 'Buscar'),
          _buildSidebarItem(6, Icons.settings_rounded, 'Configurações'),

          const Spacer(),

          // Indicador de Status das Fontes
          Padding(
            padding: const EdgeInsets.all(18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.badgeGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Fontes Conectadas',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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

  Widget _buildSidebarItem(int index, IconData icon, String title) {
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _currentIndex = index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
