//
//  SwiftfulSoundEffects+Alias.swift
//  ArchitectureProject
//
//  Created by Nick Sarno on 1/12/25.
//

import SwiftfulSoundEffects
import AVFoundation
import AudioToolbox

typealias SoundEffectManager = SwiftfulSoundEffects.SoundEffectManager

extension SoundEffectLogType {
    
    var type: LogType {
        switch self {
        case .info:
            return .info
        case .analytic:
            return .analytic
        case .warning:
            return .warning
        case .severe:
            return .severe
        }
    }
    
}
extension LogManager: @retroactive SoundEffectLogger {
    
    public func trackEvent(event: any SoundEffectLogEvent) {
        trackEvent(eventName: event.eventName, parameters: event.parameters, type: event.type.type)
    }
    
}

extension CoreInteractor {
    // MARK: Sound Effects

    func prepareSoundEffect(sound: SoundEffectFile, simultaneousPlayers: Int = 1) {
        guard let url = sound.url else { return }
        Task {
            await soundEffectManager.prepare(url: url, simultaneousPlayers: simultaneousPlayers, volume: 1)
        }
    }

    func tearDownSoundEffect(sound: SoundEffectFile) {
        guard let url = sound.url else { return }
        Task {
            await soundEffectManager.tearDown(url: url)
        }
    }

    func playSoundEffect(sound: SoundEffectFile) {
        guard let url = sound.url else {
            if let standIn = sound.systemSoundStandIn { AudioServicesPlaySystemSound(standIn) }
            return
        }
        // Ambient: mixes with the person's music instead of stopping it, and stays quiet with the
        // silent switch on. The player would otherwise run under the default session, which
        // silences other audio.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        Task {
            await soundEffectManager.play(url: url)
        }
    }

}
