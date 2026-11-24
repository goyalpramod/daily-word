import SwiftUI
import AppKit
import AVFoundation

// Renders App Store screenshots and app previews from the app's real views.
// Run via scripts/render_store_assets.sh

extension WordLibrary {
    static var store: WordLibrary!
}

@MainActor
func cgImage<V: View>(_ view: V, size: CGSize, scale: CGFloat) -> CGImage {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = scale
    renderer.isOpaque = true
    guard let image = renderer.cgImage else { fatalError("render failed") }
    return image
}

/// App Store Connect rejects screenshots with an alpha channel, so flatten to RGB.
func writePNG(_ image: CGImage, to path: String) {
    let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("  \(path)  \(image.width)×\(image.height)")
}

@MainActor
func screenshot<V: View>(_ view: V, size: CGSize, scale: CGFloat, to path: String) {
    writePNG(cgImage(view, size: size, scale: scale), to: path)
}

@MainActor
func video(size: CGSize, scale: CGFloat, seconds: Double, to path: String, frame: (Double) -> AnyView) {
    let fps = 30
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.removeItem(at: url)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let width = Int(size.width * scale), height = Int(size.height * scale)
    let writer = try! AVAssetWriter(outputURL: url, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 10_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoExpectedSourceFrameRateKey: fps,
        ],
    ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
    ])
    writer.add(input)
    guard writer.startWriting() else { fatalError("Can't write \(path): \(String(describing: writer.error))") }
    writer.startSession(atSourceTime: .zero)

    let total = Int(seconds * Double(fps))
    for i in 0..<total {
        let image = cgImage(frame(Double(i) / Double(fps)), size: size, scale: scale)
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
        let pb = buffer!
        CVPixelBufferLockBaseAddress(pb, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(pb, [])
        while !input.isReadyForMoreMediaData { usleep(2000) }
        adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps)))
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    print("  \(path)  \(width)×\(height)  \(seconds)s  \(writer.status == .completed ? "ok" : "FAILED \(String(describing: writer.error))")")
}

func crossfade(_ t: Double, at time: Double, duration: Double = 0.6) -> Double {
    phase(t, time - duration / 2, time + duration / 2)
}

