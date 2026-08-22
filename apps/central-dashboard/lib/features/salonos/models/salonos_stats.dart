enum BusinessType {
  beauty,
  healthWellness,
  homeServices,
  automotive,
  professionalServices,
  other;

  factory BusinessType.fromJson(String value) {
    return switch (value) {
      'BEAUTY' => BusinessType.beauty,
      'HEALTH_WELLNESS' => BusinessType.healthWellness,
      'HOME_SERVICES' => BusinessType.homeServices,
      'AUTOMOTIVE' => BusinessType.automotive,
      'PROFESSIONAL_SERVICES' => BusinessType.professionalServices,
      'OTHER' => BusinessType.other,
      _ => throw FormatException('Unsupported businessType: $value.'),
    };
  }
}

class SalonosBreakdown {
  final double returnEngine;
  final double slotFiller;
  final double noShowGuards;

  const SalonosBreakdown({
    required this.returnEngine,
    required this.slotFiller,
    required this.noShowGuards,
  });

  factory SalonosBreakdown.fromJson(Map<String, dynamic> json) {
    return SalonosBreakdown(
      returnEngine: _number(json, 'returnEngine'),
      slotFiller: _number(json, 'slotFiller'),
      noShowGuards: _number(json, 'noShowGuards'),
    );
  }

  bool get isEmpty => returnEngine == 0 && slotFiller == 0 && noShowGuards == 0;
}

class SalonosDailyAction {
  final String id;
  final String title;
  final String detail;
  final int count;

  const SalonosDailyAction({
    required this.id,
    required this.title,
    required this.detail,
    required this.count,
  });

  factory SalonosDailyAction.fromJson(Map<String, dynamic> json) {
    return SalonosDailyAction(
      id: _string(json, 'id'),
      title: _string(json, 'title'),
      detail: _string(json, 'detail'),
      count: _number(json, 'count').toInt(),
    );
  }
}

class SalonosStats {
  final String providerId;
  final String businessName;
  final BusinessType businessType;
  final double totalAiRevenue;
  final SalonosBreakdown breakdown;
  final List<SalonosDailyAction> dailyActions;
  final String currency;
  final DateTime periodStart;

  const SalonosStats({
    required this.providerId,
    required this.businessName,
    required this.businessType,
    required this.totalAiRevenue,
    required this.breakdown,
    required this.dailyActions,
    required this.currency,
    required this.periodStart,
  });

  factory SalonosStats.fromJson(Map<String, dynamic> json) {
    final provider = _map(json, 'provider');
    final actions = json['dailyActions'];
    if (actions is! List) {
      throw const FormatException('dailyActions must be a list.');
    }

    return SalonosStats(
      providerId: _string(provider, 'id'),
      businessName: _string(provider, 'businessName'),
      businessType: BusinessType.fromJson(_string(provider, 'businessType')),
      totalAiRevenue: _number(json, 'totalAiRevenue'),
      breakdown: SalonosBreakdown.fromJson(_map(json, 'breakdown')),
      dailyActions: List.unmodifiable(
        actions.map((item) => SalonosDailyAction.fromJson(_asMap(item))),
      ),
      currency: _string(json, 'currency'),
      periodStart: DateTime.parse(_string(json, 'periodStart')),
    );
  }

  bool get isEmpty =>
      totalAiRevenue == 0 &&
      breakdown.isEmpty &&
      dailyActions.every((action) => action.count == 0);
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key) {
  return _asMap(json[key], field: key);
}

Map<String, dynamic> _asMap(Object? value, {String field = 'value'}) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return Map<String, dynamic>.from(value);
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

double _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key must be a number.');
  return value.toDouble();
}
