import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/recognition_result.dart';
import '../models/scan_session.dart';

/// Raised when recognition can't be completed. The message is already
/// written for the user, in Spanish.
class GeminiException implements Exception {
  const GeminiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Talks to the Gemini API to identify a physical game or console from
/// one or more photos.
///
/// Scope is deliberately narrow: this app only deals with physical video
/// games, consoles and game accessories. Anything else comes back with
/// is_supported = false and gets rejected by the UI.
class GeminiService {
  static const String _host = 'generativelanguage.googleapis.com';

  /// Inline image data caps the whole request at 20MB, so photos are
  /// skipped once we get close to that.
  static const int _maxTotalImageBytes = 15 * 1024 * 1024;

  bool get isConfigured =>
      geminiApiKey.isNotEmpty && !geminiApiKey.startsWith('YOUR-');

  /// Runs one identification pass over every photo in [session].
  Future<RecognitionResult> identify(ScanSession session) async {
    if (!isConfigured) {
      throw const GeminiException(
        'Falta la API key de Gemini. Completa lib/src/config/api_config.dart.',
      );
    }

    final List<Map<String, dynamic>> imageParts = await _buildImageParts(
      session.imagePaths,
    );

    if (imageParts.isEmpty) {
      throw const GeminiException('No se pudo leer la foto del producto.');
    }

    final List<Map<String, dynamic>> parts = [
      {'text': _buildPrompt(session)},
      ...imageParts,
    ];

    // A 503 ("model overloaded") is Google's own infrastructure being
    // busy, not something wrong with this request - it usually clears
    // up within a few seconds. Retry a couple of times with a growing
    // delay before giving up, instead of failing on the first blip.
    const List<Duration> overloadRetryDelays = [
      Duration(seconds: 3),
      Duration(seconds: 8),
    ];

    http.Response response = await _sendWithLegacyFallback(parts);

    for (int attempt = 0;
        response.statusCode == 503 && attempt < overloadRetryDelays.length;
        attempt++) {
      await Future<void>.delayed(overloadRetryDelays[attempt]);
      response = await _sendWithLegacyFallback(parts);
    }

    if (response.statusCode != 200) {
      throw GeminiException(_errorMessageFor(response));
    }

    return _parseResponse(response.body);
  }

  /// One request, with the responseFormat/responseSchema version
  /// fallback already baked in (see the comment this replaced).
  Future<http.Response> _sendWithLegacyFallback(
    List<Map<String, dynamic>> parts,
  ) async {
    http.Response response = await _post(_buildBody(parts, legacy: false));

    if (response.statusCode == 400 &&
        (response.body.contains('responseFormat') ||
            response.body.contains('response_format'))) {
      response = await _post(_buildBody(parts, legacy: true));
    }

    return response;
  }

