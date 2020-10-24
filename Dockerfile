FROM debian:10 as builder

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8 NODE_VERSION=v12.15.0

RUN apt-get update && apt-get install -y locales \
        && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# install node
RUN apt-get update && apt-get install -y wget xz-utils
ADD docker/node-installer.sh /usr/local/sbin
RUN chmod +x /usr/local/sbin/node-installer.sh && node-installer.sh
ENV PATH=/usr/local/lib/nodejs/bin:$PATH

# node service requirements
RUN apt-get update && apt-get install -y xfsprogs fatresize dosfstools open-iscsi lsscsi sg3-utils multipath-tools scsitools nfs-common cifs-utils sudo 

# npm requirements
# gcc and g++ required by grpc-usd until proper upstream support
RUN apt-get install -y python make gcc g++

WORKDIR /home/csi/app
COPY package*.json ./
RUN npm install

FROM debian:10-slim

ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
        && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG=en_US.utf8 NODE_VERSION=v12.15.0

RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM"

# install node
COPY --from=builder /usr/local/lib/nodejs /usr/local/lib/nodejs
ENV PATH=/usr/local/lib/nodejs/bin:$PATH

# node service requirements
RUN apt-get update && \
        apt-get install -y xfsprogs fatresize dosfstools open-iscsi lsscsi sg3-utils multipath-tools scsitools nfs-common cifs-utils sudo && \
        rm -rf /var/lib/apt/lists/*

# install wrappers
ADD docker/iscsiadm /usr/local/sbin
RUN chmod +x /usr/local/sbin/iscsiadm

# Run as a non-root user
RUN useradd --create-home csi \
        && mkdir /home/csi/app \
        && chown -R csi: /home/csi
WORKDIR /home/csi/app
USER csi

COPY --from=builder --chown=csi:csi /home/csi/app/package*.json ./
COPY --from=builder --chown=csi:csi /home/csi/app/node_modules ./node_modules

COPY --chown=csi:csi . .

USER root

EXPOSE 50051
ENTRYPOINT [ "bin/democratic-csi" ]
