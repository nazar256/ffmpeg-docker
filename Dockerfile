ARG FF_VERSION=7.1
ARG ALPINE_VERSION=3.21
ARG FDK_AAC_VERSION=2.0.3
ARG X265_VERSION=4.1

FROM alpine:${ALPINE_VERSION} AS builder

ARG FDK_AAC_VERSION
ARG FF_VERSION
ARG X265_VERSION

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    pkgconfig \
    yasm \
    nasm \
    tar \
    xz \
    wget \
    cmake \
    make \
    autoconf \
    automake \
    libtool \
    x264-dev \
    libvpx-dev \
    opus-dev \
    lame-dev \
    libvorbis-dev \
    libtheora-dev \
    libass-dev \
    libwebp-dev \
    freetype-dev \
    sdl2-dev \
    zlib-dev \
    libdrm-dev

# Build and install libx265
WORKDIR /tmp/x265
RUN wget https://bitbucket.org/multicoreware/x265_git/downloads/x265_${X265_VERSION}.tar.gz && \
    tar xf x265_${X265_VERSION}.tar.gz && \
    cd x265_${X265_VERSION}/build/linux && \
    bash ./make-Makefiles.bash && \
    make -j$(nproc) && \
    make install

# Build and install libfdk-aac
WORKDIR /tmp/fdk-aac
RUN wget https://github.com/mstorsjo/fdk-aac/archive/v${FDK_AAC_VERSION}.tar.gz && \
    tar xf v${FDK_AAC_VERSION}.tar.gz && \
    cd fdk-aac-${FDK_AAC_VERSION} && \
    autoreconf -fiv && \
    ./configure --prefix=/usr --enable-shared && \
    make -j$(nproc) && \
    make install

# Download and build FFmpeg
WORKDIR /tmp/ffmpeg
RUN wget https://ffmpeg.org/releases/ffmpeg-${FF_VERSION}.tar.xz && \
    tar xf ffmpeg-${FF_VERSION}.tar.xz && \
    cd ffmpeg-${FF_VERSION} && \
    ./configure \
        --prefix=/usr \
        --enable-gpl \
        --enable-nonfree \
        --enable-libfdk-aac \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libvpx \
        --enable-libopus \
        --enable-libmp3lame \
        --enable-libvorbis \
        --enable-libtheora \
        --enable-libass \
        --enable-libwebp \
        --enable-libfreetype \
        --enable-sdl2 \
        --disable-debug \
        --disable-doc \
        --extra-cflags="-I/usr/include" \
        --extra-ldflags="-L/usr/lib" && \
    make -j$(nproc) && \
    make install

FROM alpine:${ALPINE_VERSION}

RUN addgroup -g 10000 -S ffmpeg && \
    adduser -S ffmpeg -G ffmpeg -u 10000

COPY --from=builder /usr/bin/* /usr/bin
COPY --from=builder /usr/lib/* /usr/lib
COPY --from=builder /usr/include/* /usr/include

ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/lib

USER 10000

ENTRYPOINT ["ffmpeg"]