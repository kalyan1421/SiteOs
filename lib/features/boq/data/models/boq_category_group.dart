import 'boq_item_model.dart';

/// A category bucket of BOQ line items with its computed subtotal.
/// Used by the detail screen's accordion and the PDF abstract sheet.
class BoqCategoryGroup {
  final String category;
  final List<BoqItemModel> items;

  const BoqCategoryGroup({required this.category, required this.items});

  /// Sum of every line's amount in this category.
  double get subtotal =>
      items.fold<double>(0, (sum, item) => sum + item.computedAmount);

  int get itemCount => items.length;
}

/// Groups a flat list of [BoqItemModel] into per-category [BoqCategoryGroup]s,
/// preserving each item's sort order and listing categories alphabetically.
List<BoqCategoryGroup> groupBoqItemsByCategory(List<BoqItemModel> items) {
  final map = <String, List<BoqItemModel>>{};
  for (final item in items) {
    final key = item.category.trim().isEmpty ? 'General' : item.category.trim();
    map.putIfAbsent(key, () => <BoqItemModel>[]).add(item);
  }
  final groups = map.entries.map((entry) {
    final sorted = [...entry.value]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return BoqCategoryGroup(category: entry.key, items: sorted);
  }).toList()
    ..sort((a, b) => a.category.toLowerCase().compareTo(b.category.toLowerCase()));
  return groups;
}

/// The grand total across all categories.
double boqGrandTotal(List<BoqItemModel> items) =>
    items.fold<double>(0, (sum, item) => sum + item.computedAmount);
