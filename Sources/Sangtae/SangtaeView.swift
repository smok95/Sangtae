import SwiftUI

struct Theme {
    static func bg(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 25/255, green: 25/255, blue: 30/255) : Color.white
    }
    
    static func text(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : .black
    }
    
    static func secondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 140/255, green: 140/255, blue: 150/255) : Color.gray
    }
    
    static func barBg(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    static let green = Color(red: 80/255, green: 220/255, blue: 100/255)
    static let yellow = Color(red: 255/255, green: 200/255, blue: 80/255)
    static let red = Color(red: 255/255, green: 80/255, blue: 80/255)
    
    static func dynamicColor(value: Double) -> Color {
        switch value {
        case 0.8...: return red
        case 0.6..<0.8: return yellow
        default: return green
        }
    }
}

struct SangtaeView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var monitor = SystemMonitor()
    
    // Adjusted layout for better balance
    private let colW: CGFloat = 250 // Reduced from 280
    private let gap: CGFloat = 15
    private let winW: CGFloat = 530 // Reduced from 600 to prevent edge sticking
    private let fontSz: CGFloat = 9.5
    private let headerSz: CGFloat = 10
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title Header
            HStack(spacing: 6) {
                Image(systemName: "chevron.up") // Match menu bar icon
                    .font(.system(size: headerSz + 2, weight: .bold))
                    .foregroundColor(Theme.secondary(for: colorScheme))
                    .offset(y: 1) // Optical alignment
                
                Text(Locale.current.language.languageCode?.identifier == "ko" ? "상태" : "SANGTAE")
                    .font(.system(size: headerSz + 4, weight: .black, design: .monospaced))
                    .foregroundColor(Theme.text(for: colorScheme))
                
                Spacer()
                
                // Battery Indicator
                if monitor.batteryLevel >= 0 {
                    HStack(spacing: 4) {
                        Image(systemName: monitor.isCharging ? "battery.100.bolt" : (monitor.batteryLevel > 0.8 ? "battery.100" : (monitor.batteryLevel > 0.6 ? "battery.75" : (monitor.batteryLevel > 0.4 ? "battery.50" : (monitor.batteryLevel > 0.2 ? "battery.25" : "battery.0")))))
                            .font(.system(size: headerSz + 1, weight: .medium))
                            .foregroundColor(Theme.text(for: colorScheme))
                        
                        Text(String(format: "%.0f%%", monitor.batteryLevel * 100))
                            .font(.system(size: headerSz, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.text(for: colorScheme))
                    }
                }
            }
            .padding(.bottom, 4)

            HStack(alignment: .top, spacing: gap) {
                // Left Column: CPU -> Processes
                VStack(alignment: .leading, spacing: 8) {
                    
                    // CPU
                    SectionBox(icon: "cpu", title: "CPU", fontSize: headerSz, scheme: colorScheme) {
                        MetricRow(label: "Total", value: monitor.cpuTotal, detail: String(format: "%.1f%%", monitor.cpuTotal * 100), width: colW, fontSize: fontSz, scheme: colorScheme)
                        ForEach(monitor.coreUsages.prefix(4), id: \.name) { core in
                            MetricRow(label: core.name, value: core.value, detail: String(format: "%.1f%%", core.value * 100), width: colW, fontSize: fontSz, scheme: colorScheme)
                        }
                    }
                    
                    // Processes
                    SectionBox(icon: "list.bullet", title: "PROCESSES", fontSize: headerSz, scheme: colorScheme) {
                        ForEach(monitor.topProcesses.prefix(4)) { proc in
                            HStack(spacing: 0) {
                                Text(proc.name)
                                    .font(.system(size: fontSz, design: .monospaced))
                                    .foregroundColor(Theme.text(for: colorScheme))
                                    .frame(width: 140, alignment: .leading)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                                Text(String(format: "%.1f%%", proc.cpuUsage))
                                    .font(.system(size: fontSz, design: .monospaced))
                                    .foregroundColor(Theme.text(for: colorScheme))
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .frame(width: colW)
                        }
                    }
                }
                .frame(width: colW)

                // Right Column: Memory -> Network -> Disk
                VStack(alignment: .leading, spacing: 8) {
                    // Memory
                    SectionBox(icon: "memorychip", title: "MEMORY", fontSize: headerSz, scheme: colorScheme) {
                        MetricRow(
                            label: String(format: "%.1f/%.1fG", monitor.memUsedGB, monitor.memTotalGB),
                            value: monitor.memUsedRatio,
                            detail: String(format: "%.1f%%", monitor.memUsedRatio * 100),
                            width: colW,
                            labelW: 70,
                            fontSize: fontSz,
                            scheme: colorScheme,
                            detailW: 40
                        )
                    }
                    
                    // Network
                    SectionBox(icon: "network", title: "NETWORK", fontSize: headerSz, scheme: colorScheme) {
                        MetricRow(label: "Down", value: min(monitor.netDownMB / 10.0, 1.0), detail: String(format: "%.1fM", monitor.netDownMB), width: colW, fontSize: fontSz, scheme: colorScheme)
                        MetricRow(label: "Up", value: min(monitor.netUpMB / 5.0, 1.0), detail: String(format: "%.1fM", monitor.netUpMB), width: colW, fontSize: fontSz, scheme: colorScheme)
                    }
                    
                    // Disk (Tighter Layout)
                    SectionBox(icon: "internaldrive", title: "DISK", fontSize: headerSz, scheme: colorScheme) {
                        ForEach(monitor.disks.prefix(4), id: \.name) { disk in
                            HStack(spacing: 0) {
                                // Name: 50pt
                                Text(disk.name)
                                    .font(.system(size: fontSz, design: .monospaced))
                                    .foregroundColor(Theme.text(for: colorScheme))
                                    .frame(width: 50, alignment: .leading)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                
                                // Bar: Flexible
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle().frame(width: geometry.size.width, height: 8).foregroundColor(Theme.barBg(for: colorScheme))
                                        Rectangle()
                                            .frame(width: CGFloat(min(max(disk.used, 0), 1.0)) * geometry.size.width, height: 8)
                                            .foregroundColor(Theme.dynamicColor(value: disk.used))
                                    }
                                    .cornerRadius(2)
                                    .offset(y: 2) // Center vertically roughly
                                }
                                .frame(height: 12) // Container height
                                .padding(.horizontal, 5) // Gap around bar
                                
                                // Percent: 35pt (Tighter)
                                Text(String(format: "%.1f%%", disk.used * 100))
                                    .font(.system(size: fontSz, design: .monospaced))
                                    .foregroundColor(Theme.text(for: colorScheme))
                                    .frame(width: 38, alignment: .trailing)
                                
                                // Capacity: 75pt (Tighter, closer to percent)
                                Text(disk.label)
                                    .font(.system(size: fontSz - 1, design: .monospaced))
                                    .foregroundColor(Theme.text(for: colorScheme))
                                    .frame(width: 80, alignment: .trailing)
                                    .lineLimit(1)
                            }
                            .frame(width: colW)
                        }
                    }
                }
                .frame(width: colW)
            }
            
            Divider().background(Theme.text(for: colorScheme).opacity(0.1))
            
            HStack {
                let loadStr = String(format: "%.2f / %.2f / %.2f", monitor.loadAvg[0], monitor.loadAvg[1], monitor.loadAvg[2])
                let coreStr = monitor.eCoreCount > 0 ? "(\(monitor.pCoreCount)P + \(monitor.eCoreCount)E)" : "(\(monitor.pCoreCount) Cores)"
                
                Text("LOAD: \(loadStr) \(coreStr)")
                    .font(.system(size: fontSz - 1, design: .monospaced))
                    .foregroundColor(Theme.secondary(for: colorScheme))
                Spacer()
                Button("QUIT") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.secondary(for: colorScheme))
            }
        }
        .padding(12)
        .frame(width: winW)
        .background(Theme.bg(for: colorScheme))
        .cornerRadius(16) // Force rounded corners
        .edgesIgnoringSafeArea(.all) 
        .fixedSize()
    }
}

