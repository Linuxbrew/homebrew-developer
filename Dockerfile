FROM debian/eol:wheezy
LABEL name="homebrew/debian7"
ARG DEBIAN_FRONTEND=noninteractive

ENV HOMEBREW_ON_DEBIAN7=1
ENV HOMEBREW_CURL_PATH=/usr/bin/curl
ENV HOMEBREW_GIT_PATH=/usr/bin/git

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       autoconf \
       automake \
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
       patch \
       procps \
       software-properties-common \
       sudo \
       texinfo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash linuxbrew \
    && echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3003
RUN curl -sL https://ftp.gnu.org/gnu/tar/tar-1.32.tar.gz | tar xz \
    && cd /tar-1.32 \
    && FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr/local \
    && make install \
    && rm -rf /tar-1.32 \
    && ln -fs /usr/local/bin/tar /usr/bin/tar

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

RUN git clone https://github.com/Homebrew/brew /home/linuxbrew/.linuxbrew/Homebrew

# hadolint ignore=DL3003
RUN cd /home/linuxbrew/.linuxbrew \
  && mkdir -p bin etc include lib opt sbin share var/homebrew/linked Cellar \
  && ln -s ../Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/ \
  && HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_AUTO_UPDATE=1 brew tap homebrew/core \
  && brew cleanup \
  && { git -C /home/linuxbrew/.linuxbrew/Homebrew config --unset gc.auto; true; } \
  && { git -C /home/linuxbrew/.linuxbrew/Homebrew config --unset homebrew.devcmdrun; true; } \
  && rm -rf ~/.cache \
  && chown -R linuxbrew: /home/linuxbrew/.linuxbrew \
  && chmod -R g+w,o-w /home/linuxbrew/.linuxbrew
