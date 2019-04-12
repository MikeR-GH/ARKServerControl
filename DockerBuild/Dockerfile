FROM ubuntu:18.04

RUN set -x \
	&& apt-get update \
	&& apt-get install --yes --no-install-recommends --no-install-suggests \
		lib32stdc++6 \
		lib32gcc1 \
		ca-certificates \
		curl \
		sudo \
		locales \

	# Install Locales and set it to en_US.UTF-8
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
	&& export \
		LANG=en_US.UTF-8 \
		LANGUAGE=en_US:de \
		LC_ALL=en_US.UTF-8 \

	# Install SteamCMD
    && mkdir -p /SteamCMD \
	&& curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -o /SteamCMD/steamcmd_linux.tar.gz \
	&& ls -lsa /SteamCMD \
	&& tar -zxf /SteamCMD/steamcmd_linux.tar.gz -C /SteamCMD \
	&& rm /SteamCMD/steamcmd_linux.tar.gz \
	&& useradd -d /SteamCMD -G sudo -s /bin/bash -u 1050 steam \
	&& chown -R steam: /SteamCMD \
	&& sudo -u steam /SteamCMD/steamcmd.sh +quit \
	
	# Ensuring '/ARK/Server'-Directory
	&& mkdir -p /ARK/Server \
	&& chown -R steam: /ARK/Server \
	
	# Cleanup
	&& apt-get clean autoclean \
	&& apt-get autoremove -y \
	&& rm -rf /var/lib/apt/lists/*

COPY ./sysctl.conf /etc/sysctl.conf
COPY ./limits.conf /etc/security/limits.conf
COPY ./common-session /etc/pam.d/common-session

COPY ./Server.sh /ARK/Server.sh

CMD ["/ARK/Server.sh"]
