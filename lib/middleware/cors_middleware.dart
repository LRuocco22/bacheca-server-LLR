import 'package:shelf/shelf.dart';

const Map<String, String> _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers': 'Authorization, Content-Type, Accept',
};

/// CORS: permette a una pagina web ospitata su un altro dominio
/// (es. l'anteprima di FlutLab) di chiamare le API.
/// L'app web servita dal nostro server non ne ha bisogno (stesso indirizzo).
/// Si usa il token nell'header, non i cookie, quindi "*" è sufficiente.
Middleware corsMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      // Richiesta "preflight" del browser: risponde subito con i permessi
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await inner(request);
      return response.change(headers: _corsHeaders);
    };
  };
}
