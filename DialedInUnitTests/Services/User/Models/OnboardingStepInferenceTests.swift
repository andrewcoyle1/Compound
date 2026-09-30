//
//  OnboardingStepInferenceTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

/// Where onboarding resumes, worked out from the stored profile rather than a saved cursor.
///
/// This is what decides the screen a returning user lands on after quitting part-way through, and
/// it is derived: there is no "last step" field to go stale, only the profile itself. That makes
/// the order of the guards the whole behaviour — get one wrong and a user is either sent back
/// through a step they finished or dropped past one they never did.
///
/// `OnboardingStepRouter` switches on exactly this value, so it is also the list of screens that
/// must stay reachable.
@MainActor
struct OnboardingStepInferenceTests {

    /// A fully onboarded profile, with any field cleared by passing nil for it.
    private func user(
        dateOfBirth: Date? = Date(timeIntervalSince1970: 0),
        gender: Gender? = .male,
        height: Double? = 180,
        weight: Double? = 80,
        exerciseFrequency: ExerciseFrequency? = .daily,
        activityLevel: ActivityLevel? = .active,
        cardioFitness: CardioFitnessLevel? = .intermediate,
        disclaimerVersion: String? = UserModel.currentHealthDisclaimerVersion,
        goalId: String? = "goal-1",
        gymProfileId: String? = "gym-1",
        mesocycleId: String? = "program-1",
        finished: Bool = true
    ) -> UserModel {
        UserModel(
            userId: "user-1",
            submittedDateOfBirth: dateOfBirth,
            submittedGender: gender,
            submittedHeightCentimeters: height,
            submittedWeightKilograms: weight,
            submittedExerciseFrequency: exerciseFrequency,
            submittedDailyActivityLevel: activityLevel,
            submittedCardioFitnessLevel: cardioFitness,
            submittedCurrentGoalId: goalId,
            submittedActiveMesocycleId: mesocycleId,
            submittedFavouriteGymProfileId: gymProfileId,
            didCompleteOnboarding: finished,
            acceptedHealthDisclaimerVersion: disclaimerVersion
        )
    }

    // MARK: - Each step in turn

    /// A brand new account has nothing on it, so it starts at the beginning.
    @Test("Test An Empty Profile Starts At Account Setup")
    func testAnEmptyProfileStartsAtAccountSetup() {
        #expect(UserModel(userId: "user-1").inferredOnboardingStep == .completeAccountSetup)
    }

    @Test("Test An Unfinished Account Resumes At Account Setup")
    func testAnUnfinishedAccountResumesAtAccountSetup() {
        #expect(user(dateOfBirth: nil).inferredOnboardingStep == .completeAccountSetup)
    }

    @Test("Test An Unaccepted Disclaimer Resumes At The Disclaimer")
    func testAnUnacceptedDisclaimerResumesAtTheDisclaimer() {
        #expect(user(disclaimerVersion: nil).inferredOnboardingStep == .healthDisclaimer)
    }

    /// A reissued disclaimer has to be read again. Accepting the previous wording is consent to
    /// that wording and nothing else, so a stale version is treated the same as never having
    /// accepted at all rather than as a permanent pass.
    @Test("Test A Superseded Disclaimer Resumes At The Disclaimer")
    func testASupersededDisclaimerResumesAtTheDisclaimer() {
        #expect(user(disclaimerVersion: "2024.01.01").inferredOnboardingStep == .healthDisclaimer)
    }

    @Test("Test The Current Disclaimer Is Accepted")
    func testTheCurrentDisclaimerIsAccepted() {
        #expect(user(disclaimerVersion: UserModel.currentHealthDisclaimerVersion).inferredOnboardingStep == .complete)
    }

    @Test("Test No Goal Resumes At Goal Setting")
    func testNoGoalResumesAtGoalSetting() {
        #expect(user(goalId: nil).inferredOnboardingStep == .goalSetting)
    }

