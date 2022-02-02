import Foundation
import os
import IOKit.ps

let home = ProcessInfo.processInfo.environment["HOME"]

let isPowerAdapterConnected = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() != nil

func shell(_ command: String) {
    let task = Process()

    task.arguments = ["-c", command]
    task.launchPath = "/bin/bash"
    do {
        try task.run()
    } 
    catch {
        print(error)
    }
    task.waitUntilExit()
}

if isPowerAdapterConnected {
    shell("\(home!)/git/dotfiles/bin/photos_metrics.sh")
} else {
    print("On battery power, skipping...")
}

