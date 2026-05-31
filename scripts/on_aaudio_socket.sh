#!/usr/bin/env bash

CONTAINER_NAME="ArchLinux" # Write your container name here
USERNAME="notshroud"       # Container username
DISPLAY_NUMBER=":0"   
DPI=315

if ! su -c "id -u" 2>/dev/null | grep -q "^0$"; then
    echo "Root privileges are required to run this script. Please ensure the device is rooted and Termux is granted root privileges."
    exit 1
fi

# Check dependencies 
required_commands=("pulseaudio" "pacmd" "pactl" "termux-x11" "id")
missing=()
for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        missing+=("$cmd")
    fi
done

if [ ${#missing[@]} -ne 0 ]; then
    echo "Missing the following dependencies, please install them and try again:"
    printf "   %s\n" "${missing[@]}"
    exit 1
fi

if pgrep -x "pulseaudio" > /dev/null; then
    echo "PulseAudio is already running, skipping startup."
else
    echo "Starting PulseAudio..."
    pulseaudio -k 2>/dev/null
    pulseaudio --start --load="module-native-protocol-unix socket=$PREFIX/tmp/.pulse-socket auth-anonymous=1" --exit-idle-time=-1 &
    sleep 1
    pacmd load-module module-aaudio-sink
    sleep 0.3
fi

AAUDIO_SINK=$(pactl list sinks short | grep "aaudio" | awk '{print $2}')
if [ -n "$AAUDIO_SINK" ]; then
    pactl set-default-sink "$AAUDIO_SINK"
    echo "Default audio device set to: $AAUDIO_SINK"
else
    echo "AAudio device not found, please check if the module loaded successfully."
fi

if pgrep -f "termux-x11.*" > /dev/null; then
    echo "termux-x11 (${DISPLAY_NUMBER}) is already running, restarting."
    pkill termux-x11 > /dev/null
    sleep 0.5
    termux-x11 "${DISPLAY_NUMBER}" -dpi "${DPI}" &
    sleep 1
else
    echo "Starting termux-x11..."
    termux-x11 "${DISPLAY_NUMBER}" -dpi "${DPI}" &
    sleep 1
fi

if su -c "/data/local/Droidspaces/bin/droidspaces --name=\"${CONTAINER_NAME}\" info" | grep -q "${CONTAINER_NAME}"; then
    echo "Container ${CONTAINER_NAME} is running, executing relevant commands..."
    su -c "/data/local/Droidspaces/bin/droidspaces --name=${CONTAINER_NAME} --user=${USERNAME} run DISPLAY=${DISPLAY_NUMBER} startplasma-x11" &
    echo "The desktop has been started, go check it out."
    su -c "am start -n com.termux.x11/.MainActivity"
else
    echo "The container is not powered on, please check if it is running."
fi
