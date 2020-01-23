FROM ubuntu:disco

LABEL maintainer="Sebastian Dehn <sdehn@redhat.com>"

ENV LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
    DEBIAN_FRONTEND="noninteractive" \
    DEBCONF_NONINTERACTIVE_SEEN="true" \
    SINUS_USER="1001" \
    SINUS_GROUP="1001" \
    SINUS_DIR="/sinusbot" \
    YTDL_BIN="/usr/local/bin/youtube-dl" \
    YTDL_VERSION="latest" \
    TS3_VERSION="3.3.2" \
    TS3_DL_ADDRESS="https://files.teamspeak-services.com/releases/client/" \
    SINUSBOT_DL_URL="https://www.sinusbot.com/dl/sinusbot.current.tar.bz2"
    # That currently points to the latest beta version of Sinusbot

ENV SINUS_DATA="$SINUS_DIR/data" \
    SINUS_DATA_SCRIPTS="$SINUS_DIR/scripts" \
    SINUS_CONFIG="$SINUS_DIR/config" \
    TS3_DIR="$SINUS_DIR/TeamSpeak3-Client-linux_amd64"

RUN groupadd -g "$SINUS_GROUP" sinusbot && \
    useradd -u "$SINUS_USER" -g "$SINUS_GROUP" -d "$SINUS_DIR" sinusbot


## preesed tzdata
RUN echo "tzdata tzdata/Areas select Europe" > /tmp/preseed.txt; \
    echo "tzdata tzdata/Zones/Europe select Berlin" >> /tmp/preseed.txt; \
    debconf-set-selections /tmp/preseed.txt

RUN dpkg --add-architecture i386 && \
    apt-get -q update -y && \
    apt-get -q upgrade -y && \
    apt-get -q install --no-install-recommends -y tzdata x11vnc xvfb libxcursor1 ca-certificates bzip2 libnss3 libegl1-mesa x11-xkb-utils libasound2 libpci3 libxslt1.1 libxkbcommon0 libxss1 curl \
        libglib2.0-0 locales wget sudo python less libpulse0 && \
    apt-get -q clean all && \
    update-ca-certificates

# worthless and wrong lang shit
RUN locale-gen --purge "$LANG" && \
    update-locale LANG="$LANG" && \
    echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale && \
    echo "LANG=en_US.UTF-8" >> /etc/default/locale

# sinus bot install   
RUN mkdir -p "$SINUS_DIR" && \
    curl -O "$SINUSBOT_DL_URL" && \
    tar -xjf sinusbot.current.tar.bz2 -C "$SINUS_DIR" && \
    rm sinusbot.current.tar.bz2 && \
    mv "$SINUS_DATA_SCRIPTS" "$SINUS_DATA_SCRIPTS-orig" && \
    mkdir -p "$SINUS_CONFIG" "$SINUS_DATA_SCRIPTS" && \
    cp -f "$SINUS_DIR/config.ini.dist" "$SINUS_DIR/config.ini" && \
    sed -i 's|^DataDir.*|DataDir = '"$SINUS_DATA"'|g' "$SINUS_DIR/config.ini"

# TS3 install
RUN mkdir -p "$TS3_DIR" && \
    cd "$SINUS_DIR" || exit 1 && \
    wget -O "TeamSpeak3-Client-linux_amd64-$TS3_VERSION.run" \
        "$TS3_DL_ADDRESS/$TS3_VERSION/TeamSpeak3-Client-linux_amd64-$TS3_VERSION.run" && \
    chmod 755 "TeamSpeak3-Client-linux_amd64-$TS3_VERSION.run" && \
    sed -i -e 's/MS_PrintLicense()/funcPrintLicense()/g' TeamSpeak3-Client-linux_amd64-$TS3_VERSION.run && \
    sed -i -e 's/MS_PrintLicense/#nolic/g' TeamSpeak3-Client-linux_amd64-$TS3_VERSION.run && \
    "./TeamSpeak3-Client-linux_amd64-$TS3_VERSION.run" && \
    rm -f "TeamSpeak3-Client-linux_amd64-$TS3_VERSION.run" && \
    rm TeamSpeak3-Client-linux_amd64/xcbglintegrations/libqxcb-glx-integration.so && \
    mkdir -p TeamSpeak3-Client-linux_amd64/plugins && \
    cp -f "$SINUS_DIR/plugin/libsoundbot_plugin.so" "$TS3_DIR/plugins/" && \
    sed -i "s|^TS3Path.*|TS3Path = \"$TS3_DIR/ts3client_linux_amd64\"|g" "$SINUS_DIR/config.ini"

# youtube dl install
RUN wget -O "$YTDL_BIN" "https://yt-dl.org/downloads/$YTDL_VERSION/youtube-dl" && \
    chmod a+rx "$YTDL_BIN" && \
    "$YTDL_BIN" -U && \
    echo "YoutubeDLPath = \"$YTDL_BIN-speedpatched\"" >> "$SINUS_DIR/config.ini"

# Change ownership and cleanup
RUN chown -fR sinusbot:0 "$SINUS_DIR" && \
    chmod -R 770 "$SINUS_DIR" && \
    rm -rf /tmp/* /var/tmp/*

COPY youtube-dl-speedpatched /usr/local/bin/youtube-dl-speedpatched

COPY entrypoint.sh /entrypoint.sh
WORKDIR "$SINUS_DIR"

ENTRYPOINT ["/entrypoint.sh"]
USER 1001