FROM --platform=linux/amd64 ubuntu:18.04 as base

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    set -eux && \
    sed -i -e '$a deb http://archive.ubuntu.com/ubuntu/ xenial main restricted universe multiverse' /etc/apt/sources.list && \
    dpkg --add-architecture i386 && \
    apt-get -q update && \
    apt-get install --no-install-recommends -qq -y \
        software-properties-common \
        build-essential \
        g++-multilib \
        gcc-multilib \
        nano locales curl xterm psmisc \
        libfontconfig1:amd64 \
        libglib2.0-0:amd64 \
        libpng12-0:amd64 \
        libsm6:amd64 \
        libxext6:amd64 \
        libxrender1:amd64 \
        libtcmalloc-minimal4 \
        # for qsys
        #openjdk-8-jre \
        # for modelsim
        libncurses5:i386 \
        libxext6:i386 \
        libxft2:i386 \
        && \
        apt-get install --no-install-recommends -qq -y \
        # for qsys
        openjdk-8-jre && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* && \
        rm -rf /tmp/*


RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    /usr/sbin/update-locale LANG=en_US.UTF-8


FROM base as install

ARG QUARTUS_VER="20.1.0.711"

ADD Quartus-lite-${QUARTUS_VER}-linux.tar /quartus
RUN mkdir -p /opt/quartus && \
    /quartus/setup.sh --mode unattended --disable-components modelsim_ae,modelsim_ase --accept_eula 1 --installdir /opt/quartus


# ModelSim Starter Edition
RUN mkdir -p /opt/quartus && \
    # ModelSim Starter Edition
    /quartus/components/ModelSimSetup-${QUARTUS_VER}-linux.run --modelsim_edition modelsim_ase --mode unattended --accept_eula 1 --installdir /opt/quartus

# disable CPU feature check
RUN sed -i -e '/grep\ sse/{n;s/test\ \$?\ !=\ 0\ /false/}' /opt/quartus/quartus/adm/qenv.sh


# build runtime image
FROM base

# ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4

# build and install freetype
RUN cd /tmp && curl -O https://download-mirror.savannah.gnu.org/releases/freetype/freetype-2.4.12.tar.gz && \
    tar xf freetype-2.4.12.tar.gz && cd freetype-2.4.12 && \
    ./configure --build=i686-pc-linux-gnu "CFLAGS=-m32" "CXXFLAGS=-m32" "LDFLAGS=-m32" && \
    make && \
    cp objs/.libs/* /lib32/ && \
    rm -rf /tmp/*


COPY --from=install /opt/quartus /opt/quartus
CMD ["/opt/quartus/quartus/bin/quartus", "--64bit"]