    @Test("Test No Gym Resumes At Gym Profile Setup")
    func testNoGymResumesAtGymProfileSetup() {
        #expect(user(gymProfileId: nil).inferredOnboardingStep == .gymProfileSetup)
    }

    @Test("Test No Programme Resumes At Training Programme Setup")
    func testNoProgrammeResumesAtTrainingProgrammeSetup() {
        #expect(user(mesocycleId: nil).inferredOnboardingStep == .mesocycleSetup)
    }

    @Test("Test An Unfinished Profile Resumes At Customise Programme")
    func testAnUnfinishedProfileResumesAtCustomiseProgramme() {
        #expect(user(finished: false).inferredOnboardingStep == .customiseProgram)
    }

    @Test("Test A Finished Profile Is Complete")
    func testAFinishedProfileIsComplete() {
        #expect(user().inferredOnboardingStep == .complete)
    }

    // MARK: - The account setup guard

    /// Account setup asks six things and needs all of them. Any one missing sends the user back,
    /// so each is checked on its own — a guard that dropped one would let a profile through with a
    /// hole in it.
    @Test("Test Any Missing Account Detail Returns To Account Setup")
    func testAnyMissingAccountDetailReturnsToAccountSetup() {
        let variants: [(String, UserModel)] = [
            ("date of birth", user(dateOfBirth: nil)),
            ("gender", user(gender: nil)),
            ("height", user(height: nil)),
            ("weight", user(weight: nil)),
            ("exercise frequency", user(exerciseFrequency: nil)),
            ("activity level", user(activityLevel: nil))
        ]

        for (missing, user) in variants {
            #expect(user.inferredOnboardingStep == .completeAccountSetup, "missing \(missing) did not send the user back")
        }
    }

    /// Decision 8c: onboarding no longer asks for cardio fitness, so a profile without it has to
    /// move past account setup. Requiring it sent everyone who joined since back to the start.
    @Test("Test A Profile Without Cardio Fitness Is Not Sent Back")
    func testAProfileWithoutCardioFitnessIsNotSentBack() {
        #expect(user(cardioFitness: nil).inferredOnboardingStep == .complete)
        #expect(user(cardioFitness: nil, disclaimerVersion: nil).inferredOnboardingStep == .healthDisclaimer)
    }

    // MARK: - Order

    /// The disclaimer comes before the goal: a user who has somehow set a goal without accepting it
    /// is still sent to the disclaimer, because that is the one with legal weight.
    @Test("Test The Health Disclaimer Comes Before The Goal")
    func testTheHealthDisclaimerComesBeforeTheGoal() {
        #expect(user(disclaimerVersion: nil, goalId: "goal-1").inferredOnboardingStep == .healthDisclaimer)
    }

    /// Finishing a later step does not skip an earlier one that is still undone.
    @Test("Test A Later Step Does Not Skip An Earlier One")
    func testALaterStepDoesNotSkipAnEarlierOne() {
        // Everything done except the gym, including the programme that comes after it.
        #expect(user(gymProfileId: nil, mesocycleId: "program-1").inferredOnboardingStep == .gymProfileSetup)
    }

    /// Account setup outranks everything: a profile complete in every other respect but missing a
    /// height still goes back to the start.
    @Test("Test Account Setup Outranks The Later Steps")
    func testAccountSetupOutranksTheLaterSteps() {
        #expect(user(height: nil).inferredOnboardingStep == .completeAccountSetup)
    }

    /// The last gate is the flag itself, so everything can be filled in and the user still lands on
    /// the final step until they actually finish it.
    @Test("Test The Completion Flag Is The Last Gate")
    func testTheCompletionFlagIsTheLastGate() {
        var user = user(finished: false)
        #expect(user.inferredOnboardingStep == .customiseProgram)

        user.markDidCompleteOnboarding()

        #expect(user.inferredOnboardingStep == .complete)
    }
}
