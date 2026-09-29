//
//  TabBarInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol TabBarInteractor: GlobalInteractor {
    var activeSession: WorkoutSessionModel? { get }
    var draftMeal: MealLogModel? { get }
    var activityNotifications: [ActivityNotificationModel] { get }
    var incomingFollowRequests: [FollowRequestModel] { get }
    func consumePendingDeepLink() -> DeepLink?
}

extension CoreInteractor: TabBarInteractor { }
