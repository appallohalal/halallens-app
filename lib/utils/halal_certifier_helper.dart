class KnownCertifierInfo {
  final String id;
  final String name;
  final String shortName;
  final String country;
  final List<String> keywords;

  const KnownCertifierInfo({
    required this.id,
    required this.name,
    required this.shortName,
    required this.country,
    required this.keywords,
  });
}

class HalalCertifierHelper {
  HalalCertifierHelper._();

  static const List<KnownCertifierInfo> knownCertifiers = [
    KnownCertifierInfo(
      id: 'avs',
      name: 'AVS (À Votre Service)',
      shortName: 'AVS',
      country: 'France',
      keywords: ['avs', 'a.v.s', 'à votre service', 'a votre service'],
    ),
    KnownCertifierInfo(
      id: 'achahada',
      name: 'Achahada',
      shortName: 'Achahada',
      country: 'France',
      keywords: ['achahada', 'chahada', 'ach-chahada'],
    ),
    KnownCertifierInfo(
      id: 'argml',
      name: 'ARGML (Grande Mosquée de Lyon)',
      shortName: 'ARGML (Lyon)',
      country: 'France',
      keywords: [
        'argml',
        'mosquée de lyon',
        'mosquee de lyon',
        'grande mosquée de lyon',
        'isla delice',
        'isla délice',
      ],
    ),
    KnownCertifierInfo(
      id: 'sfcvh',
      name: 'SFCVH (Grande Mosquée de Paris)',
      shortName: 'Mosquée de Paris',
      country: 'France',
      keywords: [
        'sfcvh',
        'mosquée de paris',
        'mosquee de paris',
        'grande mosquée de paris',
      ],
    ),
    KnownCertifierInfo(
      id: 'halal_services',
      name: 'Halal Services',
      shortName: 'Halal Services',
      country: 'France',
      keywords: ['halal services', 'halalservices'],
    ),
    KnownCertifierInfo(
      id: 'halal_correct',
      name: 'Halal Correct (TQ HC)',
      shortName: 'Halal Correct',
      country: 'Netherlands / EU',
      keywords: ['halal correct', 'total quality halal correct', 'tq hc'],
    ),
    KnownCertifierInfo(
      id: 'halal_control',
      name: 'Halal Control',
      shortName: 'Halal Control',
      country: 'Germany / EU',
      keywords: ['halal control', 'halalcontrol'],
    ),
    KnownCertifierInfo(
      id: 'hmc',
      name: 'HMC (Halal Monitoring Committee)',
      shortName: 'HMC',
      country: 'United Kingdom',
      keywords: ['hmc', 'halal monitoring committee'],
    ),
    KnownCertifierInfo(
      id: 'hfa',
      name: 'HFA (Halal Food Authority)',
      shortName: 'HFA',
      country: 'United Kingdom',
      keywords: ['hfa', 'halal food authority'],
    ),
    KnownCertifierInfo(
      id: 'jakim',
      name: 'JAKIM',
      shortName: 'JAKIM',
      country: 'Malaysia',
      keywords: ['jakim', 'halal malaysia'],
    ),
    KnownCertifierInfo(
      id: 'mui_bpjph',
      name: 'MUI / BPJPH',
      shortName: 'MUI / BPJPH',
      country: 'Indonesia',
      keywords: ['mui', 'bpjph', 'majelis ulama indonesia', 'halal indonesia'],
    ),
    KnownCertifierInfo(
      id: 'muis',
      name: 'MUIS',
      shortName: 'MUIS',
      country: 'Singapore',
      keywords: ['muis'],
    ),
    KnownCertifierInfo(
      id: 'cicot',
      name: 'CICOT',
      shortName: 'CICOT',
      country: 'Thailand',
      keywords: ['cicot'],
    ),
    KnownCertifierInfo(
      id: 'euro_halal',
      name: 'Euro Halal',
      shortName: 'Euro Halal',
      country: 'Europe',
      keywords: ['euro halal', 'eurohalal'],
    ),
    KnownCertifierInfo(
      id: 'echada',
      name: 'Echada',
      shortName: 'Echada',
      country: 'France',
      keywords: ['echada'],
    ),
  ];

  /// Detects whether any known certification body is present in the product's
  /// labels, tags, ingredients, or brand text.
  static String? detectCertifier({
    List<String>? labels,
    String? name,
    String? brand,
    String? ingredients,
  }) {
    final buffer = StringBuffer();
    if (labels != null) {
      for (final l in labels) {
        buffer.write('${l.toLowerCase()} ');
      }
    }
    if (name != null) buffer.write('${name.toLowerCase()} ');
    if (brand != null) buffer.write('${brand.toLowerCase()} ');
    if (ingredients != null) buffer.write('${ingredients.toLowerCase()} ');

    final fullText = buffer.toString();
    if (fullText.trim().isEmpty) return null;

    for (final cert in knownCertifiers) {
      for (final kw in cert.keywords) {
        final pattern = RegExp(
          r'(^|[\s,.:;_\-\(\)\[\]/])' +
              RegExp.escape(kw) +
              r'([\s,.:;_\-\(\)\[\]/]|$)',
          caseSensitive: false,
        );
        if (pattern.hasMatch(fullText)) {
          return cert.name;
        }
      }
    }

    // Generic check for "halal" certified labels in OpenFoodFacts tags (e.g. en:halal)
    if (labels != null) {
      for (final l in labels) {
        final clean = l.toLowerCase().trim();
        if (clean == 'en:halal' ||
            clean == 'fr:halal' ||
            clean.contains('halal-certified') ||
            clean.contains('certifie-halal')) {
          return 'Organisme Halal Certifié';
        }
      }
    }

    return null;
  }
}

