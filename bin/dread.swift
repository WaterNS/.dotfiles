#!/usr/bin/swift

// Ref: https://stackoverflow.com/a/61627681

//  Compile:  swiftc bin/dread.swift  -o bin/dread

// Usage:
// $ dread com.apple.Terminal "Default Window Settings"
// [result] $ Dracula-Custom

import Foundation

var args = CommandLine.arguments
args.removeFirst()
if let suite = args.first, let defaults = UserDefaults(suiteName: suite) {
    args.removeFirst()
    if let keyPath = args.first, let value = defaults.value(forKeyPath: keyPath) {
        print(value)
    } else {
        print(defaults.dictionaryRepresentation())
    }
}
