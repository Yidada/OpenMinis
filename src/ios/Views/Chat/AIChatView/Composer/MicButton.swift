//
//  MicButton.swift
//  Minis - chat page (AIChatView)
//
//  The composer's mic button: starts voice input on touch release (finger
//  lift) so a brushing touch does not activate it.
//
//  Map of the AIChatView files: AIChatView/AIChatView.swift.
//

import AVFoundation
import AVKit
import Combine
import GameController
import PhotosUI
import QuickLook
import QuickLook
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WebKit

// MARK: - Mic Button (touch-release activation)

/// Mic button that triggers on touch-release (finger lift) to avoid accidental activation.
/// Press highlight is provided via GestureState.
struct MicButton: View {
    @ObservedObject var speechManager: SpeechRecognitionManager
    @Binding var inputFocused: Bool
    /// Opens the voice-input (VAD) panel. The mic button no longer drives the
    /// in-bar SFSpeech live dictation directly — the panel (with the configured
    /// ASR provider, or the offline System fallback) is the single voice entry
    /// point. The SpeechRecognitionManager path stays in place but is no longer
    /// triggered from here.
    var onTap: () -> Void = {}
    /// True while inline voice mode is active — the button flips to a "T" glyph
    /// that switches back to text input.
    var isVoiceActive: Bool = false
    /// [T-composer-hold-to-talk] Press-and-hold talks straight from the
    /// composer: the threshold crossing switches the composer into voice mode
    /// AND starts capture in one motion, so the user never has to lift the
    /// finger and press the panel's white mic for a second time. Only armed in
    /// text mode — in voice mode the glyph is the "back to keyboard" control
    /// and the panel's own mic already answers a hold.
    var onHoldBegan: () -> Void = {}
    /// Finger lifted (or the press was cancelled). `cancelled` is true when the
    /// finger had slid up past the cancel offset.
    var onHoldEnded: (_ cancelled: Bool) -> Void = { _ in }
    /// Press feedback for the custom-gesture button.
    @State private var micPressed = false
    // [T-composer-hold-to-talk] Hold bookkeeping. `holdActive` flips true when
    // the press outlives `holdThreshold`; from then on the release ends the
    // recording instead of running the tap action.
    @State private var holdActive = false
    @State private var cancelArmed = false
    @State private var pressBeganAt: Date?
    @State private var holdWorkItem: DispatchWorkItem?

    private static let diameter: CGFloat = 34
    /// Same 150 ms / 60 pt contract as the panel's mic, so the two pushes feel
    /// like one gesture language.
    private static let holdThreshold: TimeInterval = 0.15
    private static let cancelOffset: CGFloat = 60

    var body: some View {
        // NOT a Button: SwiftUI's Button has a generous system touch-slop / touch-
        // up tolerance that fires when the finger lifts slightly outside, or moves
        // a little during a scroll/drag — which made this toggle very easy to
        // mis-tap. We use a DragGesture(minimumDistance: 0) and only activate when
        // BOTH the press and release land inside the circle AND movement is tiny.
        // In voice mode: a keyboard glyph = switch back to text input. The keyboard
        // glyph is wider than the mic, so render it ~4pt smaller for parity.
        Image(systemName: isVoiceActive ? "keyboard" : "mic")
            .font(.system(size: isVoiceActive ? 15 : 18, weight: .medium))
            .foregroundStyle(cancelArmed ? Color.red : ChatColors.secondaryText)
            .frame(width: Self.diameter, height: Self.diameter)
            .background(ChatColors.inputIconBg)
            .clipShape(Circle())
            .overlay(Circle().stroke(cancelArmed ? Color.red : ChatColors.inputIconBorder,
                                     lineWidth: 0.5))
            .scaleEffect(micPressed ? 0.9 : 1.0)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        micPressed = Self.isInside(value.location)
                        // [T-composer-hold-to-talk] First callback of a press:
                        // arm the threshold. From text mode only — voice mode
                        // keeps the old toggle semantics.
                        if pressBeganAt == nil, !isVoiceActive {
                            pressBeganAt = Date()
                            // Drop any state a cancelled press left behind.
                            holdActive = false
                            cancelArmed = false
                            let work = DispatchWorkItem {
                                guard pressBeganAt != nil else { return }
                                holdActive = true
                                cancelArmed = false
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onHoldBegan()
                            }
                            holdWorkItem = work
                            DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdThreshold,
                                                          execute: work)
                            return
                        }
                        guard holdActive else { return }
                        let shouldCancel = value.translation.height < -Self.cancelOffset
                        if shouldCancel != cancelArmed {
                            cancelArmed = shouldCancel
                            UIImpactFeedbackGenerator(style: shouldCancel ? .medium : .light)
                                .impactOccurred()
                        }
                    }
                    .onEnded { value in
                        holdWorkItem?.cancel()
                        holdWorkItem = nil
                        let wasHolding = holdActive
                        holdActive = false
                        pressBeganAt = nil
                        let cancelled = value.translation.height < -Self.cancelOffset
                        cancelArmed = false
                        micPressed = false
                        if wasHolding {
                            onHoldEnded(cancelled)
                            return
                        }
                        // Released before the threshold: the original tap.
                        let started = Self.isInside(value.startLocation)
                        let ended = Self.isInside(value.location)
                        let moved = hypot(value.translation.width, value.translation.height)
                        guard started, ended, moved < 10 else { return }
                        inputFocused = false
                        onTap()
                    }
            )
            .accessibilityHint(isVoiceActive
                ? Text("Switches back to text input", comment: "Mic button exits voice mode")
                : Text("Tap to open voice input, or hold to talk", comment: "Mic button hint: tap opens the panel, hold talks"))
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(isVoiceActive
                ? Text("Switch to text input", comment: "Mic button exits voice mode")
                : Text("Voice input", comment: "Mic button opens voice panel"))
    }

    /// Whether a point (in the button's local space) is within the visible circle.
    private static func isInside(_ p: CGPoint) -> Bool {
        let r = diameter / 2
        let dx = p.x - r, dy = p.y - r
        return (dx * dx + dy * dy) <= r * r
    }
}
