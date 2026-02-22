import Foundation
import Darwin

struct ProcessInfo: Identifiable {
    let id = UUID()
    let name: String
    let cpuUsage: Double
}

class SystemMonitor: ObservableObject {
    // CPU
    @Published var cpuTotal: Double = 0.0
    @Published var loadAvg: [Double] = [0.0, 0.0, 0.0]
    @Published var coreUsages: [(name: String, value: Double)] = []
    
    // Memory
    @Published var memUsedRatio: Double = 0.0
    @Published var memTotalGB: Double = 0.0
    @Published var memUsedGB: Double = 0.0
    @Published var memAvailableGB: Double = 0.0
    
    // Disk
    @Published var disks: [(name: String, used: Double, label: String)] = []
    
    // Network
    @Published var netDownMB: Double = 0.0
    @Published var netUpMB: Double = 0.0
    
    // Battery
    @Published var batteryLevel: Double = -1.0
    @Published var isCharging: Bool = false
    
    // Cores
    @Published var pCoreCount: Int = 0
    @Published var eCoreCount: Int = 0
    
    // Processes
    @Published var topProcesses: [ProcessInfo] = []
    
    // Private State for Deltas
    private var prevCPUInfo: processor_info_array_t?
    private var prevCPUCount: mach_msg_type_number_t = 0
    private var previousCPU = host_cpu_load_info() // For Total CPU delta
    
    private var prevNetBytesIn: UInt64 = 0
    private var prevNetBytesOut: UInt64 = 0
    private var lastUpdate = Date()
    private var timer: Timer?
    
    // Concurrency Control
    private let updateQueue = DispatchQueue(label: "com.gemini.sangtae.update")
    private var isUpdating = false
    private var updateCounter = 0

    init() {
        // Fetch Core Counts
        var size = MemoryLayout<Int32>.size
        var pCores: Int32 = 0
        var eCores: Int32 = 0
        
        // Try to get P-Cores (perflevel0) and E-Cores (perflevel1)
        if sysctlbyname("hw.perflevel0.logicalcpu", &pCores, &size, nil, 0) == 0 {
            self.pCoreCount = Int(pCores)
        }
        if sysctlbyname("hw.perflevel1.logicalcpu", &eCores, &size, nil, 0) == 0 {
            self.eCoreCount = Int(eCores)
        }
        
        // Fallback for Intel or if detection failed (Total count)
        if self.pCoreCount == 0 && self.eCoreCount == 0 {
            var total: Int32 = 0
            sysctlbyname("hw.logicalcpu", &total, &size, nil, 0)
            self.pCoreCount = Int(total)
        }
        
        updateStats()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }

    func updateStats() {
        guard !isUpdating else { return }
        isUpdating = true
        
        updateQueue.async {
            // Defer removed from here to prevent data race on isUpdating
            
            let now = Date()
            let timeInterval = now.timeIntervalSince(self.lastUpdate)
            self.lastUpdate = now
            
            // Core metrics - always update
            let cpuInfo = self.getRealCPU()
            let cores = self.getRealCores()
            let mem = self.getRealMemory()
            let net = self.getRealNetwork(interval: timeInterval)
            
            // Conditional updates
            var procs: [ProcessInfo]? = nil
            var batt: (level: Double, charging: Bool)? = nil
            var diskInfo: [(name: String, used: Double, label: String)]? = nil
            
            // Update processes every 2s
            if self.updateCounter % 2 == 0 {
                procs = self.getRealTopProcesses()
            }
            
            // Update disks and battery every 10s
            if self.updateCounter % 10 == 0 {
                batt = self.getBatteryInfo()
                diskInfo = self.getRealDisks()
            }
            
            self.updateCounter = (self.updateCounter + 1) % 1000
            
            DispatchQueue.main.async {
                self.cpuTotal = cpuInfo.total
                self.loadAvg = cpuInfo.load
                self.coreUsages = cores
                self.memUsedRatio = mem.ratio
                self.memUsedGB = mem.used
                self.memAvailableGB = mem.free
                self.memTotalGB = mem.total
                self.netDownMB = net.down
                self.netUpMB = net.up
                
                if let p = procs { self.topProcesses = p }
                if let b = batt {
                    self.batteryLevel = b.level
                    self.isCharging = b.charging
                }
                if let d = diskInfo { self.disks = d }
                
                self.isUpdating = false // Safe: Updated on Main Thread
            }
        }
    }

    // --- REAL DATA FETCHERS ---

    private func getBatteryInfo() -> (level: Double, charging: Bool) {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["-g", "batt"]
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
        } catch {
            return (-1.0, false)
        }
        
        defer {
            pipe.fileHandleForReading.closeFile()
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        
        if let output = String(data: data, encoding: .utf8), output.contains("InternalBattery") {
            // Parse "55%;" or "100%;"
            let parts = output.components(separatedBy: ";")
            if parts.count >= 2 {
                // Extract percentage
                if let percentRange = parts[0].range(of: "\\d+%", options: .regularExpression) {
                    let percentString = String(parts[0][percentRange]).dropLast()
                    if let percent = Double(percentString) {
                        let isCharging = output.contains("charging") && !output.contains("discharging")
                        return (percent / 100.0, isCharging)
                    }
                }
            }
        }
        
        // No battery found (Mac Mini / iMac / Errors)
        return (-1.0, false)
    }

