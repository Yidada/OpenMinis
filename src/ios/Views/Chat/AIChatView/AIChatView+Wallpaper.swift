//
//  AIChatView+Wallpaper.swift
//  Minis - chat page (AIChatView)
//
//  Tech wallpaper behind the transcript.
//
//  Map of the AIChatView files: AIChatView/AIChatView.swift.
//

import SwiftUI
import UIKit

/// Full-bleed wallpaper drawn behind the message list.
///
/// The artwork is procedural (dark/light pair, see `ChatWallpaper.imageset`):
/// circuit traces up top, a receding floor grid at the bottom, and a flat,
/// quiet middle where most of the conversation actually sits.
///
/// A vertical scrim fades the image out under the navigation bar and the
/// composer so transcript text never sits on a busy pixel. The message list
/// itself draws nothing behind its cells (both it and its parent are
/// black-transparent), which is why the fill lives here.
///
/// If the artwork is missing from the bundle this falls back to a painted
/// gradient rather than the plain fill - a silent blank page is
/// indistinguishable from "the build did not contain the change".
struct ChatWallpaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ChatColors.background
            if let artwork = UIImage(named: "ChatWallpaper") {
                GeometryReader { proxy in
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .overlay { scrim }
                }
                .ignoresSafeArea()
            } else {
                fallback
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Deliberately not the artwork: a flat two-stop gradient, so a missing
    /// asset reads as "intentional but wrong" instead of "nothing happened".
    private var fallback: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.02, green: 0.04, blue: 0.09), Color(red: 0.07, green: 0.13, blue: 0.26)]
                : [Color(red: 0.94, green: 0.96, blue: 1.00), Color(red: 0.80, green: 0.86, blue: 0.96)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
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
            .init(color: Color.white.opacity(0.72), location: 0.00),
            .init(color: Color.white.opacity(0.34), location: 0.16),
            .init(color: Color.white.opacity(0.20), location: 0.44),
            .init(color: Color.white.opacity(0.36), location: 0.76),
            .init(color: Color.white.opacity(0.66), location: 1.00),
        ]
    }
}
