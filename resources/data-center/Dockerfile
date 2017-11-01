FROM phusion/baseimage

LABEL name="hailstorm/data-center-node" \
      description="Builds a data center node compatible with Hailstorm" \
      maintainer="sayantam@gmail.com"

# Enable SSH
RUN rm -f /etc/service/sshd/down

# Install Java
RUN echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" | \
    tee /etc/apt/sources.list.d/webupd8team-java.list && \
    echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" | \
    tee -a /etc/apt/sources.list.d/webupd8team-java.list && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886 && \
    echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections && \
    apt-get update && \
    apt-get install -y oracle-java8-installer oracle-java8-set-default && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install JMeter
ARG JMETER_SOURCE=http://www-us.apache.org/dist//jmeter/binaries/apache-jmeter-3.3.tgz

RUN cd /root && \
    curl -fSLO $JMETER_SOURCE && \
    tar -xzf `basename $JMETER_SOURCE` && \
    ln -s `basename $JMETER_SOURCE | perl -ne 's/\.[a-zA-Z0-9]+$//; print $_'` jmeter && \
    echo '# Added by Hailstorm' >> /root/jmeter/bin/user.properties && \
    echo 'jmeter.save.saveservice.output_format=xml' >> /root/jmeter/bin/user.properties && \
    echo 'jmeter.save.saveservice.hostname=true' >> /root/jmeter/bin/user.properties && \
    echo 'jmeter.save.saveservice.thread_counts=true' >> /root/jmeter/bin/user.properties && \
    rm -f `basename $JMETER_SOURCE`

# SSH keys
RUN /usr/sbin/enable_insecure_key