struct SectionBox<Content: View>: View {
    let icon: String
    let title: String
    let fontSize: CGFloat
    let scheme: ColorScheme
    let content: Content
    
    init(icon: String, title: String, fontSize: CGFloat, scheme: ColorScheme, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.fontSize = fontSize
        self.scheme = scheme
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: fontSize - 1))
                Text(title).font(.system(size: fontSize, weight: .bold, design: .monospaced))
                Rectangle().frame(height: 0.5).foregroundColor(Theme.secondary(for: scheme).opacity(0.2))
            }
            .foregroundColor(Theme.secondary(for: scheme))
            content
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: Double
    let detail: String
    var width: CGFloat
    var labelW: CGFloat = 40
    var fontSize: CGFloat
    var scheme: ColorScheme
    var detailW: CGFloat = 40
    
    var body: some View {
        HStack(spacing: 0) {
            if labelW > 0 {
                Text(label)
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundColor(Theme.text(for: scheme))
                    .frame(width: labelW, alignment: .leading)
                    .lineLimit(1)
            }
            
            // Flexible Bar using GeometryReader for max width usage
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().frame(width: geometry.size.width, height: 8).foregroundColor(Theme.barBg(for: scheme))
                    Rectangle()
                        .frame(width: CGFloat(min(max(value, 0), 1.0)) * geometry.size.width, height: 8)
                        .foregroundColor(Theme.dynamicColor(value: value))
                }
                .cornerRadius(2)
                .offset(y: 2) // Vertically center within the text height approx
            }
            .frame(height: 12)
            .padding(.horizontal, 5)
            
            Text(detail)
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.text(for: scheme))
                .frame(width: detailW, alignment: .trailing)
        }
        .frame(width: width)
    }
}
