import SwiftUI
import AppKit

@main
struct SangtaeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: NSPanel!
    var globalClickMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Create Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let iconName = "chevron.up"
            if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Sangtae") {
                button.image = image
            } else {
                button.title = "Sangtae" // Fallback if icon missing
            }
            button.action = #selector(togglePanel)
            button.target = self
        }
        
        // 2. Create Panel (Draggable, Floating)
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 530, height: 200), // Initial dummy size
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        
        // 3. Configure Panel
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true // Key for dragging!
        panel.backgroundColor = .clear
        panel.hasShadow = true
        
        // 4. Set Content
        let hostingController = NSHostingController(rootView: SangtaeView())
        panel.contentViewController = hostingController
        
        // Resize to fit content
        panel.setContentSize(hostingController.view.fittingSize)
        
        // 5. Auto-save position
        panel.setFrameAutosaveName("SangtaeWindowPosition")
        
        // 6. Focus handling
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    @objc func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else {
            openPanel()
        }
    }
    
    func openPanel() {
        // Recalculate size in case content changed (dynamic height)
        if let contentController = panel.contentViewController {
            let size = contentController.view.fittingSize
            if size.height > 0 && size.width > 0 {
                 panel.setContentSize(size)
            }
        }
        
        // If no saved position, position at top-center
        if !panel.setFrameUsingName("MoleMonitorWindowPosition") {
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let panelSize = panel.frame.size
                
                let x = screenRect.midX - (panelSize.width / 2)
                let y = screenRect.maxY - panelSize.height - 20 // 20px padding from top
                
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                panel.center()
            }
        }
        
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Add global monitor to close on outside click
        if globalClickMonitor == nil {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePanel()
            }
        }
    }
    
    func closePanel() {
        panel.orderOut(nil)
        
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}
