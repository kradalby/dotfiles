import Foundation
import os
import IOKit.ps

let home = ProcessInfo.processInfo.environment["HOME"]
let arguments = CommandLine.arguments
let action = arguments[1]

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

for repo in ["rclone_Jotta", "rest_restic_core_terra_fap_no", "rest_restic_core_tjoda_fap_no"] {
    if isPowerAdapterConnected {
        shell("\(home!)/bin/restic_backup_job.sh \(repo) \(action)")
    } else {
        print("On battery power, skipping \(repo) \(action)...")
    }
}

