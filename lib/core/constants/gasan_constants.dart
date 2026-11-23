/// Official Municipality of Gasan (Marinduque) Barangays, Zones, TODA Directory,
/// Role Guards, Contact Validators, and Password Rules.
///
/// 1:1 parity with G-TRAMS backend & web constants.
library;

class TodaEntry {
  const TodaEntry({
    required this.id,
    required this.name,
    required this.zone,
    required this.terminal,
    required this.barangays,
    required this.description,
  });

  final String id;
  final String name;
  final String zone;
  final String terminal;
  final List<String> barangays;
  final String description;
}

class PasswordRuleCheck {
  const PasswordRuleCheck({
    required this.id,
    required this.labelEn,
    required this.labelFil,
    required this.met,
  });

  final String id;
  final String labelEn;
  final String labelFil;
  final bool met;
}

class GasanConstants {
  GasanConstants._();

  static const String municipalityName = 'Municipality of Gasan, Marinduque';
  static const String licensingOfficeName =
      'Office of the Municipal Vice Mayor (OVM) — LLSA I';
  static const String municipalSignatory = 'HON. LIDANY A. LAO-BALDO';

  /// Official 25 Barangays of Gasan, Marinduque.
  static const List<String> barangays = [
    'Antipolo',
    'Bachao Ibaba',
    'Bachao Ilaya',
    'Bacong-Bacong',
    'Bahi',
    'Bangbang',
    'Banot',
    'Banuyo',
    'Barangay I (Poblacion)',
    'Barangay II (Poblacion)',
    'Barangay III (Poblacion)',
    'Bognuyan',
    'Cabugao',
    'Dawis',
    'Dili',
    'Libtangin',
    'Mahunig',
    'Mangiliol',
    'Masiga',
    'Matandang Gasan',
    'Pangi',
    'Pinggan',
    'Tabionan',
    'Tapuyan',
    'Tiguion',
  ];

  /// Official Barangay-to-Zone mapping (Central, North, South).
  static const Map<String, String> barangayToZone = {
    'Barangay I (Poblacion)': 'Central',
    'Barangay II (Poblacion)': 'Central',
    'Barangay III (Poblacion)': 'Central',
    'Bahi': 'North',
    'Bangbang': 'North',
    'Cabugao': 'North',
    'Mangiliol': 'North',
    'Masiga': 'North',
    'Tapuyan': 'North',
    'Tiguion': 'North',
    'Antipolo': 'South',
    'Bachao Ibaba': 'South',
    'Bachao Ilaya': 'South',
    'Bacong-Bacong': 'South',
    'Banot': 'South',
    'Banuyo': 'South',
    'Bognuyan': 'South',
    'Dawis': 'South',
    'Dili': 'South',
    'Libtangin': 'South',
    'Mahunig': 'South',
    'Matandang Gasan': 'South',
    'Pangi': 'South',
    'Pinggan': 'South',
    'Tabionan': 'South',
  };

