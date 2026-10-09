import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../core/theme/app_theme.dart';

/// Barra de título personalizada para desktop (Windows, Linux, macOS).
/// Contém apenas a área de arraste da janela e os controles nativos (minimizar, maximizar, fechar).
class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      _checkMaximized();
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<void> _checkMaximized() async {
    try {
      final isMax = await windowManager.isMaximized();
      if (mounted) setState(() => _isMaximized = isMax);
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Área arrastável por toda a extensão da barra (duplo clique para maximizar/restaurar)
          Expanded(
            child: DragToMoveArea(
              child: GestureDetector(
                onDoubleTap: () async {
                  if (_isMaximized) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),

          // Lado Direito: Botões de Controle da Janela (Minimizar, Maximizar/Restaurar, Fechar)
          _buildWindowButton(
            icon: Icons.remove_rounded,
            tooltip: 'Minimizar',
            onTap: () => windowManager.minimize(),
          ),
          _buildWindowButton(
            icon: _isMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
            iconSize: _isMaximized ? 12 : 14,
            tooltip: _isMaximized ? 'Restaurar' : 'Maximizar',
            onTap: () async {
              if (_isMaximized) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _buildWindowButton(
            icon: Icons.close_rounded,
            isCloseButton: true,
            tooltip: 'Fechar',
            onTap: () => windowManager.close(),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    double iconSize = 15,
    bool isCloseButton = false,
  }) {
    return _WindowControlButton(
      icon: icon,
      onTap: onTap,
      tooltip: tooltip,
      iconSize: iconSize,
      isCloseButton: isCloseButton,
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double iconSize;
  final bool isCloseButton;

  const _WindowControlButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.iconSize = 15,
    this.isCloseButton = false,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color iconColor = AppTheme.textSecondary;

    if (_isHovered) {
      if (widget.isCloseButton) {
        bg = Colors.redAccent;
        iconColor = Colors.white;
      } else {
        bg = Colors.white.withOpacity(0.08);
        iconColor = AppTheme.textPrimary;
      }
    }

    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 46,
          height: 32,
          color: bg,
          child: Center(
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: iconColor,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 600),
        child: button,
      );
    }
    return button;
  }
}
