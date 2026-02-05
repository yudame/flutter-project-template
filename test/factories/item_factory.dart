import 'package:flutter_template/features/home/data/models/item.dart';

/// Factory for creating test Item instances
///
/// Usage:
/// ```dart
/// final item = ItemFactory.create(title: 'Custom Title');
/// final items = ItemFactory.createList(5);
/// ```
class ItemFactory {
  ItemFactory._();

  static int _counter = 0;

  /// Create a single test item with optional overrides
  static Item create({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isCompleted = false,
  }) {
    _counter++;
    return Item(
      id: id ?? 'test_item_$_counter',
      title: title ?? 'Test Item $_counter',
      description: description,
      createdAt: createdAt ?? DateTime(2024, 1, _counter),
      updatedAt: updatedAt,
      isCompleted: isCompleted,
    );
  }

  /// Create a completed item
  static Item createCompleted({
    String? id,
    String? title,
  }) {
    return create(
      id: id,
      title: title,
      isCompleted: true,
    );
  }

  /// Create a list of test items
  static List<Item> createList(int count) {
    return List.generate(count, (_) => create());
  }

  /// Create a list of items with varying completion status
  static List<Item> createMixed(int count) {
    return List.generate(
      count,
      (index) => create(isCompleted: index.isEven),
    );
  }

  /// Reset the counter (call in setUp if you need deterministic IDs)
  static void reset() {
    _counter = 0;
  }
}
