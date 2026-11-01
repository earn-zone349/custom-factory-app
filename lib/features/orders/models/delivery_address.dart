import 'package:flutter/foundation.dart';

/// Where an order is delivered and who receives it.
@immutable
class DeliveryAddress {
  const DeliveryAddress({
    required this.fullName,
    required this.phone,
    required this.district,
    required this.area,
    required this.addressLine,
    this.landmark = '',
  });

  /// Parses an address. Throws [FormatException] for invalid data.
  factory DeliveryAddress.fromMap(Map<String, dynamic> map) {
    return DeliveryAddress(
      fullName: _readRequired(map, 'fullName'),
      phone: _readRequired(map, 'phone'),
      district: _readRequired(map, 'district'),
      area: _readRequired(map, 'area'),
      addressLine: _readRequired(map, 'addressLine'),
      landmark: _readOptional(map, 'landmark'),
    );
  }

  final String fullName;
  final String phone;
  final String district;
  final String area;
  final String addressLine;
  final String landmark;

  /// One-line address such as "House 5, Road 3, Mirpur, Dhaka".
  String get formatted {
    final String text = <String>[addressLine, area, district].join(', ');
    return landmark.isEmpty ? text : '$text (Near $landmark)';
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'fullName': fullName,
      'phone': phone,
      'district': district,
      'area': area,
      'addressLine': addressLine,
      'landmark': landmark,
    };
  }

  static String _readRequired(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw FormatException('Invalid or missing "$key"');
  }

  static String _readOptional(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value == null) return '';
    if (value is String) return value;
    throw FormatException('Invalid "$key"');
  }
}
