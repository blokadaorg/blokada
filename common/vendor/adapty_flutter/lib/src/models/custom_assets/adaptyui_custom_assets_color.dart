part of 'adaptyui_custom_assets.dart';

extension on Color {
  String get stringHexValue => '#${toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

final class AdaptyCustomAssetColor extends AdaptyCustomAsset {
  final Color color;

  const AdaptyCustomAssetColor({
    required this.color,
  });

  @override
  Map<String, dynamic> get jsonValue {
    return {
      'type': 'color',
      'value': color.stringHexValue,
    };
  }
}
