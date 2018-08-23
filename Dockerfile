# daemon runs in the background
# run something like tail /var/log/Arogond/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/Arogond:/var/lib/Arogond -v $(pwd)/wallet:/home/Arogon --rm -ti Arogon:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG Arogon_BRANCH=master
ENV Arogon_BRANCH=${Arogon_BRANCH}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost1.58-all-dev \
      librocksdb-dev && \
    git clone https://github.com/Arogon/Arogon.git /src/Arogon && \
    cd /src/Arogon && \
    git checkout $Arogon_BRANCH && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/Arogond /usr/local/bin/Arogond && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/zedwallet /usr/local/bin/zedwallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/Arogond && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/zedwallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/Arogon && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev librocksdb-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the Arogond service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/Arogond Arogond && \
    useradd -s /bin/bash -m -d /home/Arogon Arogon && \
    mkdir -p /etc/services.d/Arogond/log && \
    mkdir -p /var/log/Arogond && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/Arogond/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/Arogond/run && \
    echo "cd /var/lib/Arogond" >> /etc/services.d/Arogond/run && \
    echo "export HOME /var/lib/Arogond" >> /etc/services.d/Arogond/run && \
    echo "s6-setuidgid Arogond /usr/local/bin/Arogond" >> /etc/services.d/Arogond/run && \
    chmod +x /etc/services.d/Arogond/run && \
    chown nobody:nogroup /var/log/Arogond && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/Arogond/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/Arogond/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/Arogond" >> /etc/services.d/Arogond/log/run && \
    chmod +x /etc/services.d/Arogond/log/run && \
    echo "/var/lib/Arogond true Arogond 0644 0755" > /etc/fix-attrs.d/Arogond-home && \
    echo "/home/Arogon true Arogon 0644 0755" > /etc/fix-attrs.d/Arogon-home && \
    echo "/var/log/Arogond true nobody 0644 0755" > /etc/fix-attrs.d/Arogond-logs

VOLUME ["/var/lib/Arogond", "/home/Arogon","/var/log/Arogond"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/Arogon export HOME /home/Arogon s6-setuidgid Arogon /bin/bash"]
