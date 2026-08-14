import 'dart:developer' as dev;

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
