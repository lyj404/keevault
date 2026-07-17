import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/features/totp/data/totp_service.dart';

void main() {
  group('TotpService URI parsing', () {
    test('extracts account name and issuer for a scanned URI', () {
      final config = TotpService().parseUri(
        'otpauth://totp/GitHub:alice%40example.com'
        '?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
      );

      expect(config, isNotNull);
      expect(config!.accountName, 'alice@example.com');
      expect(config.issuer, 'GitHub');
      expect(config.secret, 'JBSWY3DPEHPK3PXP');
    });

    test('uses the label as account name when it has no issuer prefix', () {
      final config = TotpService().parseUri(
        'otpauth://totp/alice%40example.com?secret=JBSWY3DPEHPK3PXP',
      );

      expect(config, isNotNull);
      expect(config!.accountName, 'alice@example.com');
    });
  });
}