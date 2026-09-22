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

    test('normalization is case insensitive and availability rules are shared', () {
      expect(UsernameValidation.normalize('  Lord  '), 'lord');
      expect(UsernameValidation.normalize('LORD123'), 'lord123');
      expect(UsernameValidation.isValid(UsernameValidation.normalize('Lord_123')), isTrue);
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
        AppwriteException('duplicate', 409),
        registering: true,
      );
      expect(message, contains('البريد الإلكتروني مستخدم بالفعل'));
    });

    test('maps Facebook OAuth cancellation and network failures', () {
      expect(
        authErrorMessage(const FacebookAuthException('CANCELLED'), registering: false),
        contains('تم إلغاء تسجيل الدخول باستخدام Facebook'),
      );
      expect(
        authErrorMessage(const FacebookAuthException('NETWORK'), registering: false),
        contains('تعذر الاتصال بخدمة Facebook'),
      );
    });
  });
}
