ARG TARGETPLATFORM
FROM ogarcia/archlinux AS customizer

#######################################################
ARG BUILD_KDE
ARG PulseAudio
ARG ENABLE_en_us_ARG
ARG ENABLE_binfmt_ARG
ARG ENABLE_yj_ARG
ARG ENABLE_mesa_ARG
ARG ENABLE_kfgj_ARG
ARG ENABLE_zip_ARG
ARG ENABLE_docker_ARG
ARG ENABLE_srf_ARG
ARG ENABLE_tmoe_ARG
######################################################

RUN sed -i '/^#ParallelDownloads/s/^#//' /etc/pacman.conf && \
    sed -i '/NoExtract.*locale/d' /etc/pacman.conf && \
    sed -i '/NoExtract.*i18n/d' /etc/pacman.conf && \
    pacman -Sy --noconfirm archlinux-keyring glibc && \
    pacman -Su --noconfirm && \
    pacman -S --noconfirm --needed \
    # Core Tools
    bash jq dialog coreutils file findutils grep sed gawk curl wget ca-certificates bash-completion dbus systemd fastfetch logrotate \
    # Base Dev/Edit Tools
    git nano sudo \
    # Network & SSH Tools
    openssh net-tools iptables iputils iproute2 bind \
    # Process Monitoring
    procps-ng \
    # Kernel Modules Support
    kmod tzdata && \
    ############################################## KDE Support ################################################
    # Minimal KDE
    if [ "$BUILD_KDE" = "Min" ]; then \
        pacman -S --noconfirm --needed \
        xorg-xrandr noto-fonts-emoji plasma-desktop pipewire pipewire-pulse wireplumber powerdevil kscreen plasma-pa ark kwin kwin-x11 upower konsole \
        dolphin kate kinfocenter mesa-utils libpulse vulkan-tools; \
    fi && \
    # Full KDE
    if [ "$BUILD_KDE" = "Full" ]; then \
        pacman -S --noconfirm --needed \
        xorg-xrandr noto-fonts-emoji plasma-desktop pipewire pipewire-pulse wireplumber powerdevil kscreen plasma-pa ark kwin kwin-x11 upower konsole \
        dolphin kate kinfocenter mesa-utils libpulse vulkan-tools aha clinfo dmidecode pciutils wayland-utils xorg-server \
        kfind plasma-systemmonitor filelight glmark2 vkmark systemsettings kscreenlocker kio-extras xdg-user-dirs dolphin-plugins ffmpegthumbs kdegraphics-thumbnailers \
        kimageformats plasma-browser-integration libcanberra gstreamer gst-plugins-base gst-plugins-good sound-theme-freedesktop chromium; \
    fi && \
    # Arch Workaround for HW Access
    if [ "$BUILD_KDE" = "Full" ] || [ "$BUILD_KDE" = "Min" ] ; then \
        mv /usr/lib/xdg-desktop-portal /usr/lib/xdg-desktop-portal.bak && \
        mv /usr/lib/xdg-desktop-portal-kde /usr/lib/xdg-desktop-portal-kde.bak; \
    fi && \
    ######################################################################################################
    # Input Method (Fcitx5 - Optional)
    if [ "$ENABLE_srf_ARG" = "true" ]; then \
        pacman -S --noconfirm --needed fcitx5-im; \
    fi && \
    ## Dev Tools Integration (Optional)
    if [ "$ENABLE_kfgj_ARG" = "true" ]; then \
        pacman -S --noconfirm --needed \
        base-devel cmake clang llvm python python-pip; \
    fi && \
    ## Compression Tools (Optional)
    if [ "$ENABLE_zip_ARG" = "true" ]; then \
        pacman -S --noconfirm --needed \
        zip unzip p7zip bzip2 xz tar gzip; \
    fi && \
    ## Docker Support (Optional)
    if [ "$ENABLE_docker_ARG" = "true" ]; then \
        pacman -S --noconfirm --needed \
        docker docker-compose; \
    fi && \
    ## TMOE Integration (Optional)
    if [ "$ENABLE_tmoe_ARG" = "true" ]; then \
        git clone --depth=1 https://github.com/2moe/tmoe-linux.git /usr/local/etc/tmoe-linux/git && \
        ln -sf /usr/local/etc/tmoe-linux/git/debian.sh /usr/local/bin/tmoe && \
        chmod -R 755 /usr/local/etc/tmoe-linux; \
    fi 

# Configure Locale & SSH
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf && \
    echo "LC_ALL=en_US.UTF-8" >> /etc/locale.conf && \
    # SSH Config
    mkdir -p /var/run/sshd && \
    ssh-keygen -A && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    # Cleanup default user and create new user
    userdel -r alarm 2>/dev/null || true && \
    useradd -m -s /bin/bash notshroud && echo "notshroud:1234" | chpasswd && \
    systemctl enable sshd

