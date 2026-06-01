ARG TARGETPLATFORM
FROM ubuntu:25.10 AS customizer

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

ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's/Components: main/Components: main restricted universe multiverse/g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || \
    sed -i 's/main/main restricted universe multiverse/g' /etc/apt/sources.list 2>/dev/null && \
    apt-get update && \
    apt-get upgrade -y

# Prioritize copying custom scripts
COPY scripts/download-firmware /usr/local/bin/

# Copy custom bashrc script to the root filesystem's profile directory
COPY scripts/bashrc.sh /etc/profile.d/ds-aliases.sh

# Grant execution permissions to relevant scripts
RUN chmod +x /usr/local/bin/download-firmware /etc/profile.d/ds-aliases.sh

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Core tool components
    bash jq dialog coreutils file findutils grep sed gawk curl wget ca-certificates locales bash-completion udev dbus systemd-sysv systemd-resolved fastfetch \
    # User-requested basic development/editing tools
    git nano sudo \
    # Network and SSH tools
    openssh-server net-tools iptables iputils-ping iproute2 dnsutils \
    # procps process tools for system monitoring
    procps \
    # Core kernel module support
    kmod tzdata && \
    ############################################## KDE Support ################################################
    # Minimal KDE
    # Remove the underlying system's exclusion rules for translation files (.mo) to prevent packet loss during desktop installation
    sed -i 's|^path-exclude=/usr/share/locale/\*/LC_MESSAGES/\*.mo|#&|' /etc/dpkg/dpkg.cfg.d/excludes || true && \
    if [ "$BUILD_KDE" = "Min" ]; then \
        apt-get install -y --no-install-recommends \
        dbus-x11 x11-xserver-utils fonts-noto-cjk fonts-noto-color-emoji kde-plasma-desktop kubuntu-settings-desktop kubuntu-wallpapers \
        pipewire pipewire-pulse wireplumber powerdevil kscreen plasma-pa ark kwin-x11 upower konsole \
        dolphin kate kinfocenter mesa-utils pulseaudio-utils vulkan-tools dbus-user-session \
        polkit-kde-agent-1 libpam-systemd libpam-modules plasma-session-x11; \
    fi && \
    # Full KDE
    if [ "$BUILD_KDE" = "Full" ]; then \
        apt-get install -y --no-install-recommends \
        dbus-x11 x11-xserver-utils fonts-noto-cjk fonts-noto-color-emoji kde-plasma-desktop kubuntu-settings-desktop kubuntu-wallpapers \
        pipewire pipewire-pulse wireplumber powerdevil kscreen plasma-pa ark kwin-x11 upower konsole \
        dolphin kate kinfocenter mesa-utils pulseaudio-utils vulkan-tools dbus-user-session aha clinfo dmidecode libdisplay-info-bin pciutils wayland-utils xserver-xorg \
        kfind plasma-systemmonitor filelight glmark2 vkmark systemsettings kde-config-screenlocker kio-extras xdg-user-dirs dolphin-plugins ffmpegthumbs kdegraphics-thumbnailers \
        kimageformat6-plugins plasma-browser-integration libcanberra-pulse gstreamer1.0-plugins-base gstreamer1.0-plugins-good sound-theme-freedesktop \
        polkit-kde-agent-1 libpam-systemd libpam-modules libpam-kwallet5 plasma-session-x11 qt6-translations-l10n; \
    fi && \
    ######################################################################################################
    # Input method fcitx5 (Optional)
    if [ "$ENABLE_srf_ARG" = "true" ]; then \
        apt-get install -y fcitx5; \
    fi && \
    ## Development tools integration (Optional)
    if [ "$ENABLE_kfgj_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends \
        build-essential gcc g++ make cmake autoconf automake libtool pkg-config clang llvm python3 python3-pip python3-dev python3-venv python-is-python3; \
    fi && \
    ## Compression tools extension (Optional)
    if [ "$ENABLE_zip_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends \
        zip unzip p7zip-full bzip2 xz-utils tar gzip; \
    fi && \
    ## Docker (Optional)
    if [ "$ENABLE_docker_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends \
        docker.io docker-compose-v2; \
    fi && \
    ## TMOE integration (Optional)
    if [ "$ENABLE_tmoe_ARG" = "true" ]; then \
        git clone --depth=1 https://github.com/2moe/tmoe-linux.git /usr/local/etc/tmoe-linux/git && \
        ln -sf /usr/local/etc/tmoe-linux/git/debian.sh /usr/local/bin/tmoe && \
        chmod -R 755 /usr/local/etc/tmoe-linux; \
    fi && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Force configuration to use iptables-legacy
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# Configure Locale & SSH
RUN sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen && \
    export DEBIAN_FRONTEND=noninteractive && \
    locale-gen && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 && \
    mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    # Ubuntu's default user is ubuntu, delete it to avoid conflicts
    deluser --remove-home ubuntu || true && \
    # Create notshroud user and add directly to shadow group to ensure lock screen authentication permissions
    useradd -m -s /bin/bash -G shadow notshroud && echo "notshroud:1234" | chpasswd && \
    systemctl enable ssh

# Add environment variables
RUN cat <<'EOF' > /etc/environment
MESA_LOADER_DRIVER_OVERRIDE=kgsl
TU_DEBUG=noconform
XCURSOR_SIZE=48
XMODIFIERS=@im=fcitx5
GTK_IM_MODULE=fcitx5
QT_IM_MODULE=fcitx5
SDL_IM_MODULE=fcitx5
GLFW_IM_MODULE=fcitx
DISPLAY=:1
EOF

# Audio selection
RUN if [ "$PulseAudio" = "socket" ]; then \
        echo "PULSE_SERVER=unix:/tmp/.pulse-socket" >> /etc/environment; \
    elif [ "$PulseAudio" = "tcp" ]; then \
        echo "PULSE_SERVER=tcp:127.0.0.1:4713" >> /etc/environment; \
    fi

# Input method auto-start and KDE configuration
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
EOF_RUN

# Mesa driver adaptation
RUN if [ "$ENABLE_mesa_ARG" = "true" ]; then \
        echo "--> [Enabled] Downloading and installing latest Mesa drivers..." && \
        URL=$(curl -s https://api.github.com/repos/lfdevs/mesa-for-android-container/releases/latest | \
        jq -r '.assets[] | select(.name | test("mesa-for-android-container_.*_ubuntu_questing_arm64\\.tar\\.gz")) | .browser_download_url' | head -1) && \
        if [ -z "$URL" ] || [ "$URL" = "null" ]; then echo "Failed to get download link, the source repository might not provide the Ubuntu version of the Mesa driver yet, or the API limit was triggered"; exit 1; fi && \
        wget -q --tries=5 --waitretry=3 -O /tmp/mesa.tar.gz "$URL" && \
        tar -zxf /tmp/mesa.tar.gz -C / && \
        rm /tmp/mesa.tar.gz && \
        ldconfig; \
    else \
        echo "--> [Skipped] Mesa driver installation not enabled"; \
    fi

# Fix DHCP network service configuration inside the container
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

# Apply Android runtime environment compatibility fixes (focusing on Systemd and Udev)
RUN <<'EOF_RUN'
# --- 1. General compatibility fixes ---
grep -q '^aid_inet:' /etc/group     || echo 'aid_inet:x:3003:'    >> /etc/group
grep -q '^aid_net_raw:' /etc/group || echo 'aid_net_raw:x:3004:' >> /etc/group
grep -q '^aid_net_admin:' /etc/group || echo 'aid_net_admin:x:3005:' >> /etc/group

getent group droidspaces-gpu >/dev/null || groupadd -g 786 -r droidspaces-gpu
usermod -a -G aid_inet,aid_net_raw,input,video,tty,droidspaces-gpu root || true
usermod -a -G aid_inet,aid_net_raw,input,video,tty,sudo,droidspaces-gpu notshroud || true

grep -q '^_apt:' /etc/passwd && usermod -g aid_inet _apt || true

if [ -f /etc/adduser.conf ]; then
    sed -i '/^EXTRA_GROUPS=/d; /^ADD_EXTRA_GROUPS=/d' /etc/adduser.conf
    echo 'ADD_EXTRA_GROUPS=1' >> /etc/adduser.conf
    echo 'EXTRA_GROUPS="aid_inet aid_net_raw input video tty"' >> /etc/adduser.conf
fi

# --- 2. Specific fixes for Systemd ---
ln -sf /dev/null /etc/systemd/system/systemd-networkd-wait-online.service
ln -sf /dev/null /etc/systemd/system/systemd-journald-audit.socket

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
GUEST_SYSTEMD_PATH="/lib/systemd/system"

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

mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/99-power-key.conf << 'EOF'
[Login]
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandlePowerKeyLongPress=ignore
HandlePowerKeyLongPressHibernate=ignore
EOF

mkdir -p /etc/systemd/system/systemd-udev-trigger.service.d
cat > /etc/systemd/system/systemd-udev-trigger.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/udevadm trigger --subsystem-match=usb --subsystem-match=block --subsystem-match=input --subsystem-match=tty --subsystem-match=net
EOF

for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service systemd-udevd-kernel.socket systemd-udevd-control.socket; do
    mkdir -p "/etc/systemd/system/${unit}.d"
    printf "[Unit]\nConditionPathIsReadWrite=\n" > "/etc/systemd/system/${unit}.d/99-readonly-fix.conf"
done

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

if [ -f /etc/logrotate.conf ]; then
    sed -i 's/^#maxsize.*/maxsize 50M/' /etc/logrotate.conf
    if ! grep -q "maxsize 50M" /etc/logrotate.conf; then
        echo "maxsize 50M" >> /etc/logrotate.conf
    fi
fi

echo "Post-extraction fixes applied on $(date)" > /etc/droidspaces
EOF_RUN

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
        (apt-get purge -y qemu-* binfmt-support || true) && \
        apt-get autoremove -y && \
        apt-get autoclean && \
        rm -rf /var/lib/binfmts/* /etc/binfmt.d/* /usr/lib/binfmt.d/qemu-* && \
        dpkg --add-architecture amd64 && \
        sed -i '/^Types: deb$/a Architectures: arm64 armhf' /etc/apt/sources.list.d/ubuntu.sources && \
        printf "Types: deb\nURIs: http://archive.ubuntu.com/ubuntu/nSuites: noble noble-updates noble-security\nComponents: main universe restricted multiverse\nArchitectures: amd64\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n" > /etc/apt/sources.list.d/ubuntu-amd64.sources && \
        apt-get update && \
        apt-get install -y --no-install-recommends qemu-user-static binfmt-support libc6:amd64; \
    else \
        rm -f /usr/local/bin/qemu-binfmt-register.sh /etc/systemd/system/qemu-binfmt-register.service; \
    fi

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

FROM scratch AS export
COPY --from=customizer / /
