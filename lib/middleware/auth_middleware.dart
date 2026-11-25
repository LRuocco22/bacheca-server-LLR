import 'package:shelf/shelf.dart';

import '../dao/azienda_dao.dart';
import '../models/azienda.dart';
import '../services/token_service.dart';
import 'error_middleware.dart';

const String _aziendaKey = 'bacheca.azienda';
const String _tokenKey = 'bacheca.token';

/// Azienda autenticata della richiesta (null se ospite, cioè un candidato).
Azienda? currentAzienda(Request request) =>
    request.context[_aziendaKey] as Azienda?;

/// Token Bearer valido della richiesta (null se assente/non valido).
String? currentToken(Request request) => request.context[_tokenKey] as String?;

/// Legge "Authorization: Bearer <token>" e, se valido, mette azienda e token nel context.
/// Eccezione: per scaricare il CV (GET .../cv) accetta anche "?token=...",
/// perché un link aperto nel browser non può inviare l'header Authorization.
Middleware authMiddleware(TokenService tokens, AziendaDao aziende) {
  return (Handler inner) {
    return (Request request) {
      var req = request;
      String? token;
      final header = request.headers['authorization'];
      if (header != null && header.toLowerCase().startsWith('bearer ')) {
        token = header.substring(7).trim();
      } else if (request.method == 'GET' && request.url.path.endsWith('/cv')) {
        token = request.url.queryParameters['token'];
      }
      if (token != null && token.isNotEmpty) {
        final aziendaId = tokens.userIdFor(token);
        if (aziendaId != null) {
          final azienda = aziende.findById(aziendaId);
          if (azienda != null) {
            req = request
                .change(context: {_aziendaKey: azienda, _tokenKey: token});
          }
        }
      }
      return inner(req);
    };
  };
}

/// Protegge un handler: 401 se la richiesta non ha un token valido
/// (area riservata accessibile solo all'azienda autenticata).
Handler guard(Handler handler) {
  return (Request request) {
    if (currentAzienda(request) == null) {
      return jsonError(401, 'Autenticazione richiesta');
    }
    return handler(request);
  };
}
