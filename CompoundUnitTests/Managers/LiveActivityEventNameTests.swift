//
//  LiveActivityEventNameTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)

/// The Live Activity manager's own events.
///
/// Starting an activity shipped as "StartLiveActiviey", so the start leg of the funnel sorted
/// nowhere near the update and end legs it should be read beside. These pin the three names, since
/// nothing else in the app spells the operation out.
@MainActor
struct LiveActivityEventNameTests {

    @Test("Test The Start Events Name The Operation The Way Update And End Do")
    func testTheStartEventsNameTheOperationTheWayUpdateAndEndDo() {
        #expect(LiveActivityManager.Event.startLiveActivityStart.eventName == "LiveActivityMan_StartLiveActivity_Start")
        #expect(LiveActivityManager.Event.startLiveActivitySuccess.eventName == "LiveActivityMan_StartLiveActivity_Success")
        #expect(
            LiveActivityManager.Event.startLiveActivityFail(error: URLError(.unknown)).eventName
                == "LiveActivityMan_StartLiveActivity_Fail"
        )
    }
}

#endif
