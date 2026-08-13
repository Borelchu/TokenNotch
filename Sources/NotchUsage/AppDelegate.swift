import AppKit
import Combine
import DynamicNotchKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = UsageModel()
    private let hoverIntent = HoverIntent()
    private var notch: DynamicNotch<ExpandedView, CompactLeadingView, CompactTrailingView>?
    private var expandCancellable: AnyCancellable?
    private var collapseCancellable: AnyCancellable?
    private var pollTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = self.model
        let hoverIntent = self.hoverIntent
        let notch = DynamicNotch(hoverBehavior: .all) {
            ExpandedView(model: model)
        } compactLeading: {
            CompactLeadingView(model: model, hoverIntent: hoverIntent)
        } compactTrailing: {
            CompactTrailingView(model: model, hoverIntent: hoverIntent)
        }
        self.notch = notch

        // NOTCH_DEMO=expand pins the expanded panel open (used for README captures).
        let demoExpand = ProcessInfo.processInfo.environment["NOTCH_DEMO"] == "expand"

        if !demoExpand {
            // Expand only from the character/percent areas — DynamicNotchKit's
            // own isHovering also covers the bare notch middle, which made the
            // trigger zone far too big. The short debounce filters drive-bys.
            expandCancellable = hoverIntent.$overCompactContent
                .removeDuplicates()
                .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
                .sink { over in
                    guard over else { return }
                    Task { @MainActor in
                        await notch.expand()
                    }
                }

            // Collapse when the pointer leaves the whole panel.
            collapseCancellable = notch.$isHovering
                .removeDuplicates()
                .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
                .sink { hovering in
                    guard !hovering else { return }
                    Task { @MainActor in
                        await notch.compact()
                    }
                }
        }

        pollTask = Task { @MainActor in
            if demoExpand {
                await notch.expand()
            } else {
                await notch.compact()
            }
            while !Task.isCancelled {
                await model.refresh()
                // 5-minute floor: the Claude usage endpoint rate-limits
                // anything more frequent (sticky ~10 min 429 once tripped).
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTask?.cancel()
    }
}
