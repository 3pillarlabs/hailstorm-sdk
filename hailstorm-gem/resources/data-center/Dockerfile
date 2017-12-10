FROM phusion/baseimage

LABEL name="hailstorm/data-center-node" \
      description="Builds a data center node compatible with Hailstorm" \
      maintainer="sayantam@gmail.com"

# Enable SSH
RUN rm -f /etc/service/sshd/down

# Install Java
COPY install_java.sh /root/
RUN chmod +x /root/install_java.sh && /root/install_java.sh

# Install JMeter
ARG JMETER_SOURCE=https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-3.2.tgz
COPY install_jmeter.sh /root/
RUN chmod +x /root/install_jmeter.sh && /root/install_jmeter.sh $JMETER_SOURCE /root

# SSH keys
RUN /usr/sbin/enable_insecure_key
