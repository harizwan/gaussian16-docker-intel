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

# Extract AMD version (Revision C - xz compression)
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

# Auto backup script using printf to avoid heredoc issues
RUN printf '#!/bin/bash\n\
INTERVAL=1800\n\
DESTINATION="storage:Outputs/backups/"\n\
SCRIPT_LOG="/gaussian/backup.log"\n\
echo "=====================================" >> $SCRIPT_LOG\n\
echo "Auto backup started: $(date)" >> $SCRIPT_LOG\n\
echo "=====================================" >> $SCRIPT_LOG\n\
while true; do\n\
    echo "[$(date)] Uploading files to Drive..." >> $SCRIPT_LOG\n\
    rclone copy /gaussian/ $DESTINATION \\\n\
        --include "*.log" \\\n\
        --include "*.chk" \\\n\
        --include "*.fchk" \\\n\
        --include "*.out" \\\n\
        --exclude "backup.log" \\\n\
        2>> $SCRIPT_LOG\n\
    echo "[$(date)] Upload complete. Next in 30 mins." >> $SCRIPT_LOG\n\
    echo "------" >> $SCRIPT_LOG\n\
    sleep $INTERVAL\n\
done\n' > /gaussian/auto_backup.sh && chmod +x /gaussian/auto_backup.sh

# Main startup script
RUN printf '#!/bin/bash\n\
echo "========================================="\n\
echo "         GAUSSIAN 16 CONTAINER"\n\
echo "========================================="\n\
\n\
# Step 1 - Restore rclone config\n\
echo "[1/4] Restoring rclone config..."\n\
mkdir -p ~/.config/rclone\n\
gdown "1miGraxJNCCuDY7vAdBjyk1LKC5sVOtAx" -O ~/.config/rclone/rclone.conf\n\
if rclone lsd storage: > /dev/null 2>&1; then\n\
    echo "      rclone connected to Google Drive"\n\
else\n\
    echo "      rclone connection failed - token may have expired"\n\
fi\n\
\n\
# Step 2 - Detect CPU\n\
echo "[2/4] Detecting CPU type..."\n\
CPU_VENDOR=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '"'"'{print $3}'"'"')\n\
echo "      CPU Vendor: $CPU_VENDOR"\n\
if echo "$CPU_VENDOR" | grep -qi "amd"; then\n\
    echo "      AMD detected - Loading Revision C"\n\
    G16ROOT=/gaussian_amd\n\
else\n\
    echo "      Intel detected - Loading Revision A"\n\
    G16ROOT=/gaussian_intel\n\
fi\n\
\n\
# Step 3 - Set Gaussian environment\n\
echo "[3/4] Setting up Gaussian environment..."\n\
export g16root=$G16ROOT\n\
export GAUSS_SCRDIR=/gaussian/scratch\n\
export PATH=$PATH:$G16ROOT/g16\n\
. $G16ROOT/g16/bsd/g16.profile\n\
printf "export g16root=$G16ROOT\nexport GAUSS_SCRDIR=/gaussian/scratch\nexport PATH=\$PATH:$G16ROOT/g16\n. $G16ROOT/g16/bsd/g16.profile\n" > /root/.bashrc\n\
echo "      Gaussian loaded from: $G16ROOT"\n\
\n\
# Step 4 - Start auto backup\n\
echo "[4/4] Starting auto backup every 30 mins..."\n\
nohup bash /gaussian/auto_backup.sh > /dev/null 2>&1 &\n\
echo "      Auto backup running"\n\
\n\
echo "========================================="\n\
echo "  Container ready!"\n\
echo "  CPU:     $CPU_VENDOR"\n\
echo "  G16:     $G16ROOT"\n\
echo "  Scratch: /gaussian/scratch"\n\
echo "  Backup:  Every 30 mins to Drive"\n\
echo "========================================="\n\
\n\
sleep infinity\n' > /startup.sh && chmod +x /startup.sh

ENV GAUSS_SCRDIR=/gaussian/scratch

CMD ["bash", "/startup.sh"]
