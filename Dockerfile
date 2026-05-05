FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    csh tcsh libgomp1 bash tmux curl wget python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install gdown

RUN gdown "1tpTmLUj_OcZ4sG_BrgmBxhm54nK2Vdcq" -O /tmp/gaussian16.tbz

RUN gdown "1rgWqk7qqeavQYANjOsNg7O8Bn_wrns8f" -O /tmp/gv6.tar.bz2

RUN mkdir -p /gaussian && \
    cd /tmp && \
    tar xvjf gaussian16.tbz -C /gaussian/ && \
    mkdir -p /gaussian/g16 && \
    tar xvjf gv6.tar.bz2 -C /gaussian/g16/ && \
    rm -f /tmp/gaussian16.tbz /tmp/gv6.tar.bz2

RUN groupadd gaussian && \
    chown -R root:gaussian /gaussian/ && \
    chmod -R 770 /gaussian/ && \
    chgrp -R gaussian /gaussian/g16/gv

RUN mkdir -p /gaussian/scratch && chmod 777 /gaussian/scratch

ENV g16root=/gaussian
ENV GAUSS_SCRDIR=/gaussian/scratch
ENV PATH=$PATH:/gaussian/g16

RUN echo ". /gaussian/g16/bsd/g16.profile" >> /root/.bashrc && \
    echo "export g16root=/gaussian" >> /root/.bashrc && \
    echo "export GAUSS_SCRDIR=/gaussian/scratch" >> /root/.bashrc

CMD ["bash", "-c", ". /gaussian/g16/bsd/g16.profile && sleep infinity"]
