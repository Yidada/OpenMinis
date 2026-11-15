//
//  WeChatComposer.swift
//  Minis - chat page (AIChatView)
//
//  WeChat-style composer: single row [voice] [field / hold-to-talk] [+ | 发送],
//  plus the full-screen hold-to-talk overlay (dimmed chat, mic + waveform,
//  cancel / convert buttons) and the flat bar chrome that replaces the floating
//  glass card.
//
//  WeChatComposerStyle.enabled is the single switch. Flip it to false and the
//  pre-existing composer (floating card, two rows, inline voice panel) comes
//  back unchanged — every branch below is gated on it.
//
//  Map of the AIChatView files: AIChatView/AIChatView.swift.
//

import SwiftUI
import UIKit

// MARK: - Style switch

enum WeChatComposerStyle {
    /// Master switch for the WeChat-style composer.
    static let enabled = true

    /// WeChat brand tokens (taken from the shipping app, not adapted).
    static let green = Color(red: 7.0 / 255.0, green: 193.0 / 255.0, blue: 96.0 / 255.0)
    static let cancelRed = Color(red: 250.0 / 255.0, green: 81.0 / 255.0, blue: 81.0 / 255.0)

    /// Bar background: #EDEDED light, #1E1E1E dark.
    static func barBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 30.0 / 255.0, green: 30.0 / 255.0, blue: 30.0 / 255.0)
            : Color(red: 237.0 / 255.0, green: 237.0 / 255.0, blue: 237.0 / 255.0)
    }

    /// Field background: #FFFFFF light, #2C2C2E dark.
    static func fieldBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 44.0 / 255.0, green: 44.0 / 255.0, blue: 46.0 / 255.0)
            : .white
    }

    /// Same value as a dynamic colour, for call sites outside a view body.
    static let fieldBackgroundDynamic = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 44.0 / 255.0, green: 44.0 / 255.0, blue: 46.0 / 255.0, alpha: 1)
            : .white
    })

    static func hairline(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.black.opacity(0.6)
            : Color(red: 214.0 / 255.0, green: 214.0 / 255.0, blue: 214.0 / 255.0)
    }

    /// Field height / radius from the WeChat composer.
    static let fieldHeight: CGFloat = 36
    static let fieldCorner: CGFloat = 4
    /// Long-press threshold before capture starts (same 180 ms used by the
    /// previous composer mic, so the feel does not change).
    static let holdThreshold: TimeInterval = 0.18
    /// Slide distance that arms "取消".
    static let cancelOffset: CGFloat = 60
}

// MARK: - Hold state

/// Shared between the hold bar (gesture owner) and the full-screen overlay.
/// Kept as its own object so neither view has to live inside AIChatView's body
/// type, which is already at the demangler's limit.
final class WeChatVoiceHoldState: ObservableObject {
    /// Finger is down past the threshold, capture is running.
    @Published var isHolding = false
    /// Finger has slid into the cancel zone.
    @Published var isCancelled = false
}

// MARK: - Flat bar chrome

/// Replaces `ComposerSurface` in WeChat mode: an edge-to-edge bar with a
/// hairline top border instead of the floating rounded glass card.
struct WeChatComposerSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(WeChatComposerStyle.barBackground(colorScheme))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(WeChatComposerStyle.hairline(colorScheme))
                    .frame(height: 0.5)
            }
    }
}

/// Chooses between the WeChat flat bar and the original floating card, so the
/// composer's modifier chain stays one line and the old surface is untouched
/// when the switch is off.
struct ComposerChrome: ViewModifier {
    func body(content: Content) -> some View {
        if WeChatComposerStyle.enabled {
            content.modifier(WeChatComposerSurface())
        } else {
            content.modifier(ComposerSurface())
        }
    }
}

// MARK: - Voice key (left of the field)

/// WeChat's left-hand key: waveform in text mode, keyboard in voice mode.
struct WeChatVoiceKeyButton: View {
    let isVoiceMode: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isVoiceMode ? "keyboard" : "waveform.circle")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color.primary)
                .frame(width: 30, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isVoiceMode
            ? Text("Switch to keyboard", comment: "Voice key: leave voice mode")
            : Text("Voice input", comment: "Voice key: enter voice mode"))
    }
}

// MARK: - "按住 说话"

/// The full-width hold target of WeChat's voice mode. Owns the press
/// threshold and the cancel slide; the engine work is delegated to
/// VoiceInputViewModel by the caller.
struct WeChatHoldToTalkBar: View {
    @ObservedObject var hold: WeChatVoiceHoldState
    let onBegan: () -> Void
    let onEnded: (_ cancelled: Bool) -> Void

