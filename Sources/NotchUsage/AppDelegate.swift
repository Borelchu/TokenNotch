import AppKit
import Combine
import DynamicNotchKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = UsageModel()
    private var notch: DynamicNotch<ExpandedView, CompactLeadingView, CompactTrailingView>?
    private var hoverCancellable: AnyCancellable?
    private var pollTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = self.model
        let notch = DynamicNotch(hoverBehavior: .all) {
            ExpandedView(model: model)
        } compactLeading: {
            CompactLeadingView(model: model)
        } compactTrailing: {
            CompactTrailingView(model: model)
        }
        self.notch = notch

        // Compact by default; expand while the pointer is over the notch.
        hoverCancellable = notch.$isHovering
            .removeDuplicates()
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { hovering in
                Task { @MainActor in
                    if hovering {
                        await notch.expand()
                    } else {
                        await notch.compact()
                    }
                }
            }

        pollTask = Task { @MainActor in
            await notch.compact()
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
