import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

extension RefCache on Ref {
  void cacheFor(Duration duration) {
    final timer = Timer(duration, () {});
    onDispose(() => timer.cancel());
  }
}