    @State private var didBegin = false
    @State private var pending: DispatchWorkItem?
    @State private var pressed = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: WeChatComposerStyle.fieldCorner)
    }

    var body: some View {
        Text("按住 说话", comment: "WeChat-style hold-to-talk button")
            .font(.system(size: 17))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: WeChatComposerStyle.fieldHeight)
            .background(shape.fill(pressed
                ? Color(uiColor: .systemGray4)
                : Color(uiColor: .secondarySystemBackground)))
            .contentShape(shape)
            .gesture(drag)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("Hold to talk, release to convert to text", comment: "Voice mode: hold-to-talk hint"))
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !didBegin {
                    // First callback of a press: arm the threshold.
                    guard pending == nil else { return }
                    pressed = true
                    let work = DispatchWorkItem {
                        guard pending != nil else { return }
                        didBegin = true
                        withAnimation(.easeOut(duration: 0.15)) { hold.isHolding = true }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onBegan()
                    }
                    pending = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + WeChatComposerStyle.holdThreshold,
                                                  execute: work)
                    return
                }
                let shouldCancel = value.translation.height < -WeChatComposerStyle.cancelOffset
                if shouldCancel != hold.isCancelled {
                    withAnimation(.easeOut(duration: 0.12)) { hold.isCancelled = shouldCancel }
                    UIImpactFeedbackGenerator(style: shouldCancel ? .medium : .light).impactOccurred()
                }
            }
            .onEnded { value in
                pending?.cancel()
                pending = nil
                pressed = false
                guard didBegin else { return }
                didBegin = false
                let cancelled = value.translation.height < -WeChatComposerStyle.cancelOffset
                withAnimation(.easeOut(duration: 0.15)) {
                    hold.isHolding = false
                    hold.isCancelled = false
                }
                onEnded(cancelled)
            }
    }
}

// MARK: - Send capsule

/// WeChat's green 发送 button, shown in place of "+" once there is text.
struct WeChatSendCapsule: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Send", comment: "Composer send button")
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .frame(width: 54, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(enabled ? WeChatComposerStyle.green : Color(uiColor: .systemGray4))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text("Send", comment: "Composer send button"))
    }
}

// MARK: - Full-screen hold overlay

/// Dimmed chat + mic/waveform + 取消/转文字 discs, exactly the layout WeChat
/// shows while 按住说话 is held. Purely visual: `allowsHitTesting(false)` so the
/// finger that started the gesture on the bar keeps owning it.
struct WeChatVoiceOverlay: View {
    @ObservedObject var hold: WeChatVoiceHoldState
    @ObservedObject var voiceVM: VoiceInputViewModel

    private var levels: [Float] {
        Array(voiceVM.waveformLevels.suffix(4))
    }

    var body: some View {
        if hold.isHolding {
            ZStack {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "mic")
                            .font(.system(size: 46, weight: .light))
                            .foregroundStyle(.white)
                        HStack(alignment: .center, spacing: 3) {
                            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                                Capsule()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 3,
                                           height: 6 + CGFloat(max(0, min(1, level))) * 26)
                            }
                        }
                        .frame(height: 32)
                    }

                    Text(hold.isCancelled
                         ? AppLocalized("松开手指，取消", comment: "Hold-to-talk overlay hint, cancel armed")
                         : AppLocalized("松开手指，转成文字", comment: "Hold-to-talk overlay hint"))
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .padding(.top, 10)

                    HStack(spacing: 88) {
                        disc(symbol: "arrow.uturn.backward",
                             label: Text("Cancel", comment: "Hold-to-talk: discard the recording"),
                             background: hold.isCancelled ? WeChatComposerStyle.cancelRed : .white,
                             foreground: hold.isCancelled ? .white : .black,
                             hot: hold.isCancelled)
                        disc(symbol: "text.alignleft",
                             label: Text("To text", comment: "Hold-to-talk: convert speech to text"),
                             background: WeChatComposerStyle.green,
                             foreground: .white,
                             hot: !hold.isCancelled)
                    }
                    .padding(.top, 46)
                }
                .padding(.bottom, 120)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func disc(symbol: String,
                      label: Text,
                      background: Color,
                      foreground: Color,
                      hot: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(background)
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(foreground)
            }
            .frame(width: 64, height: 64)
            .scaleEffect(hot ? 1.06 : 1.0)

            label
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.92))
        }
    }
}
