import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import 'src/app/sesli_ogren_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  runApp(const SesliOgrenApp());
}
