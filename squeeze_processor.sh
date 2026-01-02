#!/bin/bash

# Script to revert CPU frequency scaling governor changes
# Usage: ./revert_cpu_governor.sh

echo "Reverting CPU frequency scaling governor changes..."

# List of possible governor services that might have been created
POSSIBLE_GOVERNORS=("performance" "powersave" "ondemand" "conservative" "schedutil")

echo "Stopping and disabling any cpufreq governor services..."

# Stop and disable all possible governor services
for gov in "${POSSIBLE_GOVERNORS[@]}"; do
    SERVICE_NAME="cpufreq-${gov}.service"
    
    if systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
        echo "  Disabling $SERVICE_NAME..."
        sudo systemctl disable "$SERVICE_NAME"
    fi
    
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        echo "  Stopping $SERVICE_NAME..."
        sudo systemctl stop "$SERVICE_NAME"
    fi
    
    # Remove the service file if it exists
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
    if [ -f "$SERVICE_FILE" ]; then
        echo "  Removing $SERVICE_FILE..."
        sudo rm "$SERVICE_FILE"
    fi
done

# Reload systemd daemon to recognize the removed service files
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Reset to system default governor (usually ondemand or schedutil)
echo "Resetting CPU governor to system default..."

# Try to determine the default governor
DEFAULT_GOVERNOR=""
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]; then
    AVAILABLE_GOVERNORS=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)
    
    # Prefer schedutil if available (modern default), otherwise ondemand
    if echo "$AVAILABLE_GOVERNORS" | grep -q "schedutil"; then
        DEFAULT_GOVERNOR="schedutil"
    elif echo "$AVAILABLE_GOVERNORS" | grep -q "ondemand"; then
        DEFAULT_GOVERNOR="ondemand"
    else
        # Take the first available governor that's not performance or powersave
        for gov in $AVAILABLE_GOVERNORS; do
            if [ "$gov" != "performance" ] && [ "$gov" != "powersave" ]; then
                DEFAULT_GOVERNOR="$gov"
                break
            fi
        done
    fi
fi

# Set the default governor if we found one
if [ -n "$DEFAULT_GOVERNOR" ]; then
    echo "Setting governor to system default: $DEFAULT_GOVERNOR"
    sudo cpupower frequency-set -g "$DEFAULT_GOVERNOR" 2>/dev/null || {
        echo "Warning: Could not set governor using cpupower. Trying manual method..."
        # Fallback: set governor manually for each CPU
        for cpu_dir in /sys/devices/system/cpu/cpu*/cpufreq/; do
            if [ -w "${cpu_dir}scaling_governor" ]; then
                echo "$DEFAULT_GOVERNOR" | sudo tee "${cpu_dir}scaling_governor" >/dev/null 2>&1
            fi
        done
    }
else
    echo "Warning: Could not determine system default governor."
    echo "Available governors: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null || echo 'Unknown')"
fi

# Verify the current setting
echo "Verifying current governor setting..."
sleep 1
CURRENT_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
if [ -n "$CURRENT_GOVERNOR" ]; then
    echo "✓ Current governor: $CURRENT_GOVERNOR"
else
    echo "✗ Could not determine current governor"
fi

# Check if any cpufreq services are still running
REMAINING_SERVICES=$(systemctl list-units --type=service --state=active | grep cpufreq- | wc -l)
if [ "$REMAINING_SERVICES" -eq 0 ]; then
    echo "✓ All custom cpufreq services have been removed"
else
    echo "⚠ Warning: Some cpufreq services may still be running:"
    systemctl list-units --type=service --state=active | grep cpufreq-
fi

echo ""
echo "CPU governor revert completed!"
echo "Your system should now use the default governor ($DEFAULT_GOVERNOR)."
echo "This setting will persist after reboot unless you manually change it again."