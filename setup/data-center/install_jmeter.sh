#!/usr/bin/env bash
# $1: URL to fetch JMeter
# $2: Directory to install to
cd $2 && \
curl -fSLO $1 && \
tar -xzf `basename $1` && \
ln -s `basename $1 | perl -ne 's/\.[a-zA-Z0-9]+$//; print $_'` jmeter && \
echo '# Added by Hailstorm' >> $2/jmeter/bin/user.properties && \
echo 'jmeter.save.saveservice.output_format=xml' >> $2/jmeter/bin/user.properties && \
echo 'jmeter.save.saveservice.hostname=true' >> $2/jmeter/bin/user.properties && \
echo 'jmeter.save.saveservice.thread_counts=true' >> $2/jmeter/bin/user.properties && \
rm -f `basename $1`
