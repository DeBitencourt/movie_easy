import 'package:flutter_test/flutter_test.dart';
import 'package:movie_easy/services/screen_keep_alive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ScreenKeepAliveService enable and disable cycle', () async {
    final service = ScreenKeepAliveService.instance;
    expect(service.isActive, isFalse);

    await service.enable();
    expect(service.isActive, isTrue);

    // Multiple enables should be idempotent
    await service.enable();
    expect(service.isActive, isTrue);

    await service.disable();
    expect(service.isActive, isFalse);

    // Multiple disables should be idempotent
    await service.disable();
    expect(service.isActive, isFalse);
  });
}
