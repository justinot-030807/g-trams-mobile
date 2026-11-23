import 'package:flutter_test/flutter_test.dart';
import 'package:gtrams_mobile/core/config/app_config.dart';
import 'package:gtrams_mobile/core/constants/gasan_constants.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';

void main() {
  group('Gasan Jurisdiction & TODA Directory Parity', () {
    test('contains all 25 official Gasan barangays with valid zone mappings', () {
      expect(GasanConstants.barangays.length, 25);
      for (final brgy in GasanConstants.barangays) {
        final zone = GasanConstants.getZoneForBarangay(brgy);
        expect(
          ['Central', 'North', 'South'],
          contains(zone),
          reason: 'Expected valid zone for $brgy',
        );
      }
    });

    test('resolves common barangay aliases accurately', () {
      expect(GasanConstants.getZoneForBarangay('Brgy. I'), 'Central');
      expect(GasanConstants.getZoneForBarangay('Mat. Gasan'), 'South');
      expect(GasanConstants.getZoneForBarangay('Bangbang, Gasan'), 'North');
    });

    test('filters accredited TODAs by barangay and excludes NON-TODA', () {
      final pobTodas = GasanConstants.getTodasForBarangay('Barangay I (Poblacion)')
          .map((t) => t.id)
          .toList();
      expect(pobTodas, containsAll(['BATODA', 'POB TODA', 'GASAN CENTRAL TODA']));
      expect(pobTodas, isNot(contains('NON-TODA')));

      final tiguionTodas =
          GasanConstants.getTodasForBarangay('Tiguion').map((t) => t.id).toList();
      expect(tiguionTodas, containsAll(['TAB TODA', 'TIGUION TODA']));
    });
  });

  group('Mobile Role Guard & OVM Naming Invariant', () {
    test('admits only operator and toda_president roles', () {
      expect(GasanConstants.isAllowedMobileRole('operator'), isTrue);
      expect(GasanConstants.isAllowedMobileRole('toda_president'), isTrue);
      expect(GasanConstants.isAllowedMobileRole('toda president'), isTrue);
      expect(GasanConstants.isTodaPresidentRole('toda president'), isTrue);
    });

    test('blocks all municipal office, cashier, and system admin roles', () {
      for (final blocked in [
        'bplo_staff',
        'bplo staff',
        'cashier',
        'system_admin',
        'system admin',
        'admin',
        'administrator',
      ]) {
        expect(
          GasanConstants.isAllowedMobileRole(blocked),
          isFalse,
          reason: '$blocked must be blocked on mobile APK',
        );
      }
    });

    test('never exposes legacy BPLO label in blocked role display names', () {
      final display = GasanConstants.blockedRoleDisplayName('bplo_staff');
      expect(display.toUpperCase(), isNot(contains('BPLO')));
      expect(display, contains('OVM'));
      expect(display, contains('LLSA I'));
    });
  });

  group('Contact, Password, and API Config Validators', () {
    test('validates email and PH mobile formats', () {
      expect(GasanConstants.isValidContact('operator.tester@gtrams.com'), isTrue);
      expect(GasanConstants.isValidContact('09222222222'), isTrue);
      expect(GasanConstants.isValidContact('+639222222222'), isTrue);
      expect(GasanConstants.isValidContact('0922-222-2222'), isTrue);
      expect(GasanConstants.isValidContact('12345'), isFalse);
      expect(GasanConstants.isValidContact('not-an-email'), isFalse);
    });

    test('enforces all 5 password complexity rules', () {
      expect(GasanConstants.isPasswordQualified('Password123!'), isTrue);
      expect(GasanConstants.isPasswordQualified('password123!'), isFalse);
      expect(GasanConstants.isPasswordQualified('PASSWORD123!'), isFalse);
      expect(GasanConstants.isPasswordQualified('Password!'), isFalse);
      expect(GasanConstants.isPasswordQualified('Password123'), isFalse);
      expect(GasanConstants.isPasswordQualified('Pa1!'), isFalse);
    });

    test('points directly to Render production backend without workers.dev', () {
      expect(AppConfig.apiOrigin, isNot(contains('workers.dev')));
      expect(AppConfig.apiBaseUrl, endsWith('/api/v1'));
    });

    test('parses MobileUser and PortalSettings payloads cleanly', () {
      final user = MobileUser.fromJson({
        'user': {
          '_id': 'u1',
          'name': 'Juan Dela Cruz',
          'role': 'toda president',
          'todaAssociation': 'POB TODA',
          'bodyNumber': '007',
        },
      });
      expect(user.isTodaPresident, isTrue);
      expect(user.isAllowedMobileUser, isTrue);
      expect(user.roleDisplayTitle, 'TODA President');

      final settings = PortalSettings.fromJson({
        'data': {
          'maintenanceMode': false,
          'franchiseFee': 500,
          'maxUnitsPerOperator': 2,
          'renewalReminderDays': 60,
        },
      });
      expect(settings.maxUnitsPerOperator, 2);
      expect(settings.franchiseFee, 500);
    });
  });
}
