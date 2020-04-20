FROM ubuntu:18.04

COPY ./CPP_SendCommand /ARK/Service/Server/CPP_SendCommand

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
		cmake \
		make \
		g++ \

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
	&& curl "https://raw.githubusercontent.com/MikeR-GH/Control.Sh/v0.8.4/control.sh" -o /ARK/Service/Server/control.sh \
	&& chmod +x /ARK/Service/Server/control.sh \

	# Installing Control.Sh for the Restart-Service
	&& mkdir -p /ARK/Service/Restart \
	&& curl "https://raw.githubusercontent.com/MikeR-GH/Control.Sh/v0.8.4/control.sh" -o /ARK/Service/Restart/control.sh \
	&& chmod +x /ARK/Service/Restart/control.sh \

	# Installing Control.Sh for the PauseIdleServer-Service
	&& mkdir -p /ARK/Service/PauseIdleServer \
	&& curl "https://raw.githubusercontent.com/MikeR-GH/Control.Sh/v0.8.4/control.sh" -o /ARK/Service/PauseIdleServer/control.sh \
	&& chmod +x /ARK/Service/PauseIdleServer/control.sh \

	# Build CPP_SendCommand
	&& mkdir -p /ARK/Service/Server/build \
	&& cd /ARK/Service/Server/build \
	&& cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_BUILD_TYPE=Release -G 'Unix Makefiles' /ARK/Service/Server/CPP_SendCommand \
	&& make -j4 \
	&& cd .. \
	&& cp build/cpp_sendcommand ./sendcommand \
	&& rm -rf ./build \

	# Cleanup
	&& apt-get clean autoclean \
	&& apt-get remove --yes cmake g++ \
	&& apt-get autoremove --yes \
	&& rm -rf /var/lib/apt/lists/*

COPY ./sysctl.conf /etc/sysctl.conf
COPY ./limits.conf /etc/security/limits.conf
COPY ./common-session /etc/pam.d/common-session

# Startup
COPY ./startup.sh /ARK/startup.sh
# Log
COPY ./log.sh /ARK/log.sh

# sendcommand.sh & listplayers.sh
COPY ./Service/Server/sendcommand.sh /ARK/Service/Server/sendcommand.sh
COPY ./Service/Server/listplayers.sh /ARK/Service/Server/listplayers.sh
# Service: Server
COPY ./Service/Server/control.cfg /ARK/Service/Server/control.cfg
COPY ./Service/Server/run.sh /ARK/Service/Server/run.sh
# Service: Restart
COPY ./Service/Restart/control.cfg /ARK/Service/Restart/control.cfg
COPY ./Service/Restart/run.sh /ARK/Service/Restart/run.sh
# Service: PauseIdleServer
COPY ./Service/PauseIdleServer/control.cfg /ARK/Service/PauseIdleServer/control.cfg
COPY ./Service/PauseIdleServer/run.sh /ARK/Service/PauseIdleServer/run.sh

# Chown: /ARK
RUN chown -R steam: /ARK

CMD ["/ARK/startup.sh"]
