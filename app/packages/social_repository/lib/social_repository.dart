/// Reads and writes what users share with each other: follows and follow
/// requests, the following feed, likes, comments, notifications,
/// challenges, invites, shares, reports and usernames, in Firestore, or in
/// an in-memory Firestore in the staging flavor. Held to the Firestore
/// contract (docs/specs/flutter/firestore-contract.md).
library;

export 'package:compound_models/compound_models.dart'
    show
        ActivityNotificationModel,
        ActivityType,
        ChallengeModel,
        FollowRequestModel,
        FollowRequestStatus,
        InviteModel,
        MesocycleSharePayload,
        ReportContentType,
        ReportReason,
        ShareModel,
        SharePayload,
        ShareStatus,
        TemplateSharePayload,
        WorkoutSessionComment;

export 'src/in_memory_social_repository.dart';
export 'src/sample_social.dart';
export 'src/social_repository.dart';
export 'src/social_rules.dart';
