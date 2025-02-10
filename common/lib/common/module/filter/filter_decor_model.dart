part of 'filter.dart';

class FilterDecor {
  final String filterName;
  final List<String> tags;
  final String title;
  final String slug;
  final String description;

  final String? creditName;
  final String? creditUrl;

  FilterDecor({
    required this.filterName,
    required this.tags,
    required this.title,
    required this.slug,
    required this.description,
    this.creditName,
    this.creditUrl,
  });
}
