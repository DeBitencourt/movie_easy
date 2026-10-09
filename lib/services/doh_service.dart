import 'dart:convert';
import 'dart:io';

/// Serviço responsável por resolver DNS via HTTPS (DoH),
/// contornando bloqueios de operadoras de internet e redes restritas.
class DohService {
  static final Map<String, String> _ipCache = {};

  /// Resolve o domínio para um endereço IPv4 usando Cloudflare (1.1.1.1) ou Google (8.8.8.8).
  static Future<String?> resolve(String host) async {
    // 1. Tentar DNS do sistema primeiro
    try {
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isNotEmpty) {
        return addresses.first.address;
      }
    } catch (_) {
      // Falha no DNS local (esperado em redes restritas ou com bloqueio)
    }

    // 2. Verificar cache em memória
    if (_ipCache.containsKey(host)) {
      return _ipCache[host];
    }

    // 3. Tentar Cloudflare DoH (1.1.1.1)
    try {
      final client = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final uri = Uri.parse('https://1.1.1.1/dns-query?name=$host&type=A');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/dns-json');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final answers = json['Answer'] as List<dynamic>?;
        if (answers != null && answers.isNotEmpty) {
          for (final ans in answers) {
            if (ans['type'] == 1 && ans['data'] != null) {
              final ip = ans['data'] as String;
              _ipCache[host] = ip;
              client.close(force: true);
              return ip;
            }
          }
        }
      }
      client.close(force: true);
    } catch (_) {}

    // 4. Fallback: Google DoH (8.8.8.8)
    try {
      final client = HttpClient()..badCertificateCallback = ((cert, host, port) => true);
      final uri = Uri.parse('https://8.8.8.8/resolve?name=$host&type=A');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final answers = json['Answer'] as List<dynamic>?;
        if (answers != null && answers.isNotEmpty) {
          for (final ans in answers) {
            if (ans['type'] == 1 && ans['data'] != null) {
              final ip = ans['data'] as String;
              _ipCache[host] = ip;
              client.close(force: true);
              return ip;
            }
          }
        }
      }
      client.close(force: true);
    } catch (_) {}

    return null;
  }

  /// Cria um [HttpClient] configurado com suporte a DoH e SNI automático.
  static HttpClient createHttpClient() {
    final client = HttpClient();
    client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
      final resolvedIp = await resolve(uri.host);
      final connectTarget = resolvedIp ?? uri.host;
      final socket = await Socket.connect(connectTarget, uri.port);
      if (uri.scheme == 'https') {
        final secureSocket = await SecureSocket.secure(
          socket,
          host: uri.host, // Preserva o hostname no SNI para o Cloudflare
        );
        return ConnectionTask.fromSocket(
          Future.value(secureSocket),
          () {},
        );
      }
      return ConnectionTask.fromSocket(
        Future.value(socket),
        () {},
      );
    };
    return client;
  }

  /// Realiza uma requisição GET retornando o corpo HTML decodificado.
  static Future<String> getHtml(String url) async {
    final client = createHttpClient();
    try {
      final uri = Uri.parse(url);
      final req = await client.getUrl(uri);
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      req.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      req.headers.set('Accept-Language', 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7');

      final resp = await req.close();
      if (resp.statusCode != 200 && resp.statusCode != 301 && resp.statusCode != 302) {
        throw HttpException('Status ${resp.statusCode}', uri: uri);
      }

      // Redirecionamento se necessário
      if (resp.statusCode == 301 || resp.statusCode == 302) {
        final redirectLocation = resp.headers.value('location');
        if (redirectLocation != null) {
          return await getHtml(redirectLocation);
        }
      }

      return await resp.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }
}
