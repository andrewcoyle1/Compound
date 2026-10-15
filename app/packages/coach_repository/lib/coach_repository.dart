/// The AI coach: streaming `coachChat` answers, consent, and the saved
/// chats in Firestore, with canned answers over an in-memory Firestore for
/// the staging flavor.
library;

export 'package:compound_models/compound_models.dart'
    show CoachChat, CoachMessage, CoachMessageRole;

export 'src/coach_chat_call.dart';
export 'src/coach_repository.dart';
export 'src/in_memory_coach_repository.dart';
