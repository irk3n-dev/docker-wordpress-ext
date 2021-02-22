FROM wordpress:latest
LABEL maintainer="Kenuan Sequera"
USER root
SHELL ["/bin/bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
ARG LC_ALL=C

# system
#
RUN set -eu && \
  apt-get update -y && \
  apt-get install --no-install-recommends -y apt-utils 2> >( grep -v 'debconf: delaying package configuration, since apt-utils is not installed' >&2 ) && \
  apt-get upgrade -y
RUN apt-get install --no-install-recommends -y git htop less mc procps tar vim wget tidy csstidy netcat \
  brotli \
  imagemagick \
  libc-dev \
  libcomerr2 \
  libjpeg-dev \
  libldap2-dev \
  libmemcached-dev \
  libpng-dev \
  libwebp-dev \
  zlib1g-dev

# services = redis
RUN cd /tmp && \
  wget http://download.redis.io/redis-stable.tar.gz && \
  tar xvzf redis-stable.tar.gz && \
  cd redis-stable && \
  make && \
  make install

# extensions = basic for wordpress
#RUN docker-php-ext-configure gd --with-jpeg && \
# docker-php-ext-install -j "$(nproc)" bcmath exit gd mysqli zip

# extensions = opcache, pdo_mysql
RUN docker-php-ext-install opcache pdo_mysql

# extensions = apcu
RUN pecl install apcu && \
  rm -rf /tmp/pear && \
  docker-php-ext-enable apcu

# extensions = igbinary
RUN pecl install igbinary && \
  rm -rf /tmp/pear && \
  docker-php-ext-enable igbinary

# extensions = redis
RUN mkdir -p /tmp/pear && \
  cd /tmp/pear && \
  pecl bundle redis && \
  cd redis && \
  phpize . && \
  ./configure --enable-redis-igbinary && \
  make && \
  make install && \
  cd ~ && \
  rm -rf /tmp/pear && \
  docker-php-ext-enable redis

# extensions = memcached
RUN mkdir -p /tmp/pear && \
  cd /tmp/pear && \
  pecl bundle memcached && \
  cd memcached && \
  phpize . && \
  ./configure --enable-memcached-igbinary && \
  make && \
  make install && \
  docker-php-ext-enable memcached

# extensions = ldap
RUN docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
  docker-php-ext-install ldap && \
  apt-get purge -y libldap2-dev

# extensions = brotli
#RUN cd /tmp && git clone --recursive --depth=1 https://github.com/kjdev/php-ext-brotli.git && \
# cd php-ext-brotli && \
# phpize && \
# ./configure --with-libbrotli && \
# make && \
# make install && \
# docker-php-ext-enable brotli

# tools = wp-cli
RUN curl -o /usr/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar  && \
  chmod +x /usr/bin/wp

# clean up
RUN apt-get remove apt-utils -y && \
  apt-get clean autoclean && \
  apt-get autoremove --purge -y && \
  rm -rf /tmp/pear && \
  rm -rf /var/lib/apt/lists/*

# PHP configurations
RUN \
  set -eux && \
  ln -s "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" && \
  { \
    echo 'opcache.enable=1'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.log_verbosity_level=1'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.max_wasted_percentage=5'; \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.validate_timestamps=1'; \
  } > /usr/local/etc/php/conf.d/opcache.ini && \
  { \
    echo 'error_reporting=E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
    echo 'display_errors=On'; \
    echo 'display_startup_errors=Off'; \
    echo 'log_errors=On'; \
    echo 'error_log=/dev/stderr'; \
    echo 'log_errors_max_len=1024'; \
    echo 'ignore_repeated_errors=On'; \
    echo 'ignore_repeated_source=Off'; \
    echo 'html_errors=Off'; \
  } > /usr/local/etc/php/conf.d/error-logging.ini && \
  { \
    echo 'file_uploads=On'; \
    echo 'upload_max_filesize=64M'; \
    echo 'post_max_size=96M'; \
    echo 'max_execution_time=600'; \
    echo 'memory_limit=512M'; \
    echo 'max_input_vars=1000'; \
    echo 'max_input_time=400'; \
  } > /usr/local/etc/php/conf.d/uploads.ini

ENV WP_REVERSE_HTTPS_PROXY="true"

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN  chmod +x /docker-entrypoint.sh
ENTRYPOINT [ "/docker-entrypoint.sh" ]

