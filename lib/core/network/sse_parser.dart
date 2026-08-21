import 'dart:async';
import 'dart:convert';

/// The type of a parsed SSE event.
enum SseEventType { data, done, error }

/// A single parsed Server-Sent Events (SSE) event.
///
/// The raw `data:`/`event:`/`id:` fields from one SSE block are collapsed into
/// a typed [SseEvent] so downstream consumers (e.g. [StreamingClient]) can
/// react to data tokens, the terminal `[DONE]` sentinel, and error events
/// without re-parsing text.
class SseEvent {
  const SseEvent.data(this.data, {this.event, this.id})
      : type = SseEventType.data;
  const SseEvent.done()
      : type = SseEventType.done,
        data = '',
        event = null,
        id = null;
  const SseEvent.error(this.data)
      : type = SseEventType.error,
        event = null,
        id = null;

  final SseEventType type;

  /// The payload. For a `data:` event this is the accumulated `data:` value
  /// (multi-line values joined with `\n`). For an error event it is the error
  /// payload.
  final String data;

  /// The value of the `event:` field, if present.
  final String? event;

  /// The value of the `id:` field, if present.
  final String? id;

  bool get isData => type == SseEventType.data;
  bool get isDone => type == SseEventType.done;
  bool get isError => type == SseEventType.error;

  @override
  String toString() => 'SseEvent($type, data: $data, event: $event, id: $id)';
}

/// The sentinel payload that marks the end of a stream.
///
/// Most chat/AI backends emit `data: [DONE]` as the final event.
const String kSseDoneSentinel = '[DONE]';

/// Parses a stream of raw UTF-8 byte chunks into typed SSE events.
///
/// Decoding is performed with [utf8.decoder] so a multi-byte character split
/// across chunk boundaries is still decoded correctly.
Stream<SseEvent> parseSseBytes(Stream<List<int>> chunks) {
  return parseSse(utf8.decoder.bind(chunks));
}

/// Parses a stream of decoded text chunks into typed SSE events.
///
/// The parser buffers partial events across chunk boundaries and only emits a
/// complete [SseEvent] once the terminating blank line (`\n\n`) has been
/// received (or the source stream closes with trailing data).
///
/// Grammar handled (subset of the SSE spec):
/// * `data:` fields — multiple `data:` lines are joined with `\n`.
/// * `[DONE]` sentinel — surfaced as [SseEvent.done].
/// * comments (lines starting with `:`) — ignored, never dispatched.
/// * `event:` / `id:` fields — carried on the emitted [SseEvent].
/// * `event: error` — surfaced as [SseEvent.error].
Stream<SseEvent> parseSse(Stream<String> chunks) async* {
  var buffer = '';

  await for (final chunk in chunks) {
    buffer += chunk;

    // Normalize CRLF / CR to LF so event boundaries are predictable.
    buffer = buffer.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    while (true) {
      final separator = buffer.indexOf('\n\n');
      if (separator < 0) break;

      final block = buffer.substring(0, separator);
      buffer = buffer.substring(separator + 2);

      final event = _parseBlock(block);
      if (event != null) yield event;
    }
  }

  // A trailing block with no terminating blank line is still an event.
  if (buffer.trim().isNotEmpty) {
    final event = _parseBlock(buffer);
    if (event != null) yield event;
  }
}

SseEvent? _parseBlock(String block) {
  final dataLines = <String>[];
  String? eventName;
  String? id;
  var sawField = false;

  for (final line in block.split('\n')) {
    if (line.isEmpty) continue;

    // Comment lines are keep-alive markers and never dispatch an event.
    if (line.startsWith(':')) continue;

    sawField = true;

    final colon = line.indexOf(':');
    String field;
    String value;
    if (colon == -1) {
      field = line;
      value = '';
    } else {
      field = line.substring(0, colon);
      value = line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
    }

    switch (field) {
      case 'data':
        dataLines.add(value);
      case 'event':
        eventName = value;
      case 'id':
        id = value;
    }
  }

  // A block of only comments produces no event.
  if (!sawField) return null;

  final data = dataLines.join('\n');

  // `[DONE]` and `event: done` are the terminal marker.
  if (eventName == 'done' || data == kSseDoneSentinel) {
    return const SseEvent.done();
  }

  if (eventName == 'error') {
    return SseEvent.error(data);
  }

  return SseEvent.data(data, event: eventName, id: id);
}
