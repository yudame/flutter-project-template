import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_template/core/connectivity/connectivity_bloc.dart';
import 'package:flutter_template/core/connectivity/connectivity_state.dart';
import 'package:flutter_template/core/utils/result.dart';
import 'package:flutter_template/features/chat/data/repositories/chat_repository.dart';
import 'package:flutter_template/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

void main() {
  late ChatBloc bloc;
  late MockChatRepository repository;
  late MockConnectivityBloc connectivityBloc;

  setUp(() {
    repository = MockChatRepository();
    connectivityBloc = MockConnectivityBloc();

    when(() => connectivityBloc.state).thenReturn(
      const ConnectivityState.online(),
    );
    when(() => connectivityBloc.stream).thenAnswer(
      (_) => const Stream.empty(),
    );

    bloc = ChatBloc(
      repository: repository,
      connectivityBloc: connectivityBloc,
    );

    streamController = null;
    capturedToken = null;
  });

  tearDown(() {
    bloc.close();
  });

  group('ChatBloc', () {
    test('initial state is ChatState.initial', () {
      expect(bloc.state, const ChatState.initial());
    });

    group('send', () {
      blocTest<ChatBloc, ChatState>(
        'accumulates tokens across stream events before completion (N-1)',
        build: () {
          when(
            () => repository.stream(
              any(),
              cancelToken: any(named: 'cancelToken'),
            ),
          ).thenAnswer(
            (_) => Stream<Result<String>>.fromIterable(const [
              Result.success('Hel'),
              Result.success('lo'),
              Result.success('!'),
            ]),
          );
          return bloc;
        },
        act: (bloc) => bloc.add(const ChatEvent.send('hi')),
        expect: () => [
          const ChatState.loading(),
          const ChatState.streaming('Hel'),
          const ChatState.streaming('Hello'),
          const ChatState.streaming('Hello!'),
          const ChatState.completed('Hello!'),
        ],
      );

      blocTest<ChatBloc, ChatState>(
        'does not mark a half-accumulated message success on mid-stream '
        'failure (C-1)',
        build: () {
          when(
            () => repository.stream(
              any(),
              cancelToken: any(named: 'cancelToken'),
            ),
          ).thenAnswer(
            (_) => Stream<Result<String>>.fromIterable(const [
              Result.success('partial'),
              Result.failure('Network error'),
            ]),
          );
          return bloc;
        },
        act: (bloc) => bloc.add(const ChatEvent.send('hello')),
        expect: () => [
          const ChatState.loading(),
          const ChatState.streaming('partial'),
          const ChatState.error('Network error'),
        ],
      );

      blocTest<ChatBloc, ChatState>(
        'halts accumulation and stops at the max-length bound (C-2)',
        build: () {
          final big = 'a' * kMaxMessageChars;
          when(
            () => repository.stream(
              any(),
              cancelToken: any(named: 'cancelToken'),
            ),
          ).thenAnswer(
            (_) => Stream<Result<String>>.fromIterable(
              <Result<String>>[
                Result.success(big),
                const Result.success('bbbb'),
              ],
            ),
          );
          return bloc;
        },
        act: (bloc) => bloc.add(const ChatEvent.send('hello')),
        expect: () => [
          const ChatState.loading(),
          ChatState.streaming('a' * kMaxMessageChars),
          // Accumulation halted at the bound: the trailing 'bbbb' was ignored
          // and the stream was stopped, not completed.
          ChatState.stopped('a' * kMaxMessageChars),
        ],
      );
    });

    group('stop', () {
      blocTest<ChatBloc, ChatState>(
        'cancels the in-flight CancelToken',
        build: () {
          streamController = StreamController<Result<String>>();
          when(
            () => repository.stream(
              any(),
              cancelToken: any(named: 'cancelToken'),
            ),
          ).thenAnswer((invocation) {
            capturedToken =
                invocation.namedArguments[#cancelToken] as CancelToken?;
            return streamController!.stream;
          });
          return bloc;
        },
        act: (bloc) async {
          bloc.add(const ChatEvent.send('hello'));
          await Future<void>.delayed(const Duration(milliseconds: 20));
          bloc.add(const ChatEvent.stop());
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await streamController!.close();
        },
        verify: (_) {
          expect(capturedToken, isNotNull);
          expect(capturedToken!.isCancelled, isTrue);
        },
      );
    });
  });
}

StreamController<Result<String>>? streamController;
CancelToken? capturedToken;
