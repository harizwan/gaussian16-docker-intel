FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    csh tcsh libgomp1 bash tmux \
    curl wget unzip python3-pip \
    && pip3 install gdown \
    && curl https://rclone.org/install.sh | bash \
    && rm -rf /var/lib/apt/lists/*

# Download Intel version only
RUN gdown "1tpTmLUj_OcZ4sG_BrgmBxhm54nK2Vdcq" -O /tmp/gaussian16_A.tbz

# Download GaussView
RUN gdown "1rgWqk7qqeavQYANjOsNg7O8Bn_wrns8f" -O /tmp/gv6.tar.bz2

# Extract
RUN mkdir -p /gaussian && \
    tar xvjf /tmp/gaussian16_A.tbz -C /gaussian/ && \
    tar xvjf /tmp/gv6.tar.bz2 -C /gaussian/g16/ && \
    rm -f /tmp/gaussian16_A.tbz /tmp/gv6.tar.bz2

# Permissions
RUN groupadd gaussian && \
    chown -R root:gaussian /gaussian/ && \
    chmod -R 770 /gaussian/ && \
    chgrp -R gaussian /gaussian/g16/gv

# Scratch
RUN mkdir -p /gaussian/scratch && chmod 777 /gaussian/scratch

# Startup
RUN printf '#!/bin/bash\n\
mkdir -p ~/.config/rclone\n\
gdown "1miGraxJNCCuDY7vAdBjyk1LKC5sVOtAx" -O ~/.config/rclone/rclone.conf\n\
export g16root=/gaussian\n\
export GAUSS_SCRDIR=/gaussian/scratch\n\
export PATH=$PATH:/gaussian/g16\n\
. /gaussian/g16/bsd/g16.profile\n\
printf "export g16root=/gaussian\nexport GAUSS_SCRDIR=/gaussian/scratch\nexport PATH=\$PATH:/gaussian/g16\n. /gaussian/g16/bsd/g16.profile\n" > /root/.bashrc\n\
mkdir -p /gaussian/input /gaussian/output\n\
nohup bash /gaussian/auto_backup.sh > /dev/null 2>&1 &\n\
echo "Intel Gaussian 16 Ready!"\n\
sleep infinity\n' > /startup.sh && chmod +x /startup.sh

RUN printf '#!/bin/bash\n\
INTERVAL=1800\n\
while true; do\n\
    rclone copy /gaussian/ "storage:Outputs/backups/" --include "*.log" --include "*.chk" --include "*.fchk" --include "*.out" --exclude "backup.log"\n\
    sleep $INTERVAL\n\
done\n' > /gaussian/auto_backup.sh && chmod +x /gaussian/auto_backup.sh

ENV g16root=/gaussian
ENV GAUSS_SCRDIR=/gaussian/scratch

CMD ["bash", "/startup.sh"]
