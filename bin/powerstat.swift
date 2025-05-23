#!/usr/bin/swift

//  powerstat.swift
//  Live battery and AC power read‑out (Intel & Apple‑Silicon) with colors & spinner
//
//  Compile:  swiftc bin/powerstat.swift -framework IOKit -o bin/powerstat
//  Run:      powerstat   # Ctrl‑C / "q" / Escape to stop
// -----------------------------------------------------------------------------
//  Features
//  • Queries the AppleSmartBattery service for Voltage, Amperage, SOC, ETA, etc.
//  • Shows rated adapter watts **and** live charge watts while charging.
//  • ANSI colors highlight charging (green), discharging (yellow) and errors (red).
//  • A Unicode spinner proves the loop is actively re‑polling every interval.
//  • Press Ctrl+C or Escape or **q** (lower or uppercase) to exit gracefully.
// -----------------------------------------------------------------------------

import Foundation
import IOKit
import Darwin.POSIX.termios
import Darwin

// MARK: - Fixed refresh interval
let refreshInterval: TimeInterval = 0.3   // 300 ms

// MARK: – Put the terminal in raw, non‑blocking mode
var originalTerm = termios()
if tcgetattr(STDIN_FILENO, &originalTerm) == 0 {
    var raw = originalTerm
    raw.c_lflag &= ~(UInt(ECHO | ICANON))          // no echo, char‑by‑char
    raw.c_cc.6 /* VMIN */  = 0                    // 0 = return immediately
    raw.c_cc.5 /* VTIME */ = 0
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)

    // Make stdin non‑blocking so read() never stalls the loop
    let flags = fcntl(STDIN_FILENO, F_GETFL)
    _ = fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)   // discard (or inspect) result
}
func restoreTerminal() { tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTerm) }

// MARK: - ANSI helper
struct Ansi {
    static let reset  = "\u{1B}[0m"
    static let bold   = "\u{1B}[1m"
    static let red    = "\u{1B}[31m"
    static let green  = "\u{1B}[32m"
    static let yellow = "\u{1B}[33m"
    static let cyan   = "\u{1B}[36m"
    static func color(_ s: String, _ c: String, bold: Bool = false) -> String {
        return "\(bold ? Self.bold : "")\(c)\(s)\(Self.reset)"
    }
}

// Spinner frames (Braille dots)
let spinnerFrames = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
var spinnerIndex = 0

// MARK: - IORegistry helpers
private func property(named key: String) -> Any? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }
    return IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
}
private func intProperty(named key: String) -> Int? { (property(named: key) as? NSNumber)?.intValue }
private func boolProperty(named key: String) -> Bool? { (property(named: key) as? NSNumber)?.boolValue }
private func adapterRatedWatts() -> Int? {
    if let dict = property(named: "AdapterDetails") as? NSDictionary,
       let watts = dict["Watts"] as? NSNumber { return watts.intValue }
    return nil
}
private func signedCurrent(_ raw: Int) -> Int {
    let threshold: UInt64 = 0x7FFFFFFFFFFFFFFF
    let value = UInt64(bitPattern: Int64(raw))
    return value > threshold ? Int(Int64(bitPattern: value &+ 1) * -1) : raw
}

// Duration formatter
private func fmtDuration(_ minutes: Int?) -> String {
    guard let m = minutes, m > 0 else { return "--:--" }
    return String(format: "%d:%02d", m / 60, m % 60)
}

// Snapshot
private struct Sample {
    let voltage_mV: Int
    let amperage_mA: Int
    let external: Bool
    let charging: Bool
    let ratedWatts: Int?
    let curCap: Int
    let maxCap: Int
    let tEmpty: Int?
    let tFull: Int?
    var soc: Double { Double(curCap) / Double(maxCap) * 100.0 }
    var battPower_W: Double {
        Double(abs(amperage_mA)) * Double(voltage_mV) / 1_000_000.0
    }
    var actualCharge_W: Double? { charging ? battPower_W : nil }
}

private func fetch() -> Sample? {
    guard let v = intProperty(named: "Voltage"),
          let a = intProperty(named: "Amperage"),
          let ext = boolProperty(named: "ExternalConnected"),
          let ch = boolProperty(named: "IsCharging"),
          let cc = intProperty(named: "CurrentCapacity"),
          let mc = intProperty(named: "MaxCapacity") else { return nil }
    return Sample(voltage_mV: v,
                  amperage_mA: signedCurrent(a),
                  external: ext,
                  charging: ch,
                  ratedWatts: adapterRatedWatts(),
                  curCap: cc,
                  maxCap: mc,
                  tEmpty: intProperty(named: "AvgTimeToEmpty"),
                  tFull: intProperty(named: "AvgTimeToFull"))
}

// Clear line
@inline(__always) private func clr() { print("\r\u{1B}[2K", terminator: "") }

// Ctrl‑C handler
signal(SIGINT) {
  _ in clr();
  //print("Stopping powerstat…");
  exit(EXIT_SUCCESS)
}

// MARK: – Main loop
while true {
    // Non-blocking key-check; exits on bare Esc, q, Q (Ctrl-C is handled by signal).
    var kb = [UInt8](repeating: 0, count: 3)          // room for Esc+[+code
    let n = read(STDIN_FILENO, &kb, kb.count)         // n = bytes actually read
    if n > 0 {
        let first = kb[0]
        let isBareEsc = (first == 27 && n == 1)       // Esc with no followers
        if isBareEsc ||
          first == UInt8(ascii: "q") ||
          first == UInt8(ascii: "Q") {
            clr(); restoreTerminal(); exit(EXIT_SUCCESS)
        }
    }


    if let s = fetch() {
        clr()
        let spin = spinnerFrames[spinnerIndex % spinnerFrames.count]; spinnerIndex += 1

        let powerVal = Ansi.color(String(format: "%.1f W", s.battPower_W), Ansi.yellow, bold: true)
        // let ampStr   = "\(abs(s.amperage_mA))mA"
        // let voltStr  = "\(s.voltage_mV)mV"
        let socStr   = String(format: "%.1f%%", s.soc)
        let rateStr  = s.ratedWatts != nil ? "\(s.ratedWatts!)W" : "?W"
        let lifeETA  = fmtDuration(s.tEmpty)

        let line: String
        if s.external {
            if s.charging {
                let chargeETA = fmtDuration(s.tFull)
                let actStr = Ansi.color(String(format: "%.1fW", s.actualCharge_W ?? 0.0), Ansi.green, bold: true)
                line = "\(spin) Power: \(powerVal) | AC: \(rateStr) - " + Ansi.color("Charging", Ansi.green) + " @ \(actStr)" + " [~\(chargeETA) to full] | Battery: \(socStr)"
            } else {
                line = "\(spin) Power: \(powerVal) | AC: \(rateStr) - " + Ansi.color("Idle", Ansi.cyan) + " | Battery: \(socStr) [~\(lifeETA) left]"
            }
        } else {
            line = "\(spin) Power: \(powerVal) | " + Ansi.color("AC: NotConnected", Ansi.red) + " | Battery: \(socStr) [~\(lifeETA) left]"
        }
        print(line, terminator: "")
        fflush(stdout)
    } else {
        clr(); print(Ansi.color("Battery information unavailable", Ansi.red, bold: true), terminator: ""); fflush(stdout)
    }
    Thread.sleep(forTimeInterval: refreshInterval)
}
