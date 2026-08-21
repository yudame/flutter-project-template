import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/connectivity/connectivity_bloc.dart';
import '../../../../core/connectivity/connectivity_state.dart';
import '../../../../core/utils/connectivity_aware_mixin.dart';
import '../../../../core/utils/result.dart';
import '../../data/repositories/chat_repository.dart';

part 'chat_event.dart';
part 'chat_state.dart';
part 'chat_bloc.freezed.dart';

/// Maximum number of characters accumulated before the stream is cancelled.
/// Guards against a runaway stream growing memory unbounded (C-2).
const int kMaxMessageChars = 2000;

/// Reference BLoC for the streaming-chat feature.
///
/// Accumulates streamed tokens into a message, bounded by [kMaxMessageChars],
/// and exposes a user-facing `stop` action wired to a `CancelToken`.
class ChatBloc extends Bloc<ChatEvent, ChatState>
    with ConnectivityAwareBlocMixin {
  ChatBloc({
    required ChatRepository repository,
    required this.connectivityBloc,
  })  : _repository = repository,
        super(const ChatState.initial()) {
    initConnectivityListener();

    on<ChatEvent>(_onEvent);
  }

  final ChatRepository _repository;

  @override
  final ConnectivityBloc connectivityBloc;

  CancelToken? _cancelToken;
  String _accumulated = '';

  Future<void> _onEvent(ChatEvent event, Emitter<ChatState> emit) async {
    await event.when(
      send: (message) => _onSend(message, emit),
      stop: () => _onStop(emit),
    );
  }

  Future<void> _onSend(String userMessage, Emitter<ChatState> emit) async {
    // Cancel any previously in-flight stream and start fresh.
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    _accumulated = '';
    emit(const ChatState.loading());

    await emit.onEach<Result<String>>(
      _repository.stream(userMessage, cancelToken: cancelToken),
      onData: (result) {
        if (result.isFailure) {
          // A failure caused by our own cancellation is handled below; do not
          // surface it as an error.
          if (cancelToken.isCancelled) return;
          emit(ChatState.error(result.errorOrNull ?? 'Stream failed'));
          return;
        }

        if (result.isSuccess) {
          if (cancelToken.isCancelled) return;
          _accumulated += result.dataOrNull ?? '';

          if (_accumulated.length >= kMaxMessageChars) {
            cancelToken.cancel();
          }

          emit(ChatState.streaming(_accumulated));
        }
      },
      onError: (error, _) {
        if (!cancelToken.isCancelled) {
          emit(ChatState.error('Stream failed: $error'));
        }
      },
    );

    // The stream has ended. Decide the terminal state.
    if (cancelToken.isCancelled) {
      // User stop or max-length bound — partial message, never marked success.
      emit(ChatState.stopped(_accumulated));
    } else if (_lastStateIsStreaming) {
      // Stream reached [DONE] cleanly.
      emit(ChatState.completed(_accumulated));
    }
    // Otherwise an error state was already emitted.
  }

  bool get _lastStateIsStreaming => state is ChatStreaming;

  Future<void> _onStop(Emitter<ChatState> emit) async {
    _cancelToken?.cancel();
  }

  @override
  void onConnectivityChanged(ConnectivityState state) {
    // Streaming cannot be replayed offline; abort an in-flight stream when we
    // drop off so the UI is not left mid-token.
    if (state is ConnectivityOffline) {
      _cancelToken?.cancel();
    }
  }
}
