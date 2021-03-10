// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_io.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:idb_sqflite/src/env_utils.dart';
import 'package:sqflite/sqflite.dart';
import 'package:test/test.dart';

void main() {
  testWidgets('native', (WidgetTester tester) async {
    try {
      idbFactoryNative;
      if (!isRunningAsJavascript) {
        fail('should fail');
      }
    } on UnimplementedError catch (_) {}
  });

  testWidgets('sqflite', (WidgetTester tester) async {
    getIdbFactorySqflite(databaseFactory);

    try {
      idbFactorySembastIo;
      if (isRunningAsJavascript) {
        fail('should fail');
      }
    } on UnimplementedError catch (_) {}
  });

  testWidgets('io', (WidgetTester tester) async {
    getIdbFactorySqflite(databaseFactory);

    try {
      idbFactorySembastIo;
      if (isRunningAsJavascript) {
        fail('should fail');
      }
    } on UnimplementedError catch (_) {}
  });

  testWidgets('memory', (WidgetTester tester) async {
    idbFactoryMemory;
    idbFactoryMemoryFs;
  });
}
