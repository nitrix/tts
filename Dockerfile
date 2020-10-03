FROM ubuntu:18.04

ENV DISPLAY=192.168.2.12:0.0

# ---------------------------------------------------------------------------

# first create user and group for all the X Window stuff
# required to do this first so we have consistent uid/gid between server and client container
RUN addgroup --system xusers \
  && adduser \
			--home /home/xclient \
			--disabled-password \
			--shell /bin/bash \
			--gecos "user for running an xclient application" \
			--ingroup xusers \
			--quiet \
			xclient

# Install packages required for connecting against X Server
RUN apt-get update && apt-get install -y --no-install-recommends \
				xauth \
		&& rm -rf /var/lib/apt/lists/*

# Install some tools required for creating the image.
RUN apt-get update
RUN apt-get install -y git curl unzip ca-certificates wget gnupg software-properties-common

# Install latest Go.
RUN add-apt-repository ppa:longsleep/golang-backports
RUN apt-get install -y golang-go

# Install wine and related packages.
RUN dpkg --add-architecture i386
RUN apt-get update
RUN wget -nc https://dl.winehq.org/wine-builds/winehq.key
RUN apt-key add winehq.key
RUN add-apt-repository 'deb https://dl.winehq.org/wine-builds/ubuntu/ bionic main'
RUN add-apt-repository ppa:cybermax-dexter/sdl2-backport
RUN apt update
RUN apt-get install -y --install-recommends winehq-stable

# Use the latest version of winetricks.
RUN curl -SL 'https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks' -o /usr/local/bin/winetricks
RUN chmod +x /usr/local/bin/winetricks

# Use a dummy sound interface.
COPY etc/asound.conf /etc/asound.conf

# Give permission to everyone on opt.
RUN chmod 777 /opt

# ---------------------------------------------------------------------------

# Wine really doesn't like to be run as root, so let's use a non-root user
USER xclient
ENV HOME /home/xclient
ENV WINEPREFIX /home/xclient/.wine
ENV WINEARCH win32

# SAPI5 support.
RUN winetricks speechsdk

# Install voices.
WORKDIR /opt
RUN wget https://nas.nitrix.me/Setups/IVONA/Justin.exe
RUN wine Justin.exe
RUN rm Justin.exe

# Patch the voice.
COPY ["bin/ivona_sapi5_voice_v1.6.70.dll", "/home/xclient/.wine/drive_c/Program Files/IVONA/IVONA 2 Voice/x86/ivona_sapi5_voice_v1.6.70.dll"]

# Build go project.
RUN mkdir /opt/bin
RUN mkdir /opt/wavs
COPY bin/balcon.exe /opt/bin/balcon.exe
COPY html /opt/html
COPY *.go /opt
COPY *.mod /opt
COPY *.sum /opt
RUN go build -o tts

CMD /opt/tts