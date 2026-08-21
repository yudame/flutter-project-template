import 'package:freezed_annotation/freezed_annotation.dart';

part 'item.freezed.dart';
part 'item.g.dart';

@freezed
abstract class Item with _$Item {
  const factory Item({
    required String id,
    required String title,
    required DateTime createdAt,
    String? description,
    DateTime? updatedAt,
    @Default(false) bool isCompleted,
  }) = _Item;

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
}
