ARG TARGETPLATFORM
FROM menci/archlinuxarm:base AS customizer

#######################################################
ARG BUILD_KDE
ARG PulseAudio
ARG ENABLE_binfmt_ARG
ARG ENABLE_mesa_ARG
ARG ENABLE_kfgj_ARG
ARG ENABLE_zip_ARG
ARG ENABLE_docker_ARG
######################################################

# Disable pacman sandbox to fix 'alpm' user and Landlock crashes in Docker/QEMU
RUN sed -i '/\[options\]/a DisableSandbox' /etc/pacman.conf

# Initialize pacman keys and upgrade system
RUN pacman-key --init && \
    pacman-key --populate archlinuxarm && \
    pacman -Syu --noconfirm

# Install Core Tools
RUN pacman -S --noconfirm --needed \
    bash jq dialog coreutils file findutils grep sed gawk curl wget ca-certificates \
    bash-completion udev dbus systemd systemd-resolvconf fastfetch \
    git nano sudo openssh net-tools iptables iputils iproute2 bind procps-ng kmod tzdata

# KDE Installation Blocks
RUN if [ "$BUILD_KDE" = "min" ]; then \
        pacman -S --noconfirm --needed \
        xorg-server xorg-xinit plasma-desktop pipewire pipewire-pulse wireplumber powerdevil \
        plasma-pa ark kwin upower konsole dolphin kate kinforcenter mesa-utils vulkan-tools; \
    fi && \
    if [ "$BUILD_KDE" = "conc" ]; then \
        pacman -S --noconfirm --needed \
        xorg-server xorg-xinit plasma-meta pipewire pipewire-pulse wireplumber powerdevil \
        plasma-pa ark kwin upower konsole dolphin kate kinfocenter mesa-utils vulkan-tools \
        clinfo dmidecode pciutils wayland-utils kfind filelight glmark2 systemsettings \
        dolphin-plugins ffmpegthumbs chromium; \
    fi

# Optional Developer Tools
RUN if [ "$ENABLE_kfgj_ARG" = "true" ]; then \
        pacman -S --noconfirm --needed \
        base-devel gcc make cmake autoconf automake libtool pkgconf clang llvm python python-pip; \
    fi

# Optional Compression Tools
RUN if [ "$ENABLE_zip_ARG" = "true" ]; then \
        pacman -S --noconfirm --needed \
        zip unzip p7zip bzip2 xz tar gzip; \
    fi

# Optional Docker
RUN if [ "$ENABLE_docker_ARG" = "true" ]; then \
        pacman -S --noconfirm --needed docker docker-compose; \
    fi

# Clean Pacman cache to reduce layer size
RUN pacman -Scc --noconfirm

# Generate Locales
RUN sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen && \
    locale-gen && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

# SSH Configuration & User Account Initialization
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    useradd -m -G wheel -s /bin/bash notshroud && \
    echo "notshroud:1234" | chpasswd && \
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Environment Variables
RUN cat <<'EOF' > /etc/environment
MESA_LOADER_DRIVER_OVERRIDE=kgsl
TU_DEBUG=noconform
XCURSOR_SIZE=48
DISPLAY=:1
EOF

# Audio Selection
RUN if [ "$PulseAudio" = "socket" ]; then \
        echo "PULSE_SERVER=unix:/tmp/.pulse-socket" >> /etc/environment; \
    elif [ "$PulseAudio" = "tcp" ]; then \
        echo "PULSE_SERVER=tcp:127.0.0.1:4713" >> /etc/environment; \
    fi

# Session setup
RUN echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)' >> /home/notshroud/.bashrc && \
    if [ "$BUILD_KDE" = "min" ] || [ "$BUILD_KDE" = "conc" ] ; then \
        mkdir -p /home/notshroud/.config && \
        printf "[Compositing]\nEnabled=false\n" > /home/notshroud/.config/kwinrc; \
    fi && \
    chown -R notshroud:notshroud /home/notshroud

# Hardware and Android Network Compatibilities (Replicated to Arch)
RUN groupadd -g 3003 aid_inet && \
    groupadd -g 3004 aid_net_raw && \
    groupadd -g 3005 aid_net_admin && \
    groupadd -g 786 droidspaces-gpu && \
    usermod -a -G aid_inet,aid_net_raw,input,video,tty,droidspaces-gpu root && \
    usermod -a -G aid_inet,aid_net_raw,input,video,tty,droidspaces-gpu notshroud

# Systemd Masking for Guest Env
RUN ln -sf /dev/null /etc/systemd/system/systemd-networkd-wait-online.service && \
    ln -sf /dev/null /etc/systemd/system/systemd-journald-audit.socket && \
    mkdir -p /etc/systemd/logind.conf.d && \
    cat > /etc/systemd/logind.conf.d/99-power-key.conf << 'EOF'
[Login]
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandlePowerKeyLongPress=ignore
HandlePowerKeyLongPressHibernate=ignore
EOF

# --- Aggressive Size Reduction Cleanup ---
# 1. Remove orphaned dependencies
# 2. Clear all pacman package caches
# 3. Delete documentation, man pages, and unnecessary logs
RUN pacman -Rns --noconfirm $(pacman -Qtdq) || true && \
    pacman -Scc --noconfirm && \
    rm -rf /usr/share/doc/* \
           /usr/share/man/* \
           /usr/share/info/* \
           /var/cache/pacman/pkg/* \
           /var/log/* \
           /tmp/* \
           /var/tmp/*

# Phase 2: Export root filesystem to scratch
FROM scratch AS export
COPY --from=customizer / /