  Future<http.Response> _post(Map<String, dynamic> body) {
    final Uri uri = Uri.https(
      _host,
      '/v1beta/models/$geminiModel:generateContent',
    );

    return http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': geminiApiKey,
          },
          body: jsonEncode(body),
        )
        .timeout(
          const Duration(seconds: 90),
          onTimeout: () => throw const GeminiException(
            'La identificacion tardo demasiado. Revisa tu conexion e intenta '
            'de nuevo.',
          ),
        );
  }

  Map<String, dynamic> _buildBody(
    List<Map<String, dynamic>> parts, {
    required bool legacy,
  }) {
    final Map<String, dynamic> generationConfig = {
      // Low temperature: this is an extraction task, not a creative one.
      'temperature': 0.1,
      if (legacy) ...{
        'responseMimeType': 'application/json',
        'responseSchema': _responseSchema,
      } else
        'responseFormat': {
          'text': {'mimeType': 'APPLICATION_JSON', 'schema': _responseSchema},
        },
    };

    return {
      'contents': [
        {'parts': parts},
      ],
      'generationConfig': generationConfig,
    };
  }

  Future<List<Map<String, dynamic>>> _buildImageParts(
    List<String> imagePaths,
  ) async {
    final List<Map<String, dynamic>> parts = [];
    int totalBytes = 0;

    for (final String path in imagePaths) {
      final File file = File(path);
      if (!await file.exists()) continue;

      final List<int> bytes = await file.readAsBytes();
      if (totalBytes + bytes.length > _maxTotalImageBytes) break;
      totalBytes += bytes.length;

      parts.add({
        'inline_data': {
          'mime_type': _mimeTypeFor(path),
          'data': base64Encode(bytes),
        },
      });
    }

    return parts;
  }

  String _mimeTypeFor(String path) {
    final String extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }

  /// The instruction block. Spanish for anything the user will read,
  /// English for the eBay query.
  String _buildPrompt(ScanSession session) {
    final StringBuffer prompt = StringBuffer()
      ..writeln(
        'Sos un experto en videojuegos fisicos retro y actuales, y en '
        'consolas. Trabajas para una app que ayuda a revender estos '
        'productos de segunda mano.',
      )
      ..writeln()
      ..writeln('ALCANCE ESTRICTO. Solo aceptas estos productos:')
      ..writeln(
        '- Videojuegos FISICOS (cartuchos, discos, cajas) de '
        'cualquier consola: PlayStation 1/2/3/4/5, Xbox y sus '
        'generaciones, Nintendo (NES, SNES, N64, GameCube, Wii, Wii U, '
        'DS, 3DS, Switch), Sega, PSP, PS Vita, Game Boy, etc.',
      )
      ..writeln('- Consolas de videojuegos y sus revisiones de hardware.')
      ..writeln(
        '- Accesorios de consola (joysticks, memory cards, '
        'cables originales).',
      )
      ..writeln()
      ..writeln(
        'Si la foto muestra CUALQUIER OTRA COSA (una persona, comida, un '
        'celular, una pelicula en DVD, un CD de musica, software de PC que '
        'no sea un juego, un electrodomestico, etc.), devolve '
        'is_supported = false y explica brevemente en rejection_reason, en '
        'espanol, que viste. No inventes un juego que no esta en la foto.',
      )
      ..writeln()
      ..writeln('COMO IDENTIFICAR:')
      ..writeln(
        '- title: el nombre exacto del juego, o el nombre del '
        'modelo de consola (ej. "Silent Hill 2", "PlayStation 2 Slim").',
      )
      ..writeln(
        '- platform: la consola a la que pertenece '
        '(ej. "PlayStation 2"). Vacio si no se puede determinar.',
      )
      ..writeln(
        '- brand: la editora del juego (ej. Konami) o el '
        'fabricante de la consola (ej. Sony).',
      )
      ..writeln(
        '- model_code: el codigo de catalogo impreso. En juegos '
        'suele ser tipo SLUS-20228 / SLES / SCUS; en consolas tipo '
        'SCPH-39001, DOL-001. Dejalo vacio si no lo podes LEER en la '
        'foto: no lo adivines.',
      )
      ..writeln(
        '- region: NTSC-U (America), NTSC-J (Japon), PAL '
        '(Europa/Oceania) o unknown. OJO: NTSC-U cubre tanto Estados '
        'Unidos como Latinoamerica - no son regiones de video '
        'distintas, asi que no la uses sola para saber si es una '
        'edicion latinoamericana.',
      )
      ..writeln(
        '- Si el texto IMPRESO en la caja o el manual esta en '
        'espanol (titulo, instrucciones, clasificacion por edad, '
        'etc.), mencionalo en condition_notes como un dato de la '
        'CAJA, ej. "caja/manual en espanol (edicion para '
        'Latinoamerica)". No lo confundas con el idioma DENTRO del '
        'juego (audio, subtitulos, menus): eso no se puede saber solo '
        'mirando la caja, asi que no lo asumas ni lo afirmes como '
        'si fuera un hecho confirmado.',
      )
      ..writeln(
        '- edition: "Greatest Hits", "Platinum", "Collector\'s '
        'Edition", etc. Vacio si es la edicion comun.',
      )
      ..writeln(
        '- completeness: que tan completo esta el producto segun '
        'lo que se ve.',
      )
      ..writeln(
        '- condition_notes: desgaste visible, en espanol '
        '(rayones, caja rota, etiqueta despegada, amarillamiento...).',
      )
      ..writeln()
      ..writeln('CALIBRA EL TONO SOBRE EL ESTADO - esto es importante:')
      ..writeln(
        '- El desgaste ESTETICO normal de un producto usado '
        '(rayones superficiales, amarillamiento del plastico, polvo, '
        'etiquetas despegadas o gastadas, marcas de uso) NO significa que '
        'el producto este roto o sirva solo para repuestos. Describilo '
        'de forma neutral y factual: "usado, con desgaste estetico '
        'propio del uso" en vez de alarmar.',
      )
      ..writeln(
        '- Reserva frases como "para reparar", "para repuestos" o '
        '"no funciona" UNICAMENTE cuando haya evidencia VISUAL clara de '
        'dano funcional: carcasa rota dejando ver el interior, conector '
        'o puerto roto/doblado, piezas faltantes, corrosion severa, '
        'plastico derretido, pantalla rota. Si la foto no muestra eso, '
        'no lo asumas.',
      )
      ..writeln(
        '- No podes verificar si algo enciende o funciona solo '
        'con una foto. Si no hay evidencia de dano, asumi que es '
        'funcional y decilo asi, no dejes la duda abierta como si fuera '
        'un defecto.',
      )
      ..writeln()
      ..writeln('CONFIANZA (confidence, 0.0 a 1.0):')
      ..writeln('- 0.9+ solo si reconoces el titulo exacto Y la plataforma.')
      ..writeln(
        '- 0.5-0.8 si reconoces el producto pero falta la region, '
        'el codigo o la edicion exacta.',
      )
      ..writeln(
        '- menos de 0.5 si la foto esta borrosa, cortada o muy '
        'lejos.',
      )
      ..writeln()
      ..writeln('CUANDO PEDIR MAS FOTOS (requested_photos):')
      ..writeln(
        '- Pedi fotos SOLO si realmente te faltan datos para '
        'identificar la version exacta o para tasarla bien.',
      )
      ..writeln(
        '- Si ya reconoces el producto con claridad, devolve '
        'identification_complete = true y requested_photos vacio. No '
        'molestes al usuario sin motivo.',
      )
      ..writeln(
        '- Maximo 3 pedidos por vez, y que sean CONCRETOS y '
        'especificos a lo que estas viendo:',
      )
      ..writeln(
        '  * juego en caja -> contratapa (ahi esta el codigo de '
        'catalogo y el logo de region), lomo de la caja, el disco.',
      )
      ..writeln(
        '  * cartucho -> etiqueta de frente bien de cerca, y la '
        'parte de atras del cartucho.',
      )
      ..writeln(
        '  * consola -> etiqueta del numero de serie (abajo o '
        'atras), panel trasero de conexiones.',
      )
      ..writeln(
        '- En cada pedido: title corto en espanol, instruction '
        'clara de como sacar la foto, y reason explicando que dato '
        'resuelve.',
      )
      ..writeln(
        '- Si estas repitiendo un pedido porque la foto anterior '
        'no sirvio (seguis sin poder leer o ver lo que necesitabas), '
        'usa el MISMO id que usaste para ese pedido en tu respuesta '
        'anterior. Esto es importante: el id debe ser identico para '
        'que la app sepa que es un reintento del mismo pedido.',
      )
      ..writeln()
      ..writeln('PARA VENDER:')
      ..writeln(
        '- ebay_query: la busqueda EN INGLES que haria un '
        'coleccionista para encontrar exactamente este producto. '
        'Siempre inclui titulo y plataforma. Sin palabras de estado '
        '("used", "good"). Ej: "Silent Hill 2 PlayStation 2".',
      )
      ..writeln(
        '- Sumale un codigo a ebay_query SOLO si es un codigo de '
        'CATALOGO/SERIE de disco o cartucho de ese formato especifico '
        '(SLUS-20228, SCES-50380, DOL-001, NTR-...) - esos SI aparecen '
        'en titulos reales de publicaciones. NO sumes un codigo de SKU '
        'interno de la editora/distribuidora (ej. formatos tipo '
        '"E4H-00095" impresos en un sticker cerca del codigo de '
        'barras): esos nunca aparecen en el titulo de una publicacion '
        'y arruinan la busqueda devolviendo cero resultados. Ante la '
        'duda, dejalo afuera: title + platform ya alcanza.',
      )
      ..writeln(
        '- listing.title: titulo de publicacion en espanol, '
        'claro y buscable.',
      )
      ..writeln(
        '- listing.description: descripcion de venta en espanol, '
        '2 o 3 frases, honesta sobre el estado visible pero sin '
        'exagerar (ver CALIBRA EL TONO arriba).',
      )
      ..writeln(
        '- estimated_price_min_usd / estimated_price_max_usd: tu '
        'propia estimacion, EN DOLARES (USD), de cuanto se vende este '
        'producto usado en el mercado de segunda mano hoy en dia, '
        'basada en tu conocimiento general de precios de coleccionismo '
        'retro/gaming. Ajustala al estado visible (un producto completo '
        'en caja vale mas que uno suelto con desgaste). Esto es una '
        'estimacion aproximada tuya, no un dato de una publicacion real '
        '- se usa como referencia cuando no hay datos en vivo de eBay o '
        'MercadoLibre. Da un rango razonable, nunca 0.',
      );

    if (session.barcode != null && session.barcode!.isNotEmpty) {
      prompt
        ..writeln()
        ..writeln(
          'DATO EXTRA: el usuario escaneo este codigo de barras del '
          'producto: ${session.barcode}. Usalo para afinar la '
          'identificacion (region y edicion sobre todo).',
        );
    }

    // Round-aware instructions: this is what makes the loop converge.
    if (session.round > 1 && session.previousResult != null) {
      final RecognitionResult previous = session.previousResult!;
      prompt
        ..writeln()
        ..writeln(
          '--- SEGUNDA PASADA (intento ${session.round} de '
          '${ScanSession.maxRounds}) ---',
        )
        ..writeln(
          'Ya analizaste este producto antes y dijiste que era: '
          '"${previous.title}" (${previous.platform}), con confianza '
          '${previous.confidence.toStringAsFixed(2)}.',
        )
        ..writeln(
          'Te faltaba: ${previous.missingInfo.isEmpty ? "informacion general" : previous.missingInfo.join(", ")}.',
        )
        ..writeln(
          'El usuario acaba de agregar las fotos que pediste. Ahora '
          'recibis TODAS las fotos juntas (las viejas y las nuevas). '
          'Volve a identificar usando toda la informacion y corregi tu '
          'respuesta anterior si hace falta.',
        );
    }

    if (session.skippedRequests.isNotEmpty) {
      prompt
        ..writeln()
        ..writeln(
          'El usuario decidio NO dar estas fotos (por ejemplo, el '
          'producto esta sellado y no lo quiere abrir, o no tiene acceso '
          'a esa parte): ${session.skippedRequests.join(", ")}.',
        )
        ..writeln(
          'No vuelvas a pedirlas. Trabaja con lo que tenes: si por esto '
          'no podes confirmar algo especifico (ej. el codigo del disco '
          'adentro de un juego sellado), dejalo vacio o marcalo en '
          'missing_info en vez de bloquear el proceso pidiendo la misma '
          'foto de nuevo. Un juego sellado sigue siendo identificable por '
          'su caja/portada exterior.',
        );
    }

    if (session.isFinalRound) {
      prompt
        ..writeln()
        ..writeln(
          'ESTE ES EL ULTIMO INTENTO: no pidas mas fotos. Devolve '
          'requested_photos vacio e identification_complete = true con la '
          'mejor conclusion que puedas dar, aunque la confianza sea baja.',
        );
    }

    return prompt.toString();
  }

  /// JSON schema the model must fill in. Keep in sync with
  /// RecognitionResult.fromJson.
  static const Map<String, dynamic> _responseSchema = {
    'type': 'object',
    'properties': {
      'is_supported': {
        'type': 'boolean',
        'description':
            'true solo si la foto muestra un videojuego fisico, una consola '
            'o un accesorio de consola',
      },
      'rejection_reason': {
        'type': 'string',
        'description':
            'Si is_supported es false, que se ve en la foto, en espanol',
      },
      'item_type': {
        'type': 'string',
        'enum': ['game', 'console', 'accessory', 'unknown'],
      },
      'title': {'type': 'string'},
      'brand': {'type': 'string'},
      'platform': {'type': 'string'},
      'region': {
        'type': 'string',
        'enum': ['NTSC-U', 'NTSC-J', 'PAL', 'unknown'],
      },
      'model_code': {
        'type': 'string',
        'description': 'Codigo de catalogo leido en la foto, vacio si no se ve',
      },
      'edition': {'type': 'string'},
      'completeness': {
        'type': 'string',
        'enum': [
          'complete_in_box',
          'box_and_game_no_manual',
          'game_only',
          'console_only',
          'console_with_accessories',
          'unknown',
        ],
      },
      'condition_notes': {'type': 'string'},
      'confidence': {'type': 'number'},
      'identification_complete': {'type': 'boolean'},
      'missing_info': {
        'type': 'array',
        'items': {
          'type': 'string',
          'enum': [
            'title',
            'platform',
            'region',
            'model_code',
            'edition',
            'completeness',
            'condition',
          ],
        },
      },
      'requested_photos': {
        'type': 'array',
        'description': 'Maximo 3. Vacio si ya no hace falta nada mas.',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'title': {'type': 'string'},
            'instruction': {'type': 'string'},
            'reason': {'type': 'string'},
          },
          'required': ['id', 'title', 'instruction', 'reason'],
        },
      },
      'ebay_query': {'type': 'string'},
      'listing': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'description': {'type': 'string'},
        },
        'required': ['title', 'description'],
      },
      'estimated_price_min_usd': {
        'type': 'number',
        'description':
            'Estimacion propia del modelo, en USD - no un dato real de '
            'mercado. Usada como referencia cuando eBay/MercadoLibre '
            'no devuelven resultados.',
      },
      'estimated_price_max_usd': {'type': 'number'},
    },
    'required': [
      'is_supported',
      'item_type',
      'title',
      'brand',
      'platform',
      'region',
      'model_code',
      'edition',
      'completeness',
      'condition_notes',
      'confidence',
      'identification_complete',
      'missing_info',
      'requested_photos',
      'ebay_query',
      'listing',
      'estimated_price_min_usd',
      'estimated_price_max_usd',
    ],
  };

  RecognitionResult _parseResponse(String body) {
    try {
      final Map<String, dynamic> envelope =
          jsonDecode(body) as Map<String, dynamic>;

      final List<dynamic> candidates =
          (envelope['candidates'] as List?) ?? const [];
      if (candidates.isEmpty) {
        throw const GeminiException(
          'Gemini no devolvio ningun resultado. Probá con otra foto.',
        );
      }

      final List<dynamic> parts =
          ((candidates.first as Map)['content'] as Map?)?['parts'] as List? ??
          const [];

      final String text = parts
          .whereType<Map>()
          .map((part) => (part['text'] ?? '').toString())
          .join()
          .trim();

      if (text.isEmpty) {
        throw const GeminiException(
          'Gemini devolvio una respuesta vacia. Probá de nuevo.',
        );
      }

      return RecognitionResult.fromJson(
        jsonDecode(_stripCodeFence(text)) as Map<String, dynamic>,
      );
    } on GeminiException {
      rethrow;
    } catch (error) {
      throw GeminiException('No se pudo leer la respuesta de Gemini: $error');
    }
  }

  /// Schema mode normally returns bare JSON, but if a model ever wraps it
  /// in ```json fences this keeps the parse from blowing up.
  String _stripCodeFence(String text) {
    if (!text.startsWith('```')) return text;

    final int firstNewline = text.indexOf('\n');
    final int closing = text.lastIndexOf('```');
    if (firstNewline == -1 || closing <= firstNewline) return text;

    return text.substring(firstNewline + 1, closing).trim();
  }

  String _errorMessageFor(http.Response response) {
    String detail = '';
    try {
      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      detail = ((body['error'] as Map?)?['message'] ?? '').toString();
    } catch (_) {
      detail = response.body;
    }

    switch (response.statusCode) {
      case 400:
        return 'Gemini rechazo la peticion (400). $detail';
      case 401:
      case 403:
        return 'La API key de Gemini no es valida o no tiene permisos.';
      case 429:
        return 'Se alcanzo el limite de uso de Gemini. Esperá un momento e '
            'intentá de nuevo.';
      case 503:
        return 'Los servidores de Gemini estan saturados por demanda alta '
            'en este momento (ya se reintento un par de veces). No es un '
            'problema de tu cuenta ni de tus limites - esperá un minuto '
            'y volve a intentar.';
      default:
        return 'Error de Gemini (${response.statusCode}). $detail';
    }
  }
}

final GeminiService geminiService = GeminiService();
