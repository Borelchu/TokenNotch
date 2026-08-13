import AppKit
import SwiftUI

// MARK: - Official Codex pet spritesheet

/// The Codex CLI ships terminal pets whose spritesheets live on OpenAI's CDN
/// (the CLI downloads and caches them for its /pet feature). We do the same
/// for the original "Codex" companion instead of bundling the artwork.
///
/// Sheet layout (1536×1872, 192×208 per frame):
///   row 0: idle/waiting (6)   row 1: running-right (8)  row 2: running-left (8)
///   row 3: waving (4)         row 4: jumping (5)        row 5: sad/hurt (8)
///   row 6: thinking (7)       row 7: typing on laptop (6)  row 8: bounce (6)
@MainActor
final class CodexPetSheet: ObservableObject {
    static let shared = CodexPetSheet()

    @Published private(set) var image: NSImage?

    static let frameSize = CGSize(width: 192, height: 208)
    static let columns = 8
    static let rows = 9

    private static let remoteURL =
        URL(string: "https://persistent.oaistatic.com/codex/pets/v1/codex-spritesheet-v4.webp")!

    private init() {
        Task { await load() }
    }

    private func load() async {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NotchUsage", isDirectory: true)
        let file = cacheDir.appendingPathComponent("codex-spritesheet-v4.webp")

        if let cached = NSImage(contentsOf: file) {
            image = cached
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.remoteURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let downloaded = NSImage(data: data)
            else {
                NSLog("NotchUsage: codex pet spritesheet unavailable")
                return
            }
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            try? data.write(to: file)
            image = downloaded
        } catch {
            NSLog("NotchUsage: codex pet download failed: %@", "\(error)")
        }
    }
}

// MARK: - Animated view

struct CodexPetView: View {
    @ObservedObject private var sheet = CodexPetSheet.shared
    let mood: Mood
    let t: TimeInterval
    var scale: CGFloat = 1

    private enum Anim {
        static let idle = (row: 0, count: 6)
        static let runRight = (row: 1, count: 8)
        static let runLeft = (row: 2, count: 8)
        static let sad = (row: 5, count: 8)
        static let typing = (row: 7, count: 6)
    }

    private var patrolPeriod: Double { 6.0 }

    private var patrolPhase: Double {
        let phase = (t / patrolPeriod).truncatingRemainder(dividingBy: 1)
        return abs(phase * 2 - 1) * 2 - 1
    }

    private var anim: (row: Int, count: Int) {
        switch mood {
        case .happy:
            let phase = (t / patrolPeriod).truncatingRemainder(dividingBy: 1)
            return phase < 0.5 ? Anim.runLeft : Anim.runRight
        case .worried: return Anim.typing // heads-down at the laptop
        case .critical: return Anim.sad
        case .sleeping: return Anim.idle
        }
    }

    private var frameIndex: Int {
        if mood == .sleeping { return 1 } // eyes-closed idle frame
        return Int(t * 8).positiveModulo(anim.count)
    }

    private var patrolOffset: CGFloat {
        mood == .happy ? CGFloat(patrolPhase) * 5 : 0
    }

    private var tremble: CGFloat {
        mood == .critical ? CGFloat(sin(t * 40)) * 0.8 : 0
    }

    var body: some View {
        Group {
            if let image = sheet.image {
                spriteFrame(image)
            } else {
                // Drawn stand-in until the official sheet is downloaded
                CodexBotView(mood: mood, t: t, scale: scale)
            }
        }
        .overlay(alignment: .topTrailing) {
            if mood == .worried || mood == .critical { sweatDrop }
            if mood == .sleeping { sleepZs }
        }
        .offset(x: patrolOffset + tremble)
        .frame(width: 30 * scale, height: 18 * scale)
    }

    private func spriteFrame(_ image: NSImage) -> some View {
        let height = 18 * scale
        let unit = height / CodexPetSheet.frameSize.height
        let frameW = CodexPetSheet.frameSize.width * unit
        let frameH = CodexPetSheet.frameSize.height * unit
        return Image(nsImage: image)
            .resizable()
            .interpolation(.none)
            .frame(
                width: frameW * CGFloat(CodexPetSheet.columns),
                height: frameH * CGFloat(CodexPetSheet.rows)
            )
            .offset(
                x: -CGFloat(frameIndex) * frameW,
                y: -CGFloat(anim.row) * frameH
            )
            .frame(width: frameW, height: frameH, alignment: .topLeading)
            .clipped()
            // .clipped() only masks drawing — the full spritesheet stays
            // hit-testable and was extending the hover zone ~9 frames below
            // the notch. Restrict hit geometry to the visible frame.
            .contentShape(Rectangle())
    }

    private var sweatDrop: some View {
        Circle()
            .fill(Color(red: 0.4, green: 0.7, blue: 1.0))
            .frame(width: 2.6, height: 2.6)
            .offset(
                x: 1,
                y: -3 + CGFloat((t * 2).truncatingRemainder(dividingBy: 1)) * 4
            )
    }

    private var sleepZs: some View {
        let phase = (t / 2).truncatingRemainder(dividingBy: 1)
        return Text("z")
            .font(.system(size: 6, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(1 - phase))
            .offset(x: 2, y: -2 - CGFloat(phase) * 5)
    }
}

private extension Int {
    func positiveModulo(_ n: Int) -> Int {
        let r = self % n
        return r >= 0 ? r : r + n
    }
}
