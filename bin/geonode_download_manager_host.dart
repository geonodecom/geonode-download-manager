import 'dart:io';

import 'package:geonode_download_manager/src/native_host/native_host.dart';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    switch (args.first) {
      case '--version':
      case '-v':
      case 'version':
        stderr.writeln('geonode-download-manager-host dev');
        return;
      case '--help':
      case '-h':
      case 'help':
        stderr.writeln('geonode-download-manager-host - native messaging bridge for GeoNode Download Manager');
        return;
    }
  }

  await NativeHost().run(stdin, stdout.add);
}
