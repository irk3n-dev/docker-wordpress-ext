# https://hub.docker.com/_/wordpress?tab=tags&name=latest
ARG BASE_IMAGE=wordpress:latest

FROM ${BASE_IMAGE}

LABEL maintainer="Kenuan Sequera"

USER root

SHELL ["/bin/bash", "-c"]

# if set to 1 debug tools are added to the image (htop,less,mc,vim)
ARG DEBUG_BUILD=0

ARG DEBIAN_FRONTEND=noninteractive
ARG LC_ALL=C

RUN \
  set -eu && \
  echo "#################################################" && \
  echo "Installing OS updates..." && \
  echo "#################################################" && \
  apt-get update -y && \
  # https://github.com/phusion/baseimage-docker/issues/319
  apt-get install --no-install-recommends -y apt-utils 2> >( grep -v 'debconf: delaying package configuration, since apt-utils is not installed' >&2 ) && \
  apt-get upgrade -y && \
  #
  if [ "${DEBUG_BUILD}" = "1" ]; then \
     echo "#################################################" && \
     echo "Installing debugging tools..." && \
     echo "#################################################" && \
     apt-get install --no-install-recommends -y libcomerr2 mc && \
     apt-get install --no-install-recommends -y htop less procps vim && \
     echo -e 'set ignorecase\n\
set showmatch\n\
set novisualbell\n\
set noerrorbells\n\
set number\n\
set nowrap\n\
syntax enable\n\
set mouse-=a' > ~/.vimrc; \
  fi && \
  echo "#################################################" && \
  echo "Installing LDAP client support..." && \
  echo "#################################################" && \
  apt-get install -y libldap2-dev && \
  docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
  docker-php-ext-install ldap && \
  apt-get purge -y libldap2-dev && \
  #
  echo "#################################################" && \
  echo "Installing OPcache support..." && \
  echo "#################################################" && \
  docker-php-ext-install opcache && \
  #
  echo "#################################################" && \
  echo "Installing pdo_mysql support..." && \
  echo "#################################################" && \
  docker-php-ext-install pdo_mysql && \
  #
  echo "#################################################" && \
  echo "Installing Memcached support..." && \
  echo "#################################################" && \
  apt-get install --no-install-recommends -y libmemcached-dev zlib1g-dev && \
  pecl install memcached && docker-php-ext-enable memcached && \
  #
  echo "#################################################" && \
  echo "Installing Redis support..." && \
  echo "#################################################" && \
  pecl install redis && docker-php-ext-enable redis && \
  #
  echo "#################################################" && \
  echo "Installing APCU support..." && \
  echo "#################################################" && \
  pecl install apcu && echo "extension=apcu.so" > /usr/local/etc/php/conf.d/docker-php-ext-apcu.ini && \
  #
  echo "#################################################" && \
  echo "Installing WP-CLI..." && \
  echo "#################################################" && \
  curl -o /usr/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod a+x /usr/bin/wp && \
  #
  echo "#################################################" && \
  echo "Enabling production ready php ini file..." && \
  echo "#################################################" && \
  ln -s "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" && \
  #
  echo "#################################################" && \
  echo "Extending docker-entrypoint.sh..." && \
  echo "#################################################" && \
  sed -i '/^exec "[$]@"/i source /usr/local/bin/docker-entrypoint-addons.sh' /usr/local/bin/docker-entrypoint.sh && \
  #
  echo "#################################################" && \
  echo "apt-get clean up..." && \
  echo "#################################################" && \
  apt-get remove apt-utils -y && \
  apt-get clean autoclean && \
  apt-get autoremove --purge -y && \
  #
  echo "#################################################" && \
  echo "Removing logs, caches and temp files..." && \
  echo "#################################################" && \
  rm -rf /var/cache/{apt,debconf} \
     /var/lib/apt/lists/* \
     /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} \
     /tmp/* /var/tmp/*

# PHP configurations
RUN \
  set -eux && \
  echo "#################################################" && \
  echo "Set recommended PHP.ini settings" && \
  echo "#################################################" && \
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
  } > /usr/local/etc/php/conf.d/opcache.ini
  # see https://secure.php.net/manual/en/opcache.installation.php
RUN \
  set -eux && \
  { \
    echo 'error_reporting=E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
    echo 'display_errors=Off'; \
    echo 'display_startup_errors=Off'; \
    echo 'log_errors=On'; \
    echo 'error_log=/dev/stderr'; \
    echo 'log_errors_max_len=1024'; \
    echo 'ignore_repeated_errors=On'; \
    echo 'ignore_repeated_source=Off'; \
    echo 'html_errors=Off'; \
  } > /usr/local/etc/php/conf.d/error-logging.ini
  # https://www.php.net/manual/en/errorfunc.constants.php
  # https://github.com/docker-library/wordpress/issues/420#issuecomment-517839670
RUN \
  set -eux && \
  { \
    echo 'file_uploads=On'; \
    echo 'upload_max_filesize=64M'; \
    echo 'post_max_size=64M'; \
  } > /usr/local/etc/php/conf.d/uploads.ini

ENV  \
  INIT_SH_FILE='' \
  WP_FORCE_SSL_ADMIN="false" \
  WP_FORCE_SSL_LOGIN="false" \
  WP_REVERSE_HTTPS_PROXY="true"

COPY docker-entrypoint-addons.sh /usr/local/bin/
