//
//  AIChatView+Wallpaper.swift
//  Minis - chat page (AIChatView)
//
//  Tech wallpaper behind the transcript.
//
//  Map of the AIChatView files: AIChatView/AIChatView.swift.
//

import SwiftUI

/// Full-bleed wallpaper drawn behind the message list.
///
/// The artwork is procedural (dark/light pair, see `ChatWallpaper.imageset`):
/// circuit traces up top, a receding floor grid at the bottom, and a flat,
/// quiet middle where most of the conversation actually sits.
///
/// Two things keep the transcript readable on top of it:
/// 1. a vertical scrim that fades the image out under the navigation bar and
///    the composer, and
/// 2. an opt-out for Reduce Transparency, which falls back to the plain
///    `ChatColors.background` fill.
///
/// The view never takes touches: it is decoration, so hit testing and
/// accessibility are both off.
struct ChatWallpaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            ChatColors.background
            if !reduceTransparency {
                GeometryReader { proxy in
                    Image("ChatWallpaper")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .overlay { scrim }
                }
                .ignoresSafeArea()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var scrim: some View {
        LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    private var stops: [Gradient.Stop] {
        if colorScheme == .dark {
            return [
                .init(color: Color(white: 0.02).opacity(0.74), location: 0.00),
                .init(color: Color(white: 0.02).opacity(0.34), location: 0.16),
                .init(color: Color(white: 0.02).opacity(0.18), location: 0.44),
                .init(color: Color(white: 0.02).opacity(0.34), location: 0.76),
                .init(color: Color(white: 0.02).opacity(0.62), location: 1.00),
            ]
        }
        return [
            .init(color: Color.white.opacity(0.82), location: 0.00),
            .init(color: Color.white.opacity(0.50), location: 0.16),
            .init(color: Color.white.opacity(0.36), location: 0.44),
            .init(color: Color.white.opacity(0.50), location: 0.76),
            .init(color: Color.white.opacity(0.74), location: 1.00),
        ]
    }
}
