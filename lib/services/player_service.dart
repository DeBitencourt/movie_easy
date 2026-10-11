import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'screen_keep_alive_service.dart';

/// Serviço singleton gerenciador do Player e VideoController da aplicação.
/// 
/// Manter uma única instância viva previne que o libmpv e o renderizador OpenGL/EGL
/// do Linux sejam destruídos durante a navegação entre telas, o que causava segfaults
/// e o fechamento inesperado do aplicativo ao sair do player no Linux.
class PlayerService {
  static final PlayerService instance = PlayerService._internal();
  factory PlayerService() => instance;
  PlayerService._internal();

  Player? _player;
  VideoController? _controller;

  Player get player {
    _player ??= Player();
    return _player!;
  }

  VideoController get controller {
    _controller ??= VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    return _controller!;
  }

  /// Para a reprodução atual sem destruir a instância nativa do libmpv / texturas OpenGL.
  Future<void> stop() async {
    try {
      await ScreenKeepAliveService.instance.disable();
      if (_player != null) {
        await _player!.stop();
      }
    } catch (_) {}
  }
}
