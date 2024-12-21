# DNS Tweaker 

A small script to adjust the used DNS server on a Mac based on whether there is a captive portal present or not.
I case there is a captive portal, the local DNS will be used so the portal can be displayed to the user.
In all other cases, a user defined DNS server will be set across all network connections of the defined interface.

## Overview
As of the time writing, RFC7710 for announcing captive portals via DHCP is unfortunately not widely implemented, so the script relies on MacOS to detect captive portals using undocumented Apple magic(TM).
If MacOS fails, which may happen sometimes, the script will fall back to checking `captive.apple.com` directly.
During the time of detecting the network's state (captive or no) the local DNS may be used for up to 30 seconds for all DNS requests of the system, which can lead to information leaks.
Similiarly, the script will use the local DNS for up to 5 minutes if MacOS inicates that there is a captive portal waiting for user input.
This is a trade-off for keeping the implementation simple, do not use this script if those information leaks are an issue to your use case.

Network changes are detected by watching for file changes in `/var/run/resolv.conf`.

## Install
The script expects to be located at `~/.dns-tweaker`. If a different location is to be used, `dns-tweaker.plist` needs to be ajusted for the correct path.

With the default loacation, install as follows:
```
cp ~/.dns-tweaker/dns-tweaker.plist ~/Library/LaunchAgents/dns-tweaker.plist
launchctl load ~/Library/LaunchAgents/dns-tweaker.plist
```

## Configuration

Parameter  | Default     | Description
---        | ---         | ---
dns_server | `9.9.9.9`   | Preferred DNS server to be used. Can be IPv4 or IPv6.
interface  | `Wi-Fi`     | Interface to be watched. Only one interface can be watched at a time
log_file   | `/dev/null` | Log-file is disabled by default. Set to `$HOME/.dns-tweaker/dns-tweaker.log` to enable. Mind there is no logrotation, so the file will just keep on growing if logs are enabled.

## Uninstall
```
launchctl unload ~/Library/LaunchAgents/dns-tweaker.plist
rm ~/Library/LaunchAgents/dns-tweaker.plist
rm -rf ~/.dns-tweaker
```

## License

Copyright (C) 2024, Mark Dornbach

This program is free software: you can redistribute it and/or modify it under the terms of the MIT License as published in this repository under `LICENSE`.