  /// Official Gasan Accredited TODA Directory.
  static const List<TodaEntry> todaDirectory = [
    TodaEntry(
      id: 'BATODA',
      name: 'BATODA (Bachao TODA)',
      zone: 'South',
      terminal: 'Bachao Ibaba Junction / Poblacion Market',
      barangays: [
        'Bachao Ibaba',
        'Bachao Ilaya',
        'Antipolo',
        'Barangay I (Poblacion)',
      ],
      description:
          'Servicing Bachao coastal and interior routes connecting to Gasan Public Market.',
    ),
    TodaEntry(
      id: 'POB TODA',
      name: 'POB TODA (Poblacion Central)',
      zone: 'Central',
      terminal: 'Gasan Municipal Plaza / Town Terminal',
      barangays: [
        'Barangay I (Poblacion)',
        'Barangay II (Poblacion)',
        'Barangay III (Poblacion)',
      ],
      description:
          'Town proper internal loop connecting municipal hall, market, schools, and banks.',
    ),
    TodaEntry(
      id: 'GT TODA',
      name: 'GT TODA (Gasan-Tapuyan)',
      zone: 'North',
      terminal: 'Tapuyan Crossing / Highway Outpost',
      barangays: [
        'Tapuyan',
        'Dili',
        'Libtangin',
        'Barangay II (Poblacion)',
      ],
      description:
          'Main highway arterial route connecting northern coastal barangays to downtown Gasan.',
    ),
    TodaEntry(
      id: 'LUG TODA',
      name: 'LUG TODA (Libtangin Transport)',
      zone: 'South',
      terminal: 'Libtangin Barangay Outpost',
      barangays: ['Libtangin', 'Dili'],
      description:
          'Local passenger transit covering Libtangin community routes.',
    ),
    TodaEntry(
      id: 'NBI TODA',
      name: 'NBI TODA (North Bay Interstate)',
      zone: 'South',
      terminal: 'Bognuyan Port Terminal',
      barangays: ['Bognuyan', 'Cabugao', 'Dawis', 'Mangiliol'],
      description:
          'Port and coastal connectivity covering fishing and agricultural communities.',
    ),
    TodaEntry(
      id: 'BANGBANG IPIL TODA',
      name: 'BANGBANG IPIL TODA',
      zone: 'North',
      terminal: 'Bangbang Barangay Hall Outpost',
      barangays: ['Bangbang', 'Banot', 'Banuyo', 'Pangi'],
      description:
          'Vital farm-to-market interior feeder route across upland barangays.',
    ),
    TodaEntry(
      id: 'TAB TODA',
      name: 'TAB TODA (Tabionan Transport)',
      zone: 'South',
      terminal: 'Tabionan Junction Terminal',
      barangays: ['Tabionan', 'Tiguion', 'Masiga', 'Matandang Gasan'],
      description:
          'Southern mountain perimeter connection transporting local residents.',
    ),
    TodaEntry(
      id: 'TIGUION TODA',
      name: 'TIGUION TODA',
      zone: 'North',
      terminal: 'Tiguion Proper Terminal',
      barangays: ['Tiguion'],
      description: 'Northern upland commuter route connecting Tiguion.',
    ),
    TodaEntry(
      id: 'MASIGA TODA',
      name: 'MASIGA TODA',
      zone: 'North',
      terminal: 'Masiga Crossing Outpost',
      barangays: ['Masiga'],
      description: 'Dedicated agricultural route serving Masiga residents.',
    ),
    TodaEntry(
      id: 'MAT TODA',
      name: 'MAT TODA (Matandang Gasan)',
      zone: 'South',
      terminal: 'Matandang Gasan Outpost',
      barangays: ['Matandang Gasan'],
      description: 'Southern coastal transit serving Matandang Gasan.',
    ),
    TodaEntry(
      id: 'PG TODA',
      name: 'PG TODA (Pinggan)',
      zone: 'South',
      terminal: 'Pinggan Seashore Terminal',
      barangays: ['Pinggan'],
      description: 'Coastal shoreline transport for Pinggan residents.',
    ),
    TodaEntry(
      id: '4B TODA',
      name: '4B TODA',
      zone: 'North',
      terminal: 'Northern Four Barangays Crossing',
      barangays: ['Bahi', 'Bangbang', 'Banot', 'Banuyo'],
      description:
          'Inter-barangay commuter loop across Bahi, Bangbang, Banot, and Banuyo.',
    ),
    TodaEntry(
      id: 'DPAB TODA',
      name: 'DPAB TODA',
      zone: 'South',
      terminal: 'South Quadrant Junction',
      barangays: ['Dawis', 'Pangi', 'Antipolo', 'Bognuyan'],
      description:
          'Southern transport network connecting Dawis, Pangi, Antipolo, and Bognuyan.',
    ),
    TodaEntry(
      id: 'ILAYA TODA',
      name: 'ILAYA TODA',
      zone: 'South',
      terminal: 'Bachao Ilaya Terminal',
      barangays: ['Bachao Ilaya'],
      description: 'Interior riverway route serving Bachao Ilaya.',
    ),
    TodaEntry(
      id: 'GASAN CENTRAL TODA',
      name: 'GASAN CENTRAL TODA',
      zone: 'Central',
      terminal: 'Gasan Central Integrated Terminal',
      barangays: [
        'Barangay I (Poblacion)',
        'Barangay II (Poblacion)',
        'Barangay III (Poblacion)',
        'Mahunig',
      ],
      description:
          'Inter-barangay shuttle terminal servicing general public passenger transit.',
    ),
    TodaEntry(
      id: 'BAHI TODA',
      name: 'BAHI TODA',
      zone: 'North',
      terminal: 'Bahi Seashore Terminal',
      barangays: ['Bahi', 'Pinggan', 'Bacong-Bacong'],
      description:
          'Coastal shoreline route linking shoreline barangays to downtown markets.',
    ),
    TodaEntry(
      id: 'NON-TODA',
      name: 'NON-TODA (Independent Franchise)',
      zone: 'All Authorized Municipal Routes',
      terminal: 'Operator Residence Base',
      barangays: ['All Gasan Barangays'],
      description:
          'Independent operators authorized within their designated residency zone.',
    ),
  ];

