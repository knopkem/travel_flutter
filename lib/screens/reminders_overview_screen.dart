import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';

/// Screen for viewing and managing all shopping reminders
class RemindersOverviewScreen extends StatefulWidget {
  const RemindersOverviewScreen({super.key});

  @override
  State<RemindersOverviewScreen> createState() =>
      _RemindersOverviewScreenState();
}

class _RemindersOverviewScreenState extends State<RemindersOverviewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Reminders'),
        actions: [
          Consumer<ReminderProvider>(
            builder: (context, provider, _) {
              if (provider.reminders.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear all reminders',
                onPressed: () => _confirmClearAll(context, provider),
              );
            },
          ),
        ],
      ),
      body: Consumer<ReminderProvider>(
        builder: (context, reminderProvider, child) {
          if (reminderProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (reminderProvider.reminders.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: reminderProvider.reminders.length,
            itemBuilder: (context, index) {
              final reminder = reminderProvider.reminders[index];
              return _ReminderCard(
                reminder: reminder,
                onDelete: () => _confirmDelete(context, reminder),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Shopping Reminders',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create reminders from commercial POIs like\nsupermarkets, pharmacies, or hardware stores.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Reminder reminder) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Reminder?'),
        content: Text(
          'Remove shopping reminder for ${reminder.brandName}?\n\n'
          'This will delete your shopping list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // ignore: use_build_context_synchronously
      final provider = Provider.of<ReminderProvider>(context, listen: false);
      final success = await provider.removeReminder(reminder.id);
      if (success && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Removed reminder for ${reminder.brandName}'),
          ),
        );
      }
    }
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    ReminderProvider provider,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear All Reminders?'),
        content: Text(
          'Remove all ${provider.reminders.length} shopping reminders?\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Remove all reminders one by one
      final reminders = List<Reminder>.from(provider.reminders);
      for (final reminder in reminders) {
        await provider.removeReminder(reminder.id);
      }
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('All reminders cleared')),
        );
      }
    }
  }
}

/// Card widget for displaying a single reminder with expandable shopping list
class _ReminderCard extends StatefulWidget {
  final Reminder reminder;
  final VoidCallback onDelete;

  const _ReminderCard({
    required this.reminder,
    required this.onDelete,
  });

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard> {
  bool _isExpanded = false;
  final TextEditingController _newItemController = TextEditingController();

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uncheckedCount =
        widget.reminder.items.where((i) => !i.isChecked).length;
    final totalCount = widget.reminder.items.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          // Header
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[700],
              child: const Icon(Icons.shopping_cart, color: Colors.white),
            ),
            title: Text(
              widget.reminder.brandName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$uncheckedCount of $totalCount items remaining',
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: widget.onDelete,
                ),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Original POI info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.store, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Created from: ${widget.reminder.originalPoiName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Shopping list
                  Text(
                    'Shopping List',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.reminder.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.reminder.items[index];
                      return _ShoppingItemTile(
                        item: item,
                        reminderId: widget.reminder.id,
                      );
                    },
                  ),

                  // Add new item
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newItemController,
                          decoration: InputDecoration(
                            hintText: 'Add item...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onSubmitted: (_) => _addItem(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: _addItem,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addItem() {
    final text = _newItemController.text.trim();
    if (text.isEmpty) return;

    final provider = Provider.of<ReminderProvider>(context, listen: false);
    provider.addItem(widget.reminder.id, text);
    _newItemController.clear();
  }
}

/// Tile for a single shopping list item
class _ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final String reminderId;

  const _ShoppingItemTile({
    required this.item,
    required this.reminderId,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        final provider = Provider.of<ReminderProvider>(context, listen: false);
        provider.removeItem(reminderId, item.id);
      },
      child: CheckboxListTile(
        value: item.isChecked,
        onChanged: (checked) {
          final provider =
              Provider.of<ReminderProvider>(context, listen: false);
          provider.toggleItem(reminderId, item.id);
        },
        title: Text(
          item.text,
          style: TextStyle(
            decoration: item.isChecked ? TextDecoration.lineThrough : null,
            color: item.isChecked ? Colors.grey : null,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
