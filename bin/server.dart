import 'dart:io';

import '../lib/controllers/annuncio_controller.dart';
import '../lib/controllers/auth_controller.dart';
import '../lib/controllers/candidatura_controller.dart';
import '../lib/dao/annuncio_dao.dart';
import '../lib/dao/azienda_dao.dart';
import '../lib/dao/candidatura_dao.dart';
import '../lib/dao/json_store.dart';
import '../lib/middleware/auth_middleware.dart';
import '../lib/middleware/cors_middleware.dart';
import '../lib/middleware/error_middleware.dart';
import '../lib/services/cv_storage.dart';
import '../lib/services/seeder.dart';
import '../lib/services/token_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

Future<void> main() async {
  final dataDir = Platform.environment['DATA_DIR'] ?? 'data';
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  await Directory(dataDir).create(recursive: true);

  // DAO con persistenza su file JSON
  final aziendaDao = AziendaDao(JsonCollection('$dataDir/aziende.json'));
  final annuncioDao = AnnuncioDao(JsonCollection('$dataDir/annunci.json'));
  final candidaturaDao =
      CandidaturaDao(JsonCollection('$dataDir/candidature.json'));
  await aziendaDao.load();
  await annuncioDao.load();
  await candidaturaDao.load();
  await Seeder.run(aziende: aziendaDao, annunci: annuncioDao);

  // I curriculum (PDF) vengono salvati come file in data/uploads/
  final cvStorage = CvStorage('$dataDir/uploads');
  await cvStorage.init();

  final tokens = TokenService();

  final health = Router()
    ..get('/api/health', (Request req) => jsonResponse({'status': 'ok'}));

  // Cascade: i router hanno path completi; i 404 "di business" sono lanciati
  // come ApiException, quindi non vengono mai scambiati per "rotta non trovata".
  var cascade = Cascade()
      .add(health.call)
      .add(AuthController(aziendaDao, tokens).router.call)
      .add(AnnuncioController(annuncioDao, candidaturaDao).router.call)
      .add(CandidaturaController(annuncioDao, candidaturaDao, cvStorage)
          .router
          .call);

  // App Flutter web: i file generati da "flutter build web" vanno in web/.
  // Aprendo l'indirizzo del server nel browser si ottiene l'app.
  final webDir = Directory('web');
  if (await webDir.exists()) {
    cascade =
        cascade.add(createStaticHandler('web', defaultDocument: 'index.html'));
    print('App web servita dalla cartella web/');
  } else {
    print('Cartella web/ assente: l\'app web non è ancora stata copiata.');
  }

  final api = cascade
      .add((Request req) => jsonError(404, 'Risorsa non trovata'))
      .handler;

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addMiddleware(errorMiddleware())
      .addMiddleware(authMiddleware(tokens, aziendaDao))
      .addHandler(api);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Bacheca backend in ascolto sulla porta ${server.port}');
  print('Emulatore Android: http://10.0.2.2:${server.port}');
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        print('Indirizzo di rete: http://${addr.address}:${server.port}');
      }
    }
  } catch (_) {
    print('Impossibile leggere gli indirizzi di rete locali.');
  }
  // Per raggiungere il server da un telefono su un'altra rete (es. iPhone in 4G):
  //   cloudflared tunnel --url http://localhost:8080
  // e aprire sul telefono l'indirizzo https://....trycloudflare.com stampato.
}