  static String _stripBarangayAffixes(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r',\s*gasan.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r',\s*marinduque.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'^(?:barangay|brgy\.?)\s+', caseSensitive: false), '')
        .trim();
  }

  /// Resolves official municipal zone (`Central`, `North`, `South`) from a Barangay name.
  static String getZoneForBarangay(String? barangayName) {
    if (barangayName == null || barangayName.trim().isEmpty) return '';
    final clean = barangayName.trim();
    if (barangayToZone.containsKey(clean)) return barangayToZone[clean]!;

    final lower = clean.toLowerCase();
    final stripped = _stripBarangayAffixes(clean).toLowerCase();

    final sortedEntries = barangayToZone.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in sortedEntries) {
      final keyLower = entry.key.toLowerCase();
      if (keyLower == lower || (stripped.isNotEmpty && keyLower == stripped)) {
        return entry.value;
      }
    }

    if (lower.contains('uno') ||
        lower == 'brgy. i' ||
        lower == 'brgy i' ||
        stripped == 'i' ||
        lower.contains('poblacion')) {
      return 'Central';
    }
    if (lower.contains('dos') ||
        lower == 'brgy. ii' ||
        lower == 'brgy ii' ||
        stripped == 'ii') {
      return 'Central';
    }
    if (lower.contains('tres') ||
        lower == 'brgy. iii' ||
        lower == 'brgy iii' ||
        stripped == 'iii') {
      return 'Central';
    }
    if (lower.contains('bacong') ||
        lower.contains('ping') ||
        lower.contains('tabionan') ||
        (lower.contains('mat') && lower.contains('gasan'))) {
      return 'South';
    }
    if (lower.contains('bahi') || lower.contains('bangbang')) {
      return 'North';
    }

    for (final entry in sortedEntries) {
      final bStripped = _stripBarangayAffixes(entry.key).toLowerCase();
      if (bStripped.isNotEmpty &&
          (lower.contains(bStripped) || stripped.contains(bStripped))) {
        return entry.value;
      }
    }
    return '';
  }

  /// Filters accredited TODAs by the operator's Barangay of residence.
  static List<TodaEntry> getTodasForBarangay(String? barangayName) {
    if (barangayName == null || barangayName.trim().isEmpty) return const [];
    final clean = barangayName.trim().toLowerCase();

    final direct = todaDirectory
        .where(
          (t) =>
              t.id != 'NON-TODA' &&
              t.barangays.any((b) => b.toLowerCase() == clean),
        )
        .toList();
    if (direct.isNotEmpty) return direct;

    final zone = getZoneForBarangay(barangayName);
    if (zone.isNotEmpty) {
      final zoneMatches = todaDirectory
          .where(
            (t) =>
                t.id != 'NON-TODA' &&
                t.zone.toLowerCase().contains(zone.toLowerCase()),
          )
          .toList();
      if (zoneMatches.isNotEmpty) return zoneMatches;
    }

    return todaDirectory.where((t) => t.id != 'NON-TODA').toList();
  }

  static TodaEntry? findTodaById(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    final clean = id.trim().toLowerCase();
    for (final entry in todaDirectory) {
      if (entry.id.toLowerCase() == clean ||
          entry.name.toLowerCase() == clean) {
        return entry;
      }
    }
    return null;
  }

  /// Normalizes backend roles into canonical snake_case tokens.
  static String normalizeRole(String? rawRole) {
    return (rawRole ?? '')
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[\s-]+'), '_');
  }

  /// Strict Mobile APK Role Guard: ONLY `operator` and `toda_president` may sign in.
  static bool isAllowedMobileRole(String? rawRole) {
    final normalized = normalizeRole(rawRole);
    return normalized == 'operator' || normalized == 'toda_president';
  }

  static bool isTodaPresidentRole(String? rawRole) {
    return normalizeRole(rawRole) == 'toda_president';
  }

  /// Human-readable civic title for blocked staff roles (never exposes "BPLO").
  static String blockedRoleDisplayName(String? rawRole) {
    final normalized = normalizeRole(rawRole);
    switch (normalized) {
      case 'bplo_staff':
        return 'OVM / LLSA I Licensing Officer';
      case 'cashier':
        return 'Municipal Cashier / Treasury';
      case 'system_admin':
      case 'admin':
      case 'administrator':
        return 'System Administrator';
      default:
        return 'Municipal Staff';
    }
  }

  /// Validates email format.
  static bool isValidEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmed);
  }

  /// Validates Philippine mobile format (`09...`, `+639...`, `639...`).
  static bool isValidPhMobile(String value) {
    final digits = value.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.isEmpty) return false;
    return RegExp(r'^(09|\+639|639)\d{9}$').hasMatch(digits);
  }

  /// Validates email or Philippine mobile format (`09...`, `+639...`, `639...`).
  static bool isValidContact(String value) {
    return isValidEmail(value) || isValidPhMobile(value);
  }

  /// Canonicalizes email (lowercase) or phone number (stripped spaces/dashes).
  static String canonicalizeContact(String value) {
    final trimmed = value.trim();
    if (trimmed.contains('@')) return trimmed.toLowerCase();
    return trimmed.replaceAll(RegExp(r'[\s\-()]'), '');
  }

  /// Evaluates the 5 G-TRAMS password complexity requirements.
  static List<PasswordRuleCheck> evaluatePasswordRules(String password) {
    return [
      PasswordRuleCheck(
        id: 'length',
        labelEn: 'At least 8 characters',
        labelFil: 'Hindi bababa sa 8 karakter',
        met: password.length >= 8,
      ),
      PasswordRuleCheck(
        id: 'upper',
        labelEn: 'At least 1 uppercase letter (A-Z)',
        labelFil: 'May 1 malaking titik (A-Z)',
        met: RegExp(r'[A-Z]').hasMatch(password),
      ),
      PasswordRuleCheck(
        id: 'lower',
        labelEn: 'At least 1 lowercase letter (a-z)',
        labelFil: 'May 1 maliit na titik (a-z)',
        met: RegExp(r'[a-z]').hasMatch(password),
      ),
      PasswordRuleCheck(
        id: 'number',
        labelEn: 'At least 1 number (0-9)',
        labelFil: 'May 1 numero (0-9)',
        met: RegExp(r'[0-9]').hasMatch(password),
      ),
      PasswordRuleCheck(
        id: 'special',
        labelEn: 'At least 1 special symbol (!@#\$%^&*)',
        labelFil: 'May 1 espesyal na simbolo (!@#\$%^&*)',
        met: RegExp(r'[^A-Za-z0-9]').hasMatch(password),
      ),
    ];
  }

  static bool isPasswordQualified(String password) {
    return evaluatePasswordRules(password).every((rule) => rule.met);
  }
}
