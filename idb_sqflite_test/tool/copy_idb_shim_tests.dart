import 'dart:io';

import 'package:path/path.dart';

Future main() async {
  var src = '../../tekartik/idb_shim.dart/idb_shim/test';
  var dst = 'test_idb_shim';

  Future copy(String file) async {
    var dstFile = join(dst, file);
    await Directory(dirname(dstFile)).create(recursive: true);
    await File(join(src, file)).copy(join(dst, file));
  }

  Future copyAll(List<String> files) async {
    for (var file in files) {
      print(file);
      await copy(file);
    }
  }

  var list = Directory(src)
      .listSync(recursive: true)
      .map((entity) => relative(entity.path, from: src))
      .where((path) =>
          split(path).first != 'web' &&
          FileSystemEntity.isFileSync(join(src, path)));

  //

  await Directory(dst).delete(recursive: true);
  print(list);
  await copyAll([
    ...list,
  ]);
}
