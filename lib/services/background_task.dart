import 'dart:core';
import 'package:flutter/services.dart';
import 'stream_service.dart';

Future<Map<String, dynamic>> getStreamInfo(String songId, [dynamic token]) async {
  if (songId.startsWith("MPED")) {
    songId = songId.substring(4);
  }
  if (token != null && token is RootIsolateToken) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  }
  final playerResponse = await StreamProvider.fetch(songId);
  return playerResponse.hmStreamingData;
}
