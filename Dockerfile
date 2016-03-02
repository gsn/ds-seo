FROM node:4.3-wheezy
MAINTAINER tech <tech@trybrick.com>

RUN apt-get update \
 && apt-get install -y --force-yes --no-install-recommends\
      curl \
      git \
      tar \
      cron \
 && rm -rf /var/lib/apt/lists/*;

ENV PHANTOMJS_DISABLE_CRASH_DUMPS on

# Create some needed directories
RUN mkdir -p /app/user
WORKDIR /app/user

ADD package.json /app/user/
ADD . /app/user/
RUN npm install
RUN node node_modules/gulp/bin/gulp

WORKDIR /app/user
RUN chmod +x run.sh
RUN cp run.sh /bin
RUN crontab -l | { cat; echo "0 */2 * * *  /bin/run.sh"; } | crontab -
EXPOSE 4001

