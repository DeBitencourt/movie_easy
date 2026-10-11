import 'dart:async';
import 'dart:io';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Serviço robusto multiplataforma para impedir suspensão, hibernação
/// e desligamento/bloqueio de tela durante a reprodução de vídeos.
///
/// No Linux (GNOME, KDE, XFCE, Wayland e X11), o wakelock padrão costuma falhar
/// devido à ausência de integração com o D-Bus do desktop. Este serviço se comunica
/// diretamente com as interfaces de inibição do sistema (`org.freedesktop.ScreenSaver`,
/// `org.gnome.SessionManager` e `org.freedesktop.portal.Inhibit`), além de manter um
/// batimento periódico de atividade para garantir que a tela jamais apague.
class ScreenKeepAliveService {
  static final ScreenKeepAliveService instance = ScreenKeepAliveService._internal();
  factory ScreenKeepAliveService() => instance;
  ScreenKeepAliveService._internal();

  bool _isActive = false;
  bool get isActive => _isActive;

  // Linux D-Bus handles
  DBusClient? _dbusClient;
  int? _screenSaverCookie;
  int? _gnomeSessionCookie;
  DBusObjectPath? _portalHandle;
  Timer? _heartbeatTimer;

  /// Ativa a inibição de suspensão e bloqueio de tela.
  Future<void> enable() async {
    if (_isActive) return;
    _isActive = true;

    // 1. Ativação via wakelock_plus (Windows, macOS, iOS, Android)
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('[ScreenKeepAlive] WakelockPlus error: $e');
    }

