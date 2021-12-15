# Backup on macOS

Because of all the security stuff, the easiest way to allow restic to run with `launchd` is to wrap it in a
Swift package and then allow that in settings.

Compile the Swift wrapper:

```bash
swiftc restic_wrapper.swift -o ~/bin/restic_wrapper
```

Then copy the launchd jobs from `../launchd` into `~/Library/LaunchAgents`

```bash
cp ../launchd/* ~/Library/LaunchAgents
```

And load them:

```bash
launchctl load $HOME/Library/LaunchAgents/no.kradalby.ResticHourly.plist
```

After a bit, the Swift wrapper binary will ask for permissions to the files it needs access to.

This access can be inspected later in `System Preference -> Security & Privacy -> Privacy -> Files and Folders`

Verify the logs that the backup is not running into any issues:

```bash
tail -f ~/Library/Logs/no.kradalby.ResticHourly.*
```
