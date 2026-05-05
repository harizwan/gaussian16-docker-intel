FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    csh \
    tcsh \
    libgomp1 \
    bash \
    tmux \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create group
RUN groupadd gaussian

# Copy Gaussian files
COPY g16/ /gaussian/g16/
COPY gv6/ /gaussian/gv/

# Set permissions
RUN chown -R root:gaussian /gaussian/ && \
    chmod -R 770 /gaussian/ && \
    chgrp -R gaussian /gaussian/g16/gv

# Create scratch directory
RUN mkdir -p /gaussian/scratch && chmod 777 /gaussian/scratch

# Set environment
ENV g16root=/gaussian
ENV GAUSS_SCRDIR=/gaussian/scratch
ENV PATH=$PATH:/gaussian/g16

# Load profile on every bash session
RUN echo ". /gaussian/g16/bsd/g16.profile" >> /root/.bashrc && \
    echo "export g16root=/gaussian" >> /root/.bashrc && \
    echo "export GAUSS_SCRDIR=/gaussian/scratch" >> /root/.bashrc

CMD ["bash", "-c", ". /gaussian/g16/bsd/g16.profile && sleep infinity"]
