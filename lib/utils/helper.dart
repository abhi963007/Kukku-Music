import 'dart:developer' as dev;

import 'package:hive/hive.dart';

int getDatestamp() {
  final now = DateTime.now();
  return (now.millisecondsSinceEpoch / 1000).round();
}

bool isExpired({int? epoch, String? url}) {
  if (epoch != null) {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= epoch;
  }
  if (url != null) {
    try {
      final uri = Uri.parse(url);
      final expireParam = uri.queryParameters['expire'];
      if (expireParam != null) {
        final expireEpoch = int.tryParse(expireParam);
        if (expireEpoch != null) {
          // If less than 5 minutes remaining, consider expired
          return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= (expireEpoch - 300);
        }
      }
    } catch (_) {}
  }
  return false;
}

String cleanFilename(String text) {
  final RegExp invalidChar = RegExp(r'Container.|\/|\\|\"|\<|\>|\*|\?|\:|\!|\[|\]|\¡|\||\%');
  return text.replaceAll(invalidChar, '').trim();
}

String formatDuration(Duration? duration) {
  if (duration == null) return "0:00";
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return "$minutes:${seconds.toString().padLeft(2, '0')}";
}

String formatBytes(int bytes) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB"];
  var i = 0;
  double d = bytes.toDouble();
  while (d >= 1024 && i < suffixes.length - 1) {
    d /= 1024;
    i++;
  }
  return "${d.toStringAsFixed(1)} ${suffixes[i]}";
}

void printINFO(String message) {
  dev.log('[Kukku-INFO] $message');
}

void printERROR(String message, [dynamic error]) {
  dev.log('[Kukku-ERROR] $message: $error');
}

// ── Hive safety helpers ─────────────────────────────────────────────────────
//
// Hive throws if a box was never opened (e.g. `Hive.initFlutter()` failed at
// startup). Every call site used to assume the box exists, so a single storage
// failure cascaded into crashes across the whole app. These helpers degrade to
// in-memory defaults instead.

/// In-memory stand-in used when a Hive box could not be opened.
final Map<String, Map<dynamic, dynamic>> _fallbackStore = {};

/// Returns the opened Hive box, or `null` when unavailable.
Box? safeBox(String name) {
  try {
    if (!Hive.isBoxOpen(name)) return null;
    return Hive.box(name);
  } catch (e) {
    printERROR('Hive box "$name" unavailable', e);
    return null;
  }
}

/// Reads [key] from [boxName], falling back to [defaultValue] when the box is
/// missing or the read throws.
T boxGet<T>(String boxName, String key, T defaultValue) {
  try {
    final box = safeBox(boxName);
    final raw = box != null
        ? box.get(key, defaultValue: defaultValue)
        : (_fallbackStore[boxName]?[key] ?? defaultValue);
    if (raw is T) return raw;
    return defaultValue;
  } catch (e) {
    printERROR('boxGet($boxName/$key) failed', e);
    return defaultValue;
  }
}

/// Writes [value] to [boxName], silently no-oping when the box is unavailable.
Future<void> boxPut(String boxName, String key, dynamic value) async {
  try {
    final box = safeBox(boxName);
    if (box == null) {
      (_fallbackStore[boxName] ??= {})[key] = value;
      return;
    }
    await box.put(key, value);
  } catch (e) {
    printERROR('boxPut($boxName/$key) failed', e);
  }
}

// ── Dynamic-value coercion ──────────────────────────────────────────────────
//
// Values round-tripped through Hive or decoded from third-party JSON lose their
// static type: nested maps come back as `Map<dynamic, dynamic>` and numbers may
// arrive as strings. Casting them directly throws at runtime, so all decoding
// goes through these.

/// Recursively normalises a dynamic value into a `Map<String, dynamic>`.
///
/// Returns an empty map for anything that is not map-like, so callers never
/// need a null check.
Map<String, dynamic> asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    final out = <String, dynamic>{};
    value.forEach((k, v) => out[k.toString()] = v);
    return out;
  }
  return <String, dynamic>{};
}

/// Coerces a dynamic value to `int`, accepting numbers and numeric strings.
int asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Coerces a dynamic value to `double`.
double asDouble(dynamic value, [double fallback = 0.0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// Coerces a dynamic value to `bool`, accepting `"true"`/`"false"` and 0/1.
bool asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
  }
  return fallback;
}

/// Coerces a dynamic value to a trimmed `String` (empty when null).
String asText(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  return value.toString().trim();
}
