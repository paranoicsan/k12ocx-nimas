FROM ruby:2.7.1

ENV APP_PATH /app/

WORKDIR $APP_PATH

ADD Gemfile* $APP_PATH
RUN gem install bundler \
    && bundle install --jobs `expr $(cat /proc/cpuinfo | grep -c "cpu cores") - 1` --retry 3 \
    && rm -rf /usr/local/bundle/cache/*.gem \
    && find /usr/local/bundle/gems/ -name "*.c" -delete \
    && find /usr/local/bundle/gems/ -name "*.o" -delete

ADD . $APP_PATH

CMD ["/bin/bash"]