@main
struct Render {
    @MainActor static func main() {
        setvbuf(stdout, nil, _IOLBF, 0)
        let args = CommandLine.arguments
        let resources = args[1], out = args[2]
        WordLibrary.store = WordLibrary(bundle: Bundle(path: resources)!)
        let w = WordLibrary.store.byID
        let today = w["wistful"]!, origin = w["quarantine"]!, quiz = w["candid"]!, quiz2 = w["ephemeral"]!
        let icon = NSImage(contentsOfFile: "\(resources)/Assets.xcassets/AppIcon.appiconset/icon-1024.png")!

        // Scrolling the origin screen down to "Origin" (measured for these entries).
        let originScrollPhone: CGFloat = 255
        let originScrollPad: CGFloat = 0

        let captions: [(String, String)] = [
            ("One new word,\nevery day.", "Words for feelings, people and conversation, with how to say them."),
            ("Know where every\nword comes from.", "Origins, roots, and the words that share them."),
            ("Practice right from\nyour home screen.", "Tap to see the meaning. Tell it whether you knew it."),
            ("Words come back\nbefore you forget.", "Miss one and it returns tomorrow. Know it and it waits longer."),
            ("Add any word\nyou come across.", "Look it up, adjust it, and it joins your reviews."),
        ]

        // MARK: iPhone 6.9" — 1320 × 2868
        print("iPhone 6.9\"")
        let phone = CGSize(width: 402, height: 874)
        let phoneCanvas = CGSize(width: 440, height: 956)
        func phoneFrame<S: View>(_ i: Int, dark: Bool = false, @ViewBuilder _ screen: () -> S) -> some View {
            StoreFrame(canvas: phoneCanvas, title: captions[i].0, subtitle: captions[i].1, dark: dark,
                       screenSize: phone, screenScale: 0.9, screenTop: 268, screen: screen)
        }
        let phoneShots: [(String, AnyView)] = [
            ("01-today", AnyView(phoneFrame(0) { DeviceScreen(size: phone, tab: nil) { TodayContent(entry: today) } })),
            ("02-origin", AnyView(phoneFrame(1) { DeviceScreen(size: phone, tab: nil) { TodayContent(entry: origin, scroll: originScrollPhone) } })),
            ("03-widgets", AnyView(phoneFrame(2) { DeviceScreen(size: phone, tab: nil, background: AnyView(wallpaper)) { WidgetsContent(today: today, quiz: quiz) } })),
            ("04-review", AnyView(phoneFrame(3, dark: true) { DeviceScreen(size: phone, dark: true, tab: nil) { ReviewContent(entry: quiz, dark: true, bottomInset: 150) } })),
            ("05-add", AnyView(phoneFrame(4) { DeviceScreen(size: phone, tab: nil) { AddContent() } })),
        ]
        for (name, view) in phoneShots {
            screenshot(view, size: phoneCanvas, scale: 3, to: "\(out)/Screenshots/iphone-6.9/\(name).png")
        }

        // MARK: iPad 13" — 2064 × 2752
        print("iPad 13\"")
        let pad = CGSize(width: 834, height: 1112)
        let padCanvas = CGSize(width: 1032, height: 1376)
        func padFrame<S: View>(_ i: Int, dark: Bool = false, @ViewBuilder _ screen: () -> S) -> some View {
            StoreFrame(canvas: padCanvas, title: captions[i].0.replacingOccurrences(of: "\n", with: " "), subtitle: captions[i].1, dark: dark,
                       screenSize: pad, screenScale: 0.98, screenTop: 300, cornerRadius: 36, titleSize: 52, margin: 104, topPadding: 110,
                       screen: screen)
        }
        let padShots: [(String, AnyView)] = [
            ("01-today", AnyView(padFrame(0) { DeviceScreen(size: pad, tab: nil, island: false) { TodayContent(entry: today, topInset: 90) } })),
            ("02-origin", AnyView(padFrame(1) { DeviceScreen(size: pad, tab: nil, island: false) { TodayContent(entry: origin, scroll: originScrollPad, topInset: 90) } })),
            ("03-widgets", AnyView(padFrame(2) { DeviceScreen(size: pad, tab: nil, island: false, background: AnyView(wallpaper)) { WidgetsContent(today: today, quiz: quiz, topInset: 120) } })),
            ("04-review", AnyView(padFrame(3, dark: true) { DeviceScreen(size: pad, dark: true, tab: nil, island: false) { ReviewContent(entry: quiz, dark: true, bottomInset: 330) } })),
            ("05-add", AnyView(padFrame(4) { DeviceScreen(size: pad, tab: nil, island: false) { AddContent() } })),
        ]
        for (name, view) in padShots {
            screenshot(view, size: padCanvas, scale: 2, to: "\(out)/Screenshots/ipad-13/\(name).png")
        }

        // MARK: Mac — 2880 × 1800
        print("Mac")
        let macCanvas = CGSize(width: 1440, height: 900)
        let window = CGSize(width: 1120, height: 760)
        func macFrame<S: View>(_ i: Int, dark: Bool = false, @ViewBuilder _ screen: () -> S) -> some View {
            StoreFrame(canvas: macCanvas, title: captions[i].0.replacingOccurrences(of: "\n", with: " "), subtitle: captions[i].1, dark: dark,
                       screenSize: window, screenScale: 1, screenTop: 230, cornerRadius: 14, titleSize: 46, margin: 160, topPadding: 72,
                       screen: screen)
        }
        let desktop = CGSize(width: 1120, height: 760)
        let macShots: [(String, AnyView)] = [
            ("01-today", AnyView(macFrame(0) { MacWindow(size: window) { TodayContent(entry: today, topInset: 40) } })),
            ("02-origin", AnyView(macFrame(1) { MacWindow(size: window) { TodayContent(entry: origin, scroll: 300, topInset: 40) } })),
            ("03-widgets", AnyView(macFrame(2) {
                ZStack { wallpaper; WidgetsContent(today: today, quiz: quiz, topInset: 110) }
                    .frame(width: desktop.width, height: desktop.height)
            })),
            ("04-review", AnyView(macFrame(3, dark: true) { MacWindow(size: window, dark: true, tab: 1) { ReviewContent(entry: quiz, dark: true, bottomInset: 170, topInset: 16) } })),
        ]
        for (name, view) in macShots {
            screenshot(view, size: macCanvas, scale: 2, to: "\(out)/Screenshots/mac/\(name).png")
        }

        guard !args.contains("--no-video") else { return }

        // MARK: App previews
        // Timeline (seconds): Today appears → scrolls to its origin → widgets on the
        // home screen (tap, reveal, grade) → a review session → end card.
        print("Previews")
        func storyboard(_ t: Double, size: CGSize, dark: Bool, mac: Bool, scrollTo: CGFloat) -> AnyView {
            func device<C: View>(tab: Int?, dark d: Bool = false, bg: AnyView? = nil, @ViewBuilder _ c: () -> C) -> AnyView {
                if mac {
                    if bg != nil { return AnyView(ZStack { wallpaper; c() }.frame(width: size.width, height: size.height)) }
                    return AnyView(ZStack { Color(white: d ? 0 : 0.94); MacWindow(size: CGSize(width: size.width - 160, height: size.height - 120), dark: d, tab: tab ?? 0) { c() } }
                        .frame(width: size.width, height: size.height))
                }
                return AnyView(DeviceScreen(size: size, dark: d, tab: tab, background: bg) { c() })
            }
            let top: CGFloat = mac ? 40 : 76
            // Scene 1: Today (0–10s)
            let scene1 = device(tab: 0) {
                TodayContent(entry: today, scroll: scrollTo * CGFloat(phase(t, 4.5, 7.5)), topInset: top, appear: phase(t, 0.2, 1.4))
            }
            // Scene 2: Widgets (10–15s)
            let scene2 = device(tab: nil, bg: AnyView(wallpaper)) {
                WidgetsContent(today: today, quiz: quiz, answer: phase(t, 11.8, 12.3), pressed: phase(t, 13.6, 13.8) * (1 - phase(t, 14.0, 14.2)), topInset: mac ? 110 : 86)
            }
            // Scene 3: Review session (15–21s), two cards
            let secondCard = t >= 18.6
            let reviewEntry = secondCard ? quiz2 : quiz
            let revealed = secondCard ? phase(t, 19.4, 19.8) : phase(t, 16.0, 16.4)
            let pressed = secondCard ? 0 : phase(t, 17.8, 18.0) * (1 - phase(t, 18.2, 18.4))
            let progress = secondCard ? 0.66 : 0.33
            // Dip to blank and back while the next card comes in.
            let cardSwap = secondCard ? 1 - phase(t, 18.6, 18.9) : phase(t, 18.3, 18.6)
            let scene3 = device(tab: 1, dark: dark) {
                ReviewContent(entry: reviewEntry, dark: dark, progress: progress, revealed: revealed, pressed: pressed,
                              bottomInset: mac ? 60 : 110, topInset: mac ? 16 : 64)
                    .opacity(1 - cardSwap)
            }
            let end = AnyView(EndCard(icon: icon).frame(width: size.width, height: size.height))

            let a2 = crossfade(t, at: 10), a3 = crossfade(t, at: 15), a4 = crossfade(t, at: 21.5)
            return AnyView(ZStack {
                scene1.opacity(1 - a2)
                scene2.opacity(a2 * (1 - a3))
                scene3.opacity(a3 * (1 - a4))
                end.opacity(a4)
            }.frame(width: size.width, height: size.height))
        }

        // iPhone 6.9" app preview: 886 × 1920
        let previewPhone = CGSize(width: 443, height: 960)
        video(size: previewPhone, scale: 2, seconds: 25, to: "\(out)/Previews/iphone-6.9-raw.mp4") { t in
            storyboard(t, size: previewPhone, dark: true, mac: false, scrollTo: 360)
        }
        // iPad 13" app preview: 1200 × 1600
        let previewPad = CGSize(width: 600, height: 800)
        video(size: previewPad, scale: 2, seconds: 25, to: "\(out)/Previews/ipad-13-raw.mp4") { t in
            storyboard(t, size: previewPad, dark: true, mac: false, scrollTo: 300)
        }
        // Mac app preview: 1920 × 1080
        let previewMac = CGSize(width: 1920, height: 1080)
        video(size: previewMac, scale: 1, seconds: 25, to: "\(out)/Previews/mac-raw.mp4") { t in
            storyboard(t, size: previewMac, dark: true, mac: true, scrollTo: 300)
        }
    }
}
