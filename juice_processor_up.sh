#!/bin/bash

# Script to modululate CPU frequency scaling
# Usage: ./juice_processor_up.sh [performance|powersave|ondemand|conservative|schedutil]

# Check if argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 [performance|powersave|ondemand|conservative|schedutil]"
    echo "Example: $0 performance"
    exit 1
fi

GOVERNOR="$1"

# List of acceptable governors
ACCEPTABLE_GOVERNORS=("performance" "powersave" "ondemand" "conservative" "schedutil")

# Check if the provided governor is acceptable
if [[ ! " ${ACCEPTABLE_GOVERNORS[@]} " =~ " ${GOVERNOR} " ]]; then
    echo "Error: '$GOVERNOR' is not a valid governor."
    echo "Acceptable governors are: ${ACCEPTABLE_GOVERNORS[*]}"
    exit 1
fi

echo "Setting CPU frequency scaling governor to: $GOVERNOR"

# Create the systemd service file
sudo tee /etc/systemd/system/cpufreq-${GOVERNOR}.service << EOF
[Unit]
Description=Set CPU frequency scaling governor to $GOVERNOR
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g $GOVERNOR
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Disable any existing cpufreq services to avoid conflicts
echo "Disabling any existing cpufreq services..."
for gov in "${ACCEPTABLE_GOVERNORS[@]}"; do
    if [ "$gov" != "$GOVERNOR" ]; then
        sudo systemctl disable cpufreq-${gov}.service 2>/dev/null || true
        sudo systemctl stop cpufreq-${gov}.service 2>/dev/null || true
    fi
done

# Enable and start the new service
echo "Enabling and starting cpufreq-${GOVERNOR}.service..."
sudo systemctl enable cpufreq-${GOVERNOR}.service
sudo systemctl start cpufreq-${GOVERNOR}.service

# Verify the setting
echo "Verifying governor setting..."
sleep 1
CURRENT_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
if [ "$CURRENT_GOVERNOR" = "$GOVERNOR" ]; then
    echo "✓ Successfully set governor to: $CURRENT_GOVERNOR"
else
    echo "✗ Failed to set governor. Current governor: $CURRENT_GOVERNOR"
    exit 1
fi

echo "Governor change completed successfully!"
echo "This setting will persist after reboot."