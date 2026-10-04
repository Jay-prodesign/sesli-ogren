import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import 'src/app/sesli_ogren_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  runApp(const SesliOgrenApp());
}
