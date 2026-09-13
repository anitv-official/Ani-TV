import 'package:flutter_test/flutter_test.dart';
import 'package:appwrite/appwrite.dart';
import 'package:anitv/services/appwrite_service.dart';

void main() {
  group('UsernameValidation', () {
    test('normalizes valid usernames', () {
      expect(UsernameValidation.normalize('  Ani_TV  '), 'ani_tv');
      expect(UsernameValidation.isValid('ani_tv'), isTrue);
    });

    test('rejects invalid usernames', () {
      expect(UsernameValidation.isValid('ab'), isFalse);
      expect(UsernameValidation.isValid('اسم'), isFalse);
      expect(UsernameValidation.isValid('ani-tv'), isFalse);
    });
  });

  group('authErrorMessage', () {
    test('keeps account-created session failures distinct', () {
      final message = authErrorMessage(
        const AccountCreatedButSessionUnavailableException('session failed'),
        registering: true,
      );
      expect(message, contains('تم إنشاء الحساب'));
      expect(message, contains('سجّل الدخول'));
    });

    test('maps duplicate email to a clear registration message', () {
      final message = authErrorMessage(
        AppwriteException('duplicate', code: 409),
        registering: true,
      );
      expect(message, contains('البريد الإلكتروني مستخدم بالفعل'));
    });
  });
}
