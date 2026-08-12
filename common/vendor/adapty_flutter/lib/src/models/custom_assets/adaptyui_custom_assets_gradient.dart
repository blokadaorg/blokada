part of 'adaptyui_custom_assets.dart';

extension on Gradient {
  /// `stops` is optional in Flutter's gradients: when it is omitted the colors
  /// are distributed evenly. Mirror that here instead of dropping every color,
  /// otherwise the idiomatic `LinearGradient(colors: [a, b])` would be sent
  /// over the channel with an empty `values` array.
  List<double> get _impliedStops {
    final stops = this.stops;
    if (stops != null) return stops;
    if (colors.length == 1) return const [0.0];

    final separation = 1.0 / (colors.length - 1);
    return List<double>.generate(colors.length, (index) => index * separation);
  }

  List<Map<String, dynamic>> get stopsWithColorsMap {
    if (stops != null && stops!.length != colors.length) {
      throw ArgumentError('Stops and colors arrays must have the same length');
    }

    return _impliedStops
        .asMap()
        .entries
        .map((e) => {
              'color': colors[e.key].stringHexValue,
              'p': e.value,
            })
        .toList();
  }
}

final class AdaptyCustomAssetLinearGradient extends AdaptyCustomAsset {
  final LinearGradient gradient;

  const AdaptyCustomAssetLinearGradient({
    required this.gradient,
  });

  @override
  Map<String, dynamic> get jsonValue {
    final begin = gradient.begin as Alignment;
    final end = gradient.end as Alignment;

    return {
      'type': 'linear-gradient',
      'values': gradient.stopsWithColorsMap,
      'points': {
        'x0': begin.x,
        'y0': begin.y,
        'x1': end.x,
        'y1': end.y,
      },
    };
  }
}
