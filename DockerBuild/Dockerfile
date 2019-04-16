FROM ubuntu:18.04

RUN set -x \
	&& apt-get update \
	&& apt-get install --yes --no-install-recommends --no-install-suggests \
		lib32stdc++6 \
		lib32gcc1 \
		ca-certificates \
		curl \
		sudo \
		screen \
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
	&& tar -zxf /SteamCMD/steamcmd_linux.tar.gz -C /SteamCMD \
	&& rm /SteamCMD/steamcmd_linux.tar.gz \
	&& useradd -d /SteamCMD -G sudo -s /bin/bash -u 1050 steam \
	&& chown -R steam: /SteamCMD \
	&& sudo -u steam /SteamCMD/steamcmd.sh +quit \
	
	# Ensuring '/ARK/Server'-Directory
	&& mkdir -p /ARK/Server \

	# Installing Control.Sh for the Server-Service
	&& mkdir -p /ARK/Service/Server \
	&& curl "https://raw.githubusercontent.com/MikeR-GH/Control.Sh/v0.6.2/control.sh" -o /ARK/Service/Server/control.sh \
	&& chmod +x /ARK/Service/Server/control.sh \

	# Installing Control.Sh for the Restart-Service
	&& mkdir -p /ARK/Service/Restart \
	&& curl "https://raw.githubusercontent.com/MikeR-GH/Control.Sh/v0.6.2/control.sh" -o /ARK/Service/Restart/control.sh \
	&& chmod +x /ARK/Service/Restart/control.sh \

	# Cleanup
	&& apt-get clean autoclean \
	&& apt-get autoremove -y \
	&& rm -rf /var/lib/apt/lists/*

COPY ./sysctl.conf /etc/sysctl.conf
COPY ./limits.conf /etc/security/limits.conf
COPY ./common-session /etc/pam.d/common-session

# Startup
COPY ./startup.sh /ARK/startup.sh
# Log
COPY ./log.sh /ARK/log.sh

# Service: Server
COPY ./Service/Server/control.cfg /ARK/Service/Server/control.cfg
COPY ./Service/Server/run.sh /ARK/Service/Server/run.sh
# Service: Restart
COPY ./Service/Restart/control.cfg /ARK/Service/Restart/control.cfg
COPY ./Service/Restart/run.sh /ARK/Service/Restart/run.sh

# Chown: /ARK
RUN chown -R steam: /ARK

CMD ["/ARK/startup.sh"]
