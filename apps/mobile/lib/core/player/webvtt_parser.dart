import 'package:flutter/foundation.dart';

@immutable
class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  bool isActiveAt(Duration position) =>
      position >= start && position <= end;
}

class WebVttParser {
  const WebVttParser._();

  static List<SubtitleCue> parse(String rawVtt) {
    final lines = rawVtt.replaceAll('\r\n', '\n').split('\n');
    final cues = <SubtitleCue>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('WEBVTT') || line.startsWith('NOTE')) {
        i++;
        continue;
      }

      String timingLine = line;
      if (!timingLine.contains('-->') && i + 1 < lines.length) {
        i++;
        timingLine = lines[i].trim();
      }

      if (timingLine.contains('-->')) {
        final parts = timingLine.split('-->');
        final start = _parseTimestamp(parts[0].trim());
        final end = _parseTimestamp(parts[1].trim().split(' ').first);

        i++;
        final textBuffer = <String>[];
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          textBuffer.add(lines[i].trim());
          i++;
        }

        if (start != null && end != null && textBuffer.isNotEmpty) {
          cues.add(
            SubtitleCue(
              start: start,
              end: end,
              text: textBuffer.join('\n'),
            ),
          );
        }
      } else {
        i++;
      }
    }
    return cues;
  }

  static Duration? _parseTimestamp(String raw) {
    final normalized = raw.replaceAll(',', '.');
    final segments = normalized.split(':');
    try {
      if (segments.length == 3) {
        final hours = int.parse(segments[0]);
        final minutes = int.parse(segments[1]);
        final secParts = segments[2].split('.');
        final seconds = int.parse(secParts[0]);
        final millis = secParts.length > 1
            ? int.parse(secParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
      } else if (segments.length == 2) {
        final minutes = int.parse(segments[0]);
        final secParts = segments[1].split('.');
        final seconds = int.parse(secParts[0]);
        final millis = secParts.length > 1
            ? int.parse(secParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
