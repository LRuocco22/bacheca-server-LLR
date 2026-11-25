# Bacheca annunci di lavoro — back-end

Server REST in Dart (`shelf` + `shelf_router`) per l'app Flutter della bacheca.
I dati sono salvati in file JSON nella cartella `data/`, i curriculum (PDF) in `data/uploads/`.

## Avvio

```
dart pub get
dart run bin/server.dart
```

Il server ascolta sulla porta 8080. Al primo avvio crea dei dati di prova:
- azienda **Demo Lavoro Srl** — email `demo@bacheca.it`, password `Demo1234`
- due annunci pubblicati da questa azienda

Per ripartire da zero basta fermare il server e cancellare la cartella `data/`.

## Ambiente di sviluppo e scelte tecniche

Il progetto è stato sviluppato su un **Chromebook con Linux** (ambiente di
sviluppo Linux di ChromeOS) e provato su un **iPhone**.

- **Perché l'app è usata dal browser e non installata.** Per installare
  un'app su iPhone servono un Mac (Xcode) e un account sviluppatore Apple,
  che non ho. Per questo l'app Flutter è compilata per il **web**
  (`flutter build web`): è lo stesso codice Flutter, che sull'iPhone si apre
  in Safari (e si può aggiungere alla schermata Home come un'app).
- **Chi serve l'app.** I file compilati sono nella cartella `web/` e li
  serve questo stesso server: app e API stanno allo stesso indirizzo.
- **Perché il tunnel.** Il telefono non riusciva a raggiungere direttamente
  il server dentro l'ambiente Linux del Chromebook (port forwarding di
  ChromeOS non funzionante). Ho quindi usato un tunnel Cloudflare
  (`cloudflared tunnel --url http://localhost:8080`), che dà un indirizzo
  `https://....trycloudflare.com` raggiungibile dal telefono.
  Il tunnel trasporta solo il traffico: **il server, i dati (file JSON) e i
  curriculum restano sul mio computer** e sono gestiti dal codice di questo
  repository. Non si usano servizi esterni già pronti (tipo Firebase o
  Supabase) per la logica o per i dati.
- **Compilazione dell'app.** Il Chromebook non ha abbastanza memoria per
  compilare Flutter, quindi la compilazione web la esegue GitHub Actions nel
  repository dell'app; il risultato viene copiato in `web/`.

## Struttura

```
bin/server.dart            avvio: DAO, controller, middleware
lib/models/                Azienda, Annuncio, Candidatura
lib/dao/                   lettura/scrittura dei file JSON (JsonCollection)
lib/controllers/           rotte REST
lib/middleware/            autenticazione (token Bearer) e gestione errori
lib/services/              password (salt + SHA-256), token, salvataggio CV, seeder
lib/utils/validators.dart  validazione dei dati in ingresso
test.http                  richieste di prova (estensione REST Client di VS Code)
```

## API

Gli errori hanno sempre la forma `{"error": "messaggio"}`.
Le rotte con 🔒 richiedono l'header `Authorization: Bearer <token>`.

| Metodo | Percorso | Descrizione | Req. |
|---|---|---|---|
| POST | `/api/auth/register` | registra un'azienda `{nome, email, password}` | R1 |
| POST | `/api/auth/login` | login `{email, password}` → `{token, azienda}` | R2 |
| POST | `/api/auth/logout` 🔒 | logout (il token non vale più) | R3 |
| GET | `/api/auth/me` 🔒 | azienda autenticata | — |
| POST | `/api/annunci` 🔒 | pubblica un annuncio `{titolo, descrizione}` | R4 |
| GET | `/api/annunci` | bacheca pubblica | R5 |
| GET | `/api/annunci/<id>` | dettaglio annuncio | R5 |
| POST | `/api/annunci/<id>/candidature` | candidatura, multipart: `nome`, `cognome`, `email`, `cv` (PDF) | R6 |
| GET | `/api/azienda/annunci` 🔒 | annunci dell'azienda con `numCandidature` | R7 |
| GET | `/api/azienda/annunci/<id>/candidature` 🔒 | candidature ricevute | R7 |
| GET | `/api/candidature/<id>/cv` 🔒 | scarica il curriculum (PDF); token anche come `?token=` per aprirlo nel browser | R7 |

Codici usati: 200/201/204 ok, 400 richiesta malformata, 401 non autenticato,
403 risorsa di un'altra azienda, 404 non trovato, 409 email già registrata,
422 dati non validi.

## App web e accesso dal telefono

L'app Flutter (repository separato `bacheca-app-LLR`) viene compilata per il web con
`flutter build web`; il contenuto di `build/web` va copiato nella cartella
`web/` di questo progetto. Il server la mostra aprendo il suo indirizzo
nel browser (es. `http://localhost:8080`).

Per aprirla da uno smartphone su qualsiasi rete si usa un tunnel:

```
cloudflared tunnel --url http://localhost:8080
```

e si apre sul telefono l'indirizzo `https://....trycloudflare.com` stampato
(cambia a ogni avvio del tunnel). Il tunnel trasporta solo il traffico:
server, dati e file restano su questo computer.
