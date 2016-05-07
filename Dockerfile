# install S3QL with pip
# inspired by:
# https://github.com/xueshanf/docker-s3ql/
# https://github.com/szepeviktor/debian-server-tools/blob/master/package/s3ql-jessie.sh

FROM ubuntu:14.04
MAINTAINER Daniel Jagszent <daniel@jagszent.de>

RUN apt-get update -qq
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y wget

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-setuptools python3-dev python3-pip pkg-config
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y sqlite3 libsqlite3-dev fuse libfuse-dev curl build-essential python3-dev python3-pkg-resources pkg-config mercurial libattr1-dev kmod fuse libfuse-dev libsqlite3-dev libjs-sphinxdoc psmisc

ENV RELEASE_FILE="s3ql-2.18.tar.bz2"
RUN wget -nv -O /usr/src/${RELEASE_FILE}  https://bitbucket.org/nikratio/s3ql/downloads/${RELEASE_FILE}
ADD requirements.txt /usr/src/requirements.txt
RUN cd /usr/src && pip3 install -r requirements.txt
RUN cd /usr/src && pip3 install "${RELEASE_FILE}"

# we need /usr/bin/time executable - the bash builtin does not work for us
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y time

ADD run-benchmark.sh /run-benchmark.sh
ADD traverse_filesystem.sh /traverse_filesystem.sh
RUN chmod +x /run-benchmark.sh /traverse_filesystem.sh

# with this environment variable you can configure the benchmark run
ENV BENCHMARK_CONFIG="200/100/1 200/100/2 400/100/1 400/100/2"

WORKDIR /
CMD ["/run-benchmark.sh"]