# Custom Environment Variables
RUN cat <<'EOF' > /etc/profile.d/custom_env.sh
export MESA_LOADER_DRIVER_OVERRIDE=kgsl
export TU_DEBUG=noconform
export XCURSOR_SIZE=48
export XMODIFIERS=@im=fcitx5
export GTK_IM_MODULE=fcitx5
export QT_IM_MODULE=fcitx5
export SDL_IM_MODULE=fcitx5
export GLFW_IM_MODULE=fcitx
export DISPLAY=:1
EOF

# Audio Selection
RUN if [ "$PulseAudio" = "socket" ]; then \
        echo 'export PULSE_SERVER="unix:/tmp/.pulse-socket"' >> /etc/profile.d/custom_env.sh; \
    elif [ "$PulseAudio" = "tcp" ]; then \
        echo 'export PULSE_SERVER="tcp:127.0.0.1:4713"' >> /etc/profile.d/custom_env.sh; \
    fi
RUN chmod +x /etc/profile.d/custom_env.sh

# Autostart Configurations
RUN <<'EOF_RUN'
    if [ "$ENABLE_srf_ARG" = "true" ]; then
    mkdir -p /home/notshroud/.config/autostart
    cat <<'EOF' > /home/notshroud/.config/autostart/fcitx5.desktop
[Desktop Entry]
Name=Fcitx5
GenericName=Input Method
Comment=Start Input Method
Exec=fcitx5 -d
Icon=fcitx
Terminal=false
Type=Application
Categories=System;Utility;
StartupNotify=false
NoDisplay=true
EOF
fi
    echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)' >> /home/notshroud/.bashrc
    if [ "$BUILD_KDE" = "min" ] || [ "$BUILD_KDE" = "conc" ] ; then
    mkdir -p /home/notshroud/.config 
    cat <<'EOF' > /home/notshroud/.config/kwinrc
[Compositing]
Enabled=false
EOF
    fi
    chown -R notshroud:notshroud /home/notshroud
    if [ "$BUILD_KDE" = "Full" ] || [ "$BUILD_KDE" = "Min" ] ; then
    cat <<'EOF' > /usr/local/bin/startplasma-x11
#!/bin/bash
exec dbus-run-session /usr/bin/startplasma-x11 "$@"
EOF
    chmod +x /usr/local/bin/startplasma-x11
    fi
EOF_RUN

