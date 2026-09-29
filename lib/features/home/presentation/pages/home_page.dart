import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/connectivity_banner.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../bloc/home_bloc.dart';
import '../widgets/add_item_dialog.dart';
import '../widgets/item_card.dart';

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
    final l10n = AppLocalizations.of(context);

    return ConnectivityBanner(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
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
            return switch (state) {
              HomeInitial() => const LoadingIndicator(),
              HomeLoading() => LoadingIndicator(message: l10n.loadingMessage),
              HomeLoaded(:final items) => items.isEmpty
                  ? EmptyState(
                      title: l10n.emptyListTitle,
                      subtitle: l10n.emptyListSubtitle,
                      icon: Icons.inventory_2_outlined,
                      actionLabel: l10n.buttonAdd,
                      onAction: () => _showAddItemDialog(context),
                    )
                  : RefreshIndicator(
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
                    ),
              HomeError(:final message) => ErrorView(
                  message: message,
                  onRetry: () {
                    context.read<HomeBloc>().add(const HomeEvent.load());
                  },
                ),
            };
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
