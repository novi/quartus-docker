FROM --platform=linux/amd64 ubuntu:20.04 as base

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    set -eux && \
    apt-get -q update && \
    apt-get install --no-install-recommends -qq -y \
        ca-certificates \
        nano locales curl xterm psmisc xterm \
        libglib2.0-0:amd64 \
		libxkbcommon-x11-0 \
		libx11-xcb1 \
		libdbus-1-3 \
        libtcmalloc-minimal4 \
        libjemalloc2 \
        # for qsys
        libxtst6:amd64 \
		libxi6:amd64 \
        && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* && \
        rm -rf /tmp/*


RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    /usr/sbin/update-locale LANG=en_US.UTF-8

FROM base as libhoard

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    set -eux && \
    apt-get -q update && \
    apt-get install --no-install-recommends -qq -y \
    build-essential \
    git clang llvm-dev

RUN cd /root && git clone https://github.com/emeryberger/Hoard && \
    cd Hoard/src && \
    make

FROM base as install

ARG QUARTUS_VER="21.1.1.850"

ADD Quartus-lite-${QUARTUS_VER}-linux.tar /quartus
RUN mkdir -p /opt/quartus && \
    /quartus/setup.sh --mode unattended --disable-components modelsim_ae --accept_eula 1 --installdir /opt/quartus


# disable CPU feature check
RUN sed -i -e '/grep\ sse/{n;s/test\ \$?\ !=\ 0\ /false/}' /opt/quartus/quartus/adm/qenv.sh


# build runtime image
FROM base

COPY --from=libhoard /root/Hoard/src/libhoard.so /opt/lib/libhoard.so
COPY --from=install /opt/quartus /opt/quartus
# CMD ["/opt/quartus/quartus/bin/quartus", "--64bit"]