# Download & Install Mesa
RUN if [ "$ENABLE_mesa_ARG" = "true" ]; then \
        echo "--> [Enabled] Downloading and installing latest Mesa drivers..." && \
        URL=$(curl -s https://api.github.com/repos/lfdevs/mesa-for-android-container/releases/latest | \
        jq -r '.assets[] | select(.name | test("mesa-for-android-container_.*_archlinux_arm64\\.tar")) | .browser_download_url' | head -1) && \
        if [ -z "$URL" ] || [ "$URL" = "null" ]; then echo "Failed to get download link, possibly hit GitHub API rate limit"; exit 1; fi && \
        wget -q --tries=5 --waitretry=3 -O /tmp/mesa.tar "$URL" && \
        tar -xf /tmp/mesa.tar -C /tmp && \
        cp /etc/pacman.conf /tmp/pacman-nosig.conf && \
        sed -i 's/.*SigLevel.*/SigLevel = Never/g' /tmp/pacman-nosig.conf && \
        pacman --config /tmp/pacman-nosig.conf -U --noconfirm /tmp/*.pkg.tar.* && \
        rm -f /tmp/mesa.tar /tmp/*.pkg.tar.* /tmp/pacman-nosig.conf /tmp/*.sig ; \
    else \
        echo "--> [Skipped] Mesa driver installation not enabled"; \
    fi

# Fix DHCP config for containers
RUN mkdir -p /etc/systemd/network && \
    cat <<'EOF' > /etc/systemd/network/10-eth-dhcp.network
[Match]
Name=eth*

[Network]
DHCP=yes
IPv6AcceptRA=yes

[DHCPv4]
UseDNS=yes
UseDomains=yes
RouteMetric=100
EOF

# Android Env Compat Fixes
RUN <<'EOF_RUN'
# --- 1. General Compat Fixes ---
# Create Android network groups
grep -q '^aid_inet:' /etc/group     || echo 'aid_inet:x:3003:'    >> /etc/group
grep -q '^aid_net_raw:' /etc/group || echo 'aid_net_raw:x:3004:' >> /etc/group
grep -q '^aid_net_admin:' /etc/group || echo 'aid_net_admin:x:3005:' >> /etc/group

# Create droidspaces-gpu group
getent group droidspaces-gpu >/dev/null || groupadd -g 786 -r droidspaces-gpu
# Assign perms to root
usermod -a -G aid_inet,aid_net_raw,input,video,tty,droidspaces-gpu root || true
usermod -a -G aid_inet,aid_net_raw,input,video,tty,wheel,droidspaces-gpu notshroud || true

# Sudo for wheel group
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# --- 2. Systemd Specific Fixes ---
ln -sf /dev/null /etc/systemd/system/systemd-networkd-wait-online.service
ln -sf /dev/null /etc/systemd/system/systemd-journald-audit.socket

# Optimize Journald
cat >> /etc/systemd/journald.conf << 'EOT'
[Journal]
ReadKMsg=no
Audit=no
Storage=volatile
EOT

mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/ds-logging.conf << 'EOT'
[Journal]
SystemMaxUse=200M
RuntimeMaxUse=200M
MaxRetentionSec=7day
MaxLevelStore=info
EOT

mkdir -p /etc/systemd/system/multi-user.target.wants
GUEST_SYSTEMD_PATH="/usr/lib/systemd/system"

if [ -f "$GUEST_SYSTEMD_PATH/dbus.service" ]; then
    ln -sf "$GUEST_SYSTEMD_PATH/dbus.service" "/etc/systemd/system/multi-user.target.wants/dbus.service"
fi

if [ "$ENABLE_yj_ARG" = "true" ]; then
    for service in systemd-udevd.service systemd-resolved.service systemd-networkd.service NetworkManager.service; do
        if [ -f "$GUEST_SYSTEMD_PATH/$service" ]; then
            ln -sf "$GUEST_SYSTEMD_PATH/$service" "/etc/systemd/system/multi-user.target.wants/$service"
        fi
    done
else
    for service in systemd-udevd.service systemd-resolved.service systemd-networkd.service NetworkManager.service; do
        ln -sf /dev/null "/etc/systemd/system/$service"
    done
fi

# Disable Power Key handling
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/99-power-key.conf << 'EOF'
[Login]
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandlePowerKeyLongPress=ignore
HandlePowerKeyLongPressHibernate=ignore
EOF

# Udev Overrides
mkdir -p /etc/systemd/system/systemd-udev-trigger.service.d
cat > /etc/systemd/system/systemd-udev-trigger.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/udevadm trigger --subsystem-match=usb --subsystem-match=block --subsystem-match=input --subsystem-match=tty --subsystem-match=net
EOF

# Read-only path overrides
for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service systemd-udevd-kernel.socket systemd-udevd-control.socket; do
    mkdir -p "/etc/systemd/system/${unit}.d"
    printf "[Unit]\nConditionPathIsReadWrite=\n" > "/etc/systemd/system/${unit}.d/99-readonly-fix.conf"
done

# Network service limits
for unit in NetworkManager.service dhcpcd.service systemd-resolved.service systemd-networkd.service; do
    if [ -f "$GUEST_SYSTEMD_PATH/$unit" ] || [ -f "/etc/systemd/system/multi-user.target.wants/$unit" ]; then
        mkdir -p "/etc/systemd/system/${unit}.d"
        cat > "/etc/systemd/system/${unit}.d/99-netmode-limit.conf" << 'EOF'
[Service]
ExecCondition=
ExecCondition=/bin/sh -c "grep -q 'net_mode=nat' /run/droidspaces/container.config"
EOF
    fi
done

# Hardware access udev limits
for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service; do
    if [ -f "$GUEST_SYSTEMD_PATH/$unit" ] || [ -f "/etc/systemd/system/multi-user.target.wants/$unit" ]; then
        mkdir -p "/etc/systemd/system/${unit}.d"
        cat > "/etc/systemd/system/${unit}.d/99-hwaccess-limit.conf" << 'EOF'
[Service]
ExecCondition=
ExecCondition=/bin/sh -c "grep -q 'enable_hw_access=0' /run/droidspaces/container.config"
EOF
    fi
done

# Logrotate tweaks
if [ -f /etc/logrotate.conf ]; then
    sed -i 's/^#maxsize.*/maxsize 50M/' /etc/logrotate.conf
    if ! grep -q "maxsize 50M" /etc/logrotate.conf; then
        echo "maxsize 50M" >> /etc/logrotate.conf
    fi
fi

echo "Post-extraction fixes applied on $(date)" > /etc/droidspaces
EOF_RUN

# Binfmt Service Injection
COPY scripts/binfmt/qemu-binfmt-register.sh /usr/local/bin/
COPY scripts/binfmt/qemu-binfmt-register.service /etc/systemd/system/

RUN if [ "$ENABLE_binfmt_ARG" = "false" ]; then \
        rm -rf /usr/local/bin/qemu-binfmt-register.sh && \
        rm -rf /etc/systemd/system/qemu-binfmt-register.service ; \
    fi

RUN if [ "$ENABLE_binfmt_ARG" = "true" ]; then \
        chmod +x /usr/local/bin/qemu-binfmt-register.sh && \
        chmod 644 /etc/systemd/system/qemu-binfmt-register.service && \
        mkdir -p /etc/systemd/system/multi-user.target.wants && \
        ln -sf /etc/systemd/system/qemu-binfmt-register.service /etc/systemd/system/multi-user.target.wants/qemu-binfmt-register.service && \
        pacman -S --noconfirm --needed qemu-user-static && \
        rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/* ; \
    else \
        rm -f /usr/local/bin/qemu-binfmt-register.sh /etc/systemd/system/qemu-binfmt-register.service; \
    fi

# Final Cleanup
RUN rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/*

# Phase 2: Export rootfs
FROM scratch AS export
COPY --from=customizer / /

