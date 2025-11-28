import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../shared/widgets/connectivity_banner.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../bloc/home_bloc.dart';
import '../widgets/item_card.dart';
import '../widgets/add_item_dialog.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<HomeBloc>()..add(const HomeEvent.load()),
      child: const HomeView(),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ConnectivityBanner(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Template'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                context.read<HomeBloc>().add(const HomeEvent.refresh());
              },
            ),
          ],
        ),
        body: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            return state.when(
              initial: () => const LoadingIndicator(),
              loading: () => const LoadingIndicator(message: 'Loading items...'),
              loaded: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    title: 'No items yet',
                    subtitle: 'Tap the + button to create your first item',
                    icon: Icons.inventory_2_outlined,
                    actionLabel: 'Add Item',
                    onAction: () => _showAddItemDialog(context),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<HomeBloc>().add(const HomeEvent.refresh());
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ItemCard(
                        item: item,
                        onToggle: (completed) {
                          context.read<HomeBloc>().add(
                                HomeEvent.updateItem(
                                  item.copyWith(isCompleted: completed),
                                ),
                              );
                        },
                        onDelete: () {
                          context
                              .read<HomeBloc>()
                              .add(HomeEvent.deleteItem(item.id));
                        },
                      );
                    },
                  ),
                );
              },
              error: (message) => ErrorView(
                message: message,
                onRetry: () {
                  context.read<HomeBloc>().add(const HomeEvent.load());
                },
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddItemDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddItemDialog(
        onAdd: (title, description) {
          context.read<HomeBloc>().add(
                HomeEvent.createItem(
                  title: title,
                  description: description,
                ),
              );
        },
      ),
    );
  }
}
