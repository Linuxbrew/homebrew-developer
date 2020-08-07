FROM debian/eol:wheezy
LABEL name="homebrew/debian7"
ARG DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       autoconf \
       bison \
       ca-certificates \
       curl \
       file \
       flex \
       gettext \
       gcc \
       g++ \
       libcurl4-openssl-dev \
       libz-dev \
       make \
       software-properties-common \
       sudo \
       texinfo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash linuxbrew \
    && echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3003
RUN curl -sL https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.28.0.tar.gz | tar xz \
    && cd /git-2.28.0 \
    && make configure \
    && ./configure --prefix=/usr/local \
    && make install NO_TCLTK=1 \
    && rm -rf /git-2.28.0 \
    && ln -fs /usr/local/bin/git /usr/bin/git

USER linuxbrew
WORKDIR /home/linuxbrew
ENV PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH \
    SHELL=/bin/bash

RUN git clone https://github.com/Homebrew/brew /home/linuxbrew/.linuxbrew/Homebrew \
     && mkdir /home/linuxbrew/.linuxbrew/bin \
     && ln -s ../Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/ \
     && brew config
