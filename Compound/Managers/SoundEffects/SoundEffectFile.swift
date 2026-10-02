//
//  SoundEffectFile.swift
//  ArchitectureProject
//
//  Created by Nick Sarno on 1/12/25.
//
import Foundation
import AudioToolbox

// Use this to register sound effects in the application.
// Add the file to the bundle (ie. in SoundEffectFiles folder) and create an enum case!

enum SoundEffectFile: String, Equatable {
    case sample
    /// Played when a rest timer runs out, if `WorkoutSettings.restTimerPlaySound` is on. The audio
    /// file is not in the bundle yet, so `systemSoundStandIn` plays in its place.
    case restComplete

    var fileName: String {
        switch self {
        case .sample:
            return "Sample.wav"
        case .restComplete:
            return "RestComplete.wav"
        }
    }
    
    /// Force-unwrapped `Bundle.main.path(forResource:)` before. `Sample.wav` is not in the bundle —
    /// it is a leftover from the template this project started from — so the one call that would
    /// have played a sound would have crashed instead. Optional, so a missing file is silence.
    /// A system sound played while the file is missing. System sounds follow the silent switch and
    /// mix with whatever the person is listening to, which is how the file will be played too.
    var systemSoundStandIn: SystemSoundID? {
        switch self {
        
        // Pending: Add RestComplete.wav to the bundle; `url` then finds it and this stand-in stops playing.
        case .restComplete: return 1007
        case .sample: return nil
        }
    }

    var url: URL? {
        guard let path = Bundle.main.path(forResource: fileName, ofType: nil) else { return nil }
        return URL(fileURLWithPath: path)
    }
}
