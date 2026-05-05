FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Install all dependencies including rclone
RUN apt-get update && apt-get install -y \
    csh tcsh libgomp1 bash tmux \
    curl wget unzip python3-pip \
    && pip3 install gdown \
    && curl https://rclone.org/install.sh | bash \
    && rm -rf /var/lib/apt/lists/*

# Download Intel version (Revision A)
RUN gdown "1tpTmLUj_OcZ4sG_BrgmBxhm54nK2Vdcq" -O /tmp/gaussian16_A.tbz

# Download AMD version (Revision C)
RUN gdown "137SGJleaSIXUeW1Qg9eWkNkCCZQ1Oup_" -O /tmp/gaussian16_C.tbz

# Download GaussView
RUN gdown "1rgWqk7qqeavQYANjOsNg7O8Bn_wrns8f" -O /tmp/gv6.tar.bz2

# Extract Intel version
RUN mkdir -p /gaussian_intel && \
    tar xvjf /tmp/gaussian16_A.tbz -C /gaussian_intel/ && \
    rm -f /tmp/gaussian16_A.tbz

# Extract AMD version
RUN mkdir -p /gaussian_amd && \
    tar xvJf /tmp/gaussian16_C.tbz -C /gaussian_amd/ && \
    rm -f /tmp/gaussian16_C.tbz

# Extract GaussView into both
RUN tar xvjf /tmp/gv6.tar.bz2 -C /gaussian_intel/g16/ && \
    tar xvjf /tmp/gv6.tar.bz2 -C /gaussian_amd/g16/ && \
    rm -f /tmp/gv6.tar.bz2

# Permissions for both versions
RUN groupadd gaussian && \
    chown -R root:gaussian /gaussian_intel/ /gaussian_amd/ && \
    chmod -R 770 /gaussian_intel/ /gaussian_amd/ && \
    chgrp -R gaussian /gaussian_intel/g16/gv /gaussian_amd/g16/gv

# Scratch directory
RUN mkdir -p /gaussian/scratch && chmod 777 /gaussian/scratch

# Auto backup script
RUN cat > /gaussian/auto_backup.sh << 'BACKUP'
#!/bin/bash
INTERVAL=1800
DESTINATION="storage:Outputs/backups/"
SCRIPT_LOG="/gaussian/backup.log"
echo "=====================================" >> $SCRIPT_LOG
echo "Auto backup started: $(date)" >> $SCRIPT_LOG
echo "=====================================" >> $SCRIPT_LOG
while true; do
    echo "[$(date)] Uploading files to Drive..." >> $SCRIPT_LOG
    rclone copy /gaussian/ $DESTINATION \
        --include "*.log" \
        --include "*.chk" \
        --include "*.fchk" \
        --include "*.out" \
        --exclude "backup.log" \
        2>> $SCRIPT_LOG
    echo "[$(date)] Upload complete. Next in 30 mins." >> $SCRIPT_LOG
    echo "------" >> $SCRIPT_LOG
    sleep $INTERVAL
done
BACKUP
RUN chmod +x /gaussian/auto_backup.sh

# Main startup script
RUN cat > /startup.sh << 'EOF'
#!/bin/bash

echo "========================================="
echo "         GAUSSIAN 16 CONTAINER"
echo "========================================="

# Step 1 - Restore rclone config
echo "[1/4] Restoring rclone config..."
mkdir -p ~/.config/rclone
gdown "1miGraxJNCCuDY7vAdBjyk1LKC5sVOtAx" -O ~/.config/rclone/rclone.conf

if rclone lsd storage: > /dev/null 2>&1; then
    echo "      rclone connected to Google Drive ✓"
else
    echo "      rclone connection failed - token may have expired"
fi

# Step 2 - Detect CPU
echo "[2/4] Detecting CPU type..."
CPU_VENDOR=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $3}')
echo "      CPU Vendor: $CPU_VENDOR"

if echo "$CPU_VENDOR" | grep -qi "amd"; then
    echo "      AMD detected → Loading Revision C"
    G16ROOT=/gaussian_amd
else
    echo "      Intel detected → Loading Revision A"
    G16ROOT=/gaussian_intel
fi

# Step 3 - Set Gaussian environment
echo "[3/4] Setting up Gaussian environment..."
export g16root=$G16ROOT
export GAUSS_SCRDIR=/gaussian/scratch
export PATH=$PATH:$G16ROOT/g16
. $G16ROOT/g16/bsd/g16.profile

# Write to bashrc for all future shells
cat > /root/.bashrc << BASHRC
export g16root=$G16ROOT
export GAUSS_SCRDIR=/gaussian/scratch
export PATH=\$PATH:$G16ROOT/g16
. $G16ROOT/g16/bsd/g16.profile
BASHRC

echo "      Gaussian loaded from: $G16ROOT ✓"

# Step 4 - Start auto backup
echo "[4/4] Starting auto backup every 30 mins..."
nohup bash /gaussian/auto_backup.sh > /dev/null 2>&1 &
echo "      Auto backup running ✓"

echo "========================================="
echo "  Container ready!"
echo "  CPU:     $CPU_VENDOR"
echo "  G16:     $G16ROOT"
echo "  Scratch: /gaussian/scratch"
echo "  Backup:  Every 30 mins to Drive"
echo "========================================="

sleep infinity
EOF

RUN chmod +x /startup.sh

ENV GAUSS_SCRDIR=/gaussian/scratch

CMD ["bash", "/startup.sh"]
