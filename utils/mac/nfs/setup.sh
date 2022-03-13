#!/usr/bin/env bash

cat << EOF | sudo tee /Library/LaunchDaemons/org.jeroen.mount_nfs.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
          <key>Label</key>
          <string>org.tisgoud.restore_nfs_mount.plist</string>
          <key>ProgramArguments</key>
          <array>
                    <string>/bin/sh</string>
                    <string>/Users/jeroen_manders/workspace/tools/mac/nfs-mount.sh</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
</dict>
</plist>
EOF

sudo chmod 644 /Library/LaunchDaemons/org.jeroen.mount_nfs.plist
