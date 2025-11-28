import 'package:flutter/material.dart';

import '../../data/models/item.dart';

class ItemCard extends StatelessWidget {
  final Item item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const ItemCard({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTemp = item.id.startsWith('temp_');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Checkbox(
          value: item.isCompleted,
          onChanged: (value) => onToggle(value ?? false),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
            color: item.isCompleted ? colorScheme.outline : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.description != null && item.description!.isNotEmpty)
              Text(
                item.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (isTemp)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 14,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pending sync',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: colorScheme.error),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
