FROM ubuntu:14.04.3
MAINTAINER tech <tech@trybrick.com>

RUN apt-get update \
 && apt-get install -y --force-yes --no-install-recommends\
      apt-transport-https \
      ssh-client \
      build-essential \
      curl \
      ca-certificates \
      git \
      libicu-dev \
      lsb-release \
      python-all \
      rlwrap \
      software-properties-common \
      tar \
      g++ flex bison gperf ruby perl \
      libsqlite3-dev libfontconfig1-dev libfreetype6 libssl-dev \
      libpng-dev libjpeg-dev libx11-dev libxext-dev \
 && rm -rf /var/lib/apt/lists/*;

ENV PHANTOMJS_DISABLE_CRASH_DUMPS on
# Which version of node?
ENV NODE_ENGINE 4.2.5
# Locate our binaries
ENV PATH /app/heroku/node/bin/:/app/user/node_modules/.bin:$PATH

# Create some needed directories
RUN mkdir -p /app/heroku/node /app/.profile.d
WORKDIR /app/user

# Install node
RUN curl -s https://s3pository.heroku.com/node/v$NODE_ENGINE/node-v$NODE_ENGINE-linux-x64.tar.gz | tar --strip-components=1 -xz -C /app/heroku/node

# Export the node path in .profile.d
RUN echo "export PATH=\"/app/heroku/node/bin:/app/user/node_modules/.bin:\$PATH\"" > /app/.profile.d/nodejs.sh

ADD package.json /app/user/
ADD . /app/user/
RUN /app/heroku/node/bin/npm install
RUN node node_modules/gulp/bin/gulp

WORKDIR /app/user
RUN chmod +x run.sh
RUN cp run.sh /bin
RUN crontab -l | { cat; echo "0 */2 * * *  /bin/run.sh"; } | crontab -
