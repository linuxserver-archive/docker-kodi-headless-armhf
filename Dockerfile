ARG UBUNTU_VER="bionic"
FROM lsiobase/ubuntu.armhf:${UBUNTU_VER} as buildstage
############## build stage ##############

# package versions
ARG KODI_NAME="Leia"
ARG KODI_VER="18.1"

# defines which addons to build
ARG KODI_ADDONS="vfs.libarchive vfs.rar"

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"

# copy patches and excludes
COPY patches/ /patches/

# install build packages
RUN \
 apt-get update && \
 apt-get install -y \
	autoconf \
	automake \
	autopoint \
	binutils \
	cmake \
	curl \
	default-jre \
	g++ \
	gawk \
	gcc \
	git \
	gperf \
	libass-dev \
	libavahi-client-dev \
	libavahi-common-dev \
	libbluray-dev \
	libbz2-dev \
	libcurl4-openssl-dev \
	libegl1-mesa-dev \
	libflac-dev \
	libfmt-dev \
	libfreetype6-dev \
	libfstrcmp-dev \
	libgif-dev \
	libglew-dev \
	libiso9660-dev \
	libjpeg-dev \
	liblcms2-dev \
	liblzo2-dev \
	libmicrohttpd-dev \
	libmysqlclient-dev \
	libnfs-dev \
	libpcre3-dev \
	libplist-dev \
	libsmbclient-dev \
	libsqlite3-dev \
	libssl-dev \
	libtag1-dev \
	libtiff5-dev \
	libtinyxml-dev \
	libtool \
	libvorbis-dev \
	libxrandr-dev \
	libxslt-dev \
	make \
	nasm \
	python-dev \
	rapidjson-dev \
	swig \
	uuid-dev \
	yasm \
	zip \
	zlib1g-dev

# fetch source and apply any required patches
RUN \
 set -ex && \
 mkdir -p \
	/tmp/kodi-source/build && \
 curl -o \
 /tmp/kodi.tar.gz -L \
	"https://github.com/xbmc/xbmc/archive/${KODI_VER}-${KODI_NAME}.tar.gz" && \
 tar xf /tmp/kodi.tar.gz -C \
	/tmp/kodi-source --strip-components=1 && \
 cd /tmp/kodi-source && \
 git apply \
	/patches/"${KODI_NAME}"/headless.patch

# build package
RUN \
 cd /tmp/kodi-source/build && \
 cmake ../. \
# this block is only for armhf builds
	-DCMAKE_C_FLAGS="-march=armv7-a \
		-mtune=cortex-a7 \
		-mfpu=neon-vfpv4 \
		-mvectorize-with-neon-quad \
		-mfloat-abi=hard" \
# comment everything out in the block for non-armhf builds
	-DCMAKE_INSTALL_LIBDIR=/usr/lib \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-DENABLE_AIRTUNES=OFF \
	-DENABLE_ALSA=OFF \
	-DENABLE_AVAHI=OFF \
	-DENABLE_BLUETOOTH=OFF \
	-DENABLE_BLURAY=ON \
	-DENABLE_CAP=OFF \
	-DENABLE_CEC=OFF \
	-DENABLE_DBUS=OFF \
	-DENABLE_DVDCSS=OFF \
	-DENABLE_GLX=OFF \
	-DENABLE_INTERNAL_FLATBUFFERS=ON \
	-DENABLE_LIBUSB=OFF \
	-DENABLE_NFS=ON \
	-DENABLE_OPENGL=OFF \
	-DENABLE_OPTICAL=OFF \
	-DENABLE_PULSEAUDIO=OFF \
	-DENABLE_SNDIO=OFF \
	-DENABLE_UDEV=OFF \
	-DENABLE_UPNP=ON \
	-DENABLE_VAAPI=OFF \
	-DENABLE_VDPAU=OFF && \
 make -j3 && \
 make DESTDIR=/tmp/kodi-build install

# build kodi addons
RUN \
 set -ex && \
 cd /tmp/kodi-source && \
 make -j3 \
	-C tools/depends/target/binary-addons \
	ADDONS="$KODI_ADDONS" \
	PREFIX=/tmp/kodi-build/usr

# install kodi send
RUN \
 install -Dm755 \
	/tmp/kodi-source/tools/EventClients/Clients/KodiSend/kodi-send.py \
	/usr/bin/kodi-send && \
 install -Dm644 \
	/tmp/kodi-source/tools/EventClients/lib/python/xbmcclient.py \
	/usr/lib/python2.7/xbmcclient.py

FROM lsiobase/ubuntu.armhf:${UBUNTU_VER}

############## runtime stage ##############

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="sparklyballs"

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"
ENV HOME="/config"

# install runtime packages
RUN \
 apt-get update && \
 apt-get install -y \
	--no-install-recommends \
	libass9 \
	libbluray2 \
	libegl1 \
	libfstrcmp0 \
	libgl1 \
	liblcms2-2 \
	liblzo2-2 \
	libmicrohttpd12 \
	libmysqlclient20 \
	libnfs11 \
	libpcrecpp0v5 \
	libpython2.7 \
	libsmbclient \
	libtag1v5 \
	libtinyxml2.6.2v5 \
	libxrandr2 \
	libxslt1.1 && \
	\
# cleanup 
	\
 rm -rf \
	/tmp/* \
	/var/lib/apt/lists/* \
	/var/tmp/*

# copy local files and artifacts of build stages.
COPY root/ /
COPY --from=buildstage /tmp/kodi-build/usr/ /usr/
COPY --from=buildstage /usr/bin/kodi-send /usr/bin/kodi-send
COPY --from=buildstage /usr/lib/python2.7/xbmcclient.py /usr/lib/python2.7/xbmcclient.py

# ports and volumes
VOLUME /config/.kodi
EXPOSE 8080 9090 9777/udp
