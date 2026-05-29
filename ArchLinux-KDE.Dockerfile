ARG TARGETPLATFORM
FROM menci/archlinuxarm:base AS customizer

#######################################################
ARG ENABLE_binfmt_ARG
ARG ENABLE_kfgj_ARG
ARG ENABLE_zip_ARG
ARG ENABLE_docker_ARG
######################################################

# Disable pacman sandbox to prevent QEMU/Docker build crashes
RUN sed -i '/\[options\]/a DisableSandbox' /etc/pacman.conf

# Initialize pacman keys and upgrade system
RUN pacman-key --init && \
    pacman-key --populate archlinuxarm && \
    pacman -Syu --noconfirm

# Install Base Minimum CLI Tools (Strictly No GUI)
RUN pacman -S --noconfirm --needed \
    bash jq dialog coreutils file findutils grep sed gawk curl wget ca-certificates \
    bash-completion udev dbus systemd systemd-resolvconf fastfetch \
    git nano sudo openssh net-tools iptables iputils iproute2 bind procps-ng kmod tzdata

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

# Clean Pacman cache to keep the layer small
RUN pacman -Scc --noconfirm

# Generate Locales
RUN sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen && \
    locale-gen && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

# SSH Configuration & CLI User Account Initialization
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    useradd -m -G wheel -s /bin/bash notshroud && \
    echo "notshroud:1234" | chpasswd && \
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Hardware and Android Network Compatibilities
RUN groupadd -g 3003 aid_inet && \
    groupadd -g 3004 aid_net_raw && \
    groupadd -g 3005 aid_net_admin && \
    groupadd -g 786 droidspaces-gpu && \
    usermod -a -G aid_inet,aid_net_raw,input,video,tty,droidspaces-gpu root && \
    usermod -a -G aid_inet,aid_net_raw,input,video,tty,droidspaces-gpu notshroud

# Systemd Masking for Guest Environment Stability
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
