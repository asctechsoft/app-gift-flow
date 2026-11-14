import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Toast {
  Toast._();

  static void show(String message) {
    final ctx = Get.context;
    if (ctx == null) return;
    final m = ScaffoldMessenger.maybeOf(ctx);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(message)));
  }
}
