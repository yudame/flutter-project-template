import 'dart:async';
import 'dart:convert';

import 'package:flutter_template/core/network/sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<SseEvent> _parse(String raw) {
  return parseSse(Stream.fromIterable([raw]));
}

Future<List<SseEvent>> _collect(Stream<SseEvent> stream) {
  return stream.toList();
}

void main() {
  group('SseParser', () {
    test('parses a simple data event', () async {
      final events = await _collect(_parse('data: hello\n\n'));
      expect(events, hasLength(1));
      expect(events.single.isData, isTrue);
      expect(events.single.data, 'hello');
    });

    test('joins multi-line data fields with newline', () async {
      final events = await _collect(_parse('data: line1\ndata: line2\n\n'));
      expect(events.single.data, 'line1\nline2');
    });

    test('strips a single leading space after the field name', () async {
      final events = await _collect(_parse('data: hello world\n\n'));
      expect(events.single.data, 'hello world');
    });

    test('emits an empty data event for a bare data: line', () async {
      final events = await _collect(_parse('data:\n\n'));
      expect(events.single.isData, isTrue);
      expect(events.single.data, '');
    });

    test('surfaces the [DONE] sentinel as a done event, not data', () async {
      final events = await _collect(_parse('data: hello\n\ndata: [DONE]\n\n'));
      expect(events, hasLength(2));
      expect(events[0].isData, isTrue);
      expect(events[0].data, 'hello');
      expect(events[1].isDone, isTrue);
      expect(events[1].data, isEmpty);
    });

    test('surfaces event: done as a done event', () async {
      final events = await _collect(_parse('event: done\n\n'));
      expect(events.single.isDone, isTrue);
    });

    test('surfaces event: error as an error event', () async {
      final events = await _collect(
        _parse('event: error\ndata: upstream failure\n\n'),
      );
      expect(events.single.isError, isTrue);
      expect(events.single.data, 'upstream failure');
    });

    test('ignores comment lines', () async {
      final events = await _collect(_parse(': keepalive\n: ping\n\n'));
      expect(events, isEmpty);
    });

    test('ignores comments but still parses a following data event', () async {
      final events = await _collect(_parse(': keepalive\ndata: token\n\n'));
      expect(events, hasLength(1));
      expect(events.single.data, 'token');
    });

    test('carries event: and id: fields on the emitted event', () async {
      final events = await _collect(
        _parse('id: 42\nevent: message\ndata: hello\n\n'),
      );
      expect(events.single.data, 'hello');
      expect(events.single.event, 'message');
      expect(events.single.id, '42');
    });

    test('parses multiple events in one stream', () async {
      final events = await _collect(
        _parse('data: one\n\ndata: two\n\ndata: three\n\n'),
      );
      expect(events.map((e) => e.data), ['one', 'two', 'three']);
    });

    test('buffers an event split across chunk boundaries', () async {
      // The event is delivered in pieces, including the \n\n boundary.
      final stream = Stream.fromIterable([
        'data: Hel',
        'lo Wo',
        'rld\n\ndata: next\n',
        '\n',
      ]);
      final events = await _collect(parseSse(stream));
      expect(events, hasLength(2));
      expect(events[0].data, 'Hello World');
      expect(events[1].data, 'next');
    });

    test('handles a trailing event with no terminating blank line', () async {
      final events = await _collect(_parse('data: trailing'));
      expect(events, hasLength(1));
      expect(events.single.data, 'trailing');
    });

    test('normalizes CRLF line endings', () async {
      final events = await _collect(parseSse(Stream.fromIterable([
        'data: hello\r\n\r\n',
        'data: world\r\n\r\n',
      ])));
      expect(events.map((e) => e.data), ['hello', 'world']);
    });

    test('decodes UTF-8 split across chunk boundaries', () async {
      final smiley = utf8.encode('data: \u{1F600}\n\n');
      // Split the multi-byte emoji so the first chunk ends mid-code-point.
      final splitPoint = smiley.indexOf(utf8.encode('😀').first) + 2;
      final stream = Stream.fromIterable([
        smiley.sublist(0, splitPoint),
        smiley.sublist(splitPoint),
      ]);
      final events = await _collect(parseSseBytes(stream));
      expect(events.single.data, '😀');
    });
  });
}