    // 2. No Linux, comunicação direta com D-Bus (GNOME, KDE, Freedesktop, Portals)
    if (!kIsWeb && Platform.isLinux) {
      await _enableLinuxInhibit();
    }
  }

  /// Desativa a inibição de suspensão e retorna o comportamento normal de economia de energia.
  Future<void> disable() async {
    if (!_isActive) return;
    _isActive = false;

    // 1. Cancela timer periódico de atividade no Linux
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    // 2. Libera inibidores D-Bus no Linux
    if (!kIsWeb && Platform.isLinux) {
      await _disableLinuxInhibit();
    }

    // 3. Desativação via wakelock_plus
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('[ScreenKeepAlive] WakelockPlus disable error: $e');
    }
  }

  Future<void> _enableLinuxInhibit() async {
    try {
      _dbusClient ??= DBusClient.session();
      final client = _dbusClient!;

      // A) org.freedesktop.ScreenSaver (Compatível com GNOME, KDE, XFCE, Cinnamon, MATE)
      try {
        final ssObject = DBusRemoteObject(
          client,
          name: 'org.freedesktop.ScreenSaver',
          path: DBusObjectPath('/org/freedesktop/ScreenSaver'),
        );
        final response = await ssObject.callMethod(
          'org.freedesktop.ScreenSaver',
          'Inhibit',
          [
            const DBusString('MovieEasy'),
            const DBusString('Reproduzindo vídeo'),
          ],
          replySignature: DBusSignature('u'),
        );
        _screenSaverCookie = response.returnValues.first.asUint32();
        debugPrint('[ScreenKeepAlive] org.freedesktop.ScreenSaver inibido com sucesso (cookie: $_screenSaverCookie)');
      } catch (e) {
        debugPrint('[ScreenKeepAlive] Falha ao inibir org.freedesktop.ScreenSaver: $e');
      }

      // B) org.gnome.SessionManager (Específico e altamente confiável no GNOME Wayland/X11)
      try {
        final gnomeObject = DBusRemoteObject(
          client,
          name: 'org.gnome.SessionManager',
          path: DBusObjectPath('/org/gnome/SessionManager'),
        );
        // Flags: 4 (Inhibit idle / screensaver) + 8 (Inhibit suspend / sleep) = 12
        final response = await gnomeObject.callMethod(
          'org.gnome.SessionManager',
          'Inhibit',
          [
            const DBusString('MovieEasy'),
            const DBusUint32(0),
            const DBusString('Reproduzindo vídeo'),
            const DBusUint32(12),
          ],
          replySignature: DBusSignature('u'),
        );
        _gnomeSessionCookie = response.returnValues.first.asUint32();
        debugPrint('[ScreenKeepAlive] org.gnome.SessionManager inibido com sucesso (cookie: $_gnomeSessionCookie)');
      } catch (e) {
        debugPrint('[ScreenKeepAlive] Falha ao inibir org.gnome.SessionManager: $e');
      }

      // C) org.freedesktop.portal.Inhibit (XDG Desktop Portal)
      try {
        final portalObject = DBusRemoteObject(
          client,
          name: 'org.freedesktop.portal.Desktop',
          path: DBusObjectPath('/org/freedesktop/portal/desktop'),
        );
        final response = await portalObject.callMethod(
          'org.freedesktop.portal.Inhibit',
          'Inhibit',
          [
            const DBusString(''),
            const DBusUint32(12), // 8 (idle) + 4 (suspend)
            DBusDict.stringVariant({
              'reason': const DBusString('MovieEasy: Reproduzindo vídeo'),
            }),
          ],
          replySignature: DBusSignature('o'),
        );
        _portalHandle = response.returnValues.first.asObjectPath();
        debugPrint('[ScreenKeepAlive] XDG Portal inibido com sucesso (handle: $_portalHandle)');
      } catch (e) {
        debugPrint('[ScreenKeepAlive] Falha ao inibir XDG Portal: $e');
      }

      // D) Batimento periódico (a cada 45 segundos) simulando atividade do usuário para
      // garantir que nenhum protetor de tela ou timer de inatividade apague o monitor.
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        _sendKeepAliveHeartbeat();
      });
    } catch (e) {
      debugPrint('[ScreenKeepAlive] Erro ao configurar inibições D-Bus no Linux: $e');
    }
  }

  void _sendKeepAliveHeartbeat() {
    if (!_isActive || _dbusClient == null) return;
    try {
      final ssObject = DBusRemoteObject(
        _dbusClient!,
        name: 'org.freedesktop.ScreenSaver',
        path: DBusObjectPath('/org/freedesktop/ScreenSaver'),
      );
      ssObject.callMethod(
        'org.freedesktop.ScreenSaver',
        'SimulateUserActivity',
        [],
        replySignature: DBusSignature.empty,
      ).catchError((_) => DBusMethodSuccessResponse([]));
    } catch (_) {}

    try {
      Process.run('xdg-screensaver', ['reset']).catchError((_) => ProcessResult(0, 0, null, null));
    } catch (_) {}
  }

  Future<void> _disableLinuxInhibit() async {
    final client = _dbusClient;
    if (client == null) return;

    if (_screenSaverCookie != null) {
      try {
        final ssObject = DBusRemoteObject(
          client,
          name: 'org.freedesktop.ScreenSaver',
          path: DBusObjectPath('/org/freedesktop/ScreenSaver'),
        );
        await ssObject.callMethod(
          'org.freedesktop.ScreenSaver',
          'UnInhibit',
          [DBusUint32(_screenSaverCookie!)],
          replySignature: DBusSignature.empty,
        );
        debugPrint('[ScreenKeepAlive] ScreenSaver desinibido');
      } catch (e) {
        debugPrint('[ScreenKeepAlive] Erro ao desinibir ScreenSaver: $e');
      }
      _screenSaverCookie = null;
    }

    if (_gnomeSessionCookie != null) {
      try {
        final gnomeObject = DBusRemoteObject(
          client,
          name: 'org.gnome.SessionManager',
          path: DBusObjectPath('/org/gnome/SessionManager'),
        );
        await gnomeObject.callMethod(
          'org.gnome.SessionManager',
          'Uninhibit',
          [DBusUint32(_gnomeSessionCookie!)],
          replySignature: DBusSignature.empty,
        );
        debugPrint('[ScreenKeepAlive] GNOME SessionManager desinibido');
      } catch (e) {
        debugPrint('[ScreenKeepAlive] Erro ao desinibir GNOME SessionManager: $e');
      }
      _gnomeSessionCookie = null;
    }

    if (_portalHandle != null) {
      try {
        final requestObject = DBusRemoteObject(
          client,
          name: 'org.freedesktop.portal.Desktop',
          path: _portalHandle!,
        );
        await requestObject.callMethod(
          'org.freedesktop.portal.Request',
          'Close',
          [],
          replySignature: DBusSignature.empty,
        );
        debugPrint('[ScreenKeepAlive] XDG Portal desinibido');
      } catch (e) {
        debugPrint('[ScreenKeepAlive] Erro ao fechar handle XDG Portal: $e');
      }
      _portalHandle = null;
    }

    try {
      await client.close();
    } catch (_) {}
    _dbusClient = null;
  }
}