    private func getRealCPU() -> (total: Double, load: [Double]) {
        var load = [Double](repeating: 0.0, count: 3)
        getloadavg(&load, 3)
        // self.loadAvg = load  <-- REMOVED: Caused crash by updating on BG thread
        
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info()
        _ = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        
        let user = Double(info.cpu_ticks.0 - previousCPU.cpu_ticks.0)
        let sys = Double(info.cpu_ticks.1 - previousCPU.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2 - previousCPU.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3 - previousCPU.cpu_ticks.3)
        previousCPU = info
        
        let total = user + sys + idle + nice
        let totalUsage = total == 0 ? 0 : (user + sys + nice) / total
        
        return (totalUsage, load)
    }

    private func getRealCores() -> [(name: String, value: Double)] {
        var processorCount: mach_msg_type_number_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &processorInfo, &processorInfoCount)
        
        guard result == KERN_SUCCESS, let info = processorInfo else { return [] }
        
        var results: [(name: String, value: Double)] = []
        
        if let prevInfo = prevCPUInfo {
            for i in 0..<Int(processorCount) {
                let offset = i * Int(CPU_STATE_MAX)
                let u = Double(info[offset + Int(CPU_STATE_USER)] - prevInfo[offset + Int(CPU_STATE_USER)])
                let s = Double(info[offset + Int(CPU_STATE_SYSTEM)] - prevInfo[offset + Int(CPU_STATE_SYSTEM)])
                let n = Double(info[offset + Int(CPU_STATE_NICE)] - prevInfo[offset + Int(CPU_STATE_NICE)])
                let id = Double(info[offset + Int(CPU_STATE_IDLE)] - prevInfo[offset + Int(CPU_STATE_IDLE)])
                let total = u + s + n + id
                let usage = total > 0 ? (u + s + n) / total : 0.0
                results.append(("Core\(i+1)", usage))
            }
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(prevCPUCount * mach_msg_type_number_t(MemoryLayout<integer_t>.size)))
        }
        
        prevCPUInfo = info
        prevCPUCount = processorInfoCount
        
        // Sort by usage descending (Highest Load First)
        return results.sorted { $0.value > $1.value }
    }

    private func getRealMemory() -> (ratio: Double, used: Double, free: Double, total: Double) {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var info = vm_statistics64_data_t()
        _ = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        
        var totalBytes: UInt64 = 0
        var totalSize = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalBytes, &totalSize, nil, 0)
        
        let pageSize = Double(vm_kernel_page_size)
        let used = (Double(info.active_count) + Double(info.wire_count) + Double(info.compressor_page_count)) * pageSize / 1024 / 1024 / 1024
        let total = Double(totalBytes) / 1024 / 1024 / 1024
        
        return (used / total, used, total - used, total)
    }

    private func getRealDisks() -> [(name: String, used: Double, label: String)] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        let options: FileManager.VolumeEnumerationOptions = [.skipHiddenVolumes]
        let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: options) ?? []
        
        var results: [(name: String, used: Double, label: String)] = []
        for url in paths {
            guard let components = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            
            if let total = components.volumeTotalCapacity, let avail = components.volumeAvailableCapacity, total > 10 * 1024 * 1024 * 1024 { // Only show disks > 10GB
                let usedBytes = total - avail
                let ratio = Double(usedBytes) / Double(total)
                let name = components.volumeName ?? url.lastPathComponent
                let label = String(format: "(%dG/%dG)", usedBytes / 1024 / 1024 / 1024, total / 1024 / 1024 / 1024)
                results.append((name, ratio, label))
            }
        }
        return Array(results.prefix(4))
    }

    private func getRealNetwork(interval: TimeInterval) -> (down: Double, up: Double) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (0, 0) }
        
        var currIn: UInt64 = 0
        var currOut: UInt64 = 0
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let addr = ptr.pointee
            if addr.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: addr.ifa_name)
                // Filter common active interfaces
                if name == "en0" || name == "en1" { 
                    let data = unsafeBitCast(addr.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                    currIn += UInt64(data.pointee.ifi_ibytes)
                    currOut += UInt64(data.pointee.ifi_obytes)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        // Fix Arithmetic Overflow Crash:
        // If interface counters reset or roll over, currIn might be less than prevNetBytesIn.
        // We must ensure we don't subtract a larger number from a smaller one on UInt64.
        
        var down: Double = 0.0
        var up: Double = 0.0
        
        if prevNetBytesIn > 0 && currIn >= prevNetBytesIn {
             down = Double(currIn - prevNetBytesIn) / 1024 / 1024 / interval
        }
        
        if prevNetBytesOut > 0 && currOut >= prevNetBytesOut {
             up = Double(currOut - prevNetBytesOut) / 1024 / 1024 / interval
        }
        
        prevNetBytesIn = currIn
        prevNetBytesOut = currOut
        
        return (down, up)
    }

    private func getRealTopProcesses() -> [ProcessInfo] {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-eco", "%cpu,comm", "-r"]
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
        } catch {
            return []
        }
        
        defer {
            pipe.fileHandleForReading.closeFile()
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        
        let output = String(data: data, encoding: .utf8) ?? ""
        
        var results: [ProcessInfo] = []
        let lines = output.components(separatedBy: "\n").dropFirst()
        for line in lines where !line.isEmpty {
            let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").filter { !$0.isEmpty }
            if parts.count >= 2, let cpu = Double(parts[0]) {
                if cpu > 0.5 {
                    results.append(ProcessInfo(name: parts[1...].joined(separator: " "), cpuUsage: cpu))
                }
            }
            if results.count >= 4 { break }
        }
        return results
    }
}
