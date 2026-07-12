import 'package:flutter/foundation.dart';

import '../core/coach/coach_exception.dart';
import '../repositories/coach_repository.dart';

class CoachChatMessage {
  final String text;
  final bool fromUser;

  const CoachChatMessage(this.text, this.fromUser);
}

const _welcomeMessage = CoachChatMessage(
  'Hola, soy tu Gemelo Digital. Te conozco por tu historial de entrenamiento '
  'en la app. Preguntame lo que quieras.',
  false,
);

/// Estado del chat del Coach IA -- la pantalla solo lee `messages`/`sending`/
/// `llmUnavailable` y llama a `sendMessage`; nunca interpreta un código HTTP
/// ni construye el `CoachContext` por su cuenta (eso vive en
/// `CoachRepository`/`CoachContextBuilder`).
class CoachProvider extends ChangeNotifier {
  final CoachRepository _repository;

  CoachProvider(this._repository);

  final List<CoachChatMessage> messages = [_welcomeMessage];
  bool sending = false;
  bool llmUnavailable = false;

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || sending) return;

    messages.add(CoachChatMessage(trimmed, true));
    sending = true;
    llmUnavailable = false;
    notifyListeners();

    try {
      final reply = await _repository.sendMessage(trimmed);
      messages.add(CoachChatMessage(reply.text, false));
    } on CoachUnavailableException catch (e) {
      llmUnavailable = true;
      messages.add(CoachChatMessage(e.message, false));
    } on CoachException catch (e) {
      messages.add(CoachChatMessage(e.message, false));
    } finally {
      sending = false;
      notifyListeners();
    }
  }
}
