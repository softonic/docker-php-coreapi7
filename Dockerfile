FROM php:7-apache

MAINTAINER Basilio Vera <basilio.vera@softonic.com>

ENV APCU_VERSION="5.1.8" \
    LIBMEMCACHED_VERSION="1.0.18-4" \
    MEMCACHED_VERSION="3.0.3"

# ZLIB Module, required by many other modules, like memcached
RUN apt-get update \
    && apt-get install -y zlib1g-dev \
    && apt-get clean \
# Git needed by Igbinary and Memcached
    && apt-get install -y git \
# Basic modules
    && docker-php-ext-install pcntl sockets bcmath mbstring opcache mysqli gettext \
# Igbinary and xDebug modules
    && pecl install igbinary xdebug \
    && docker-php-ext-enable igbinary \
# APCu module
    && pecl install apcu-$APCU_VERSION \
    && docker-php-ext-enable apcu \
# Memcached module with igbinary support. The package provided by PECL does not support it
    && apt-get install -y libmemcached-dev=$LIBMEMCACHED_VERSION \
    && pecl download memcached-$MEMCACHED_VERSION \
    && tar xzvf memcached-$MEMCACHED_VERSION.tgz \
    && cd memcached-$MEMCACHED_VERSION \
    && phpize \
    && ./configure --enable-memcached-igbinary --disable-memcached-sasl \
    && make \
    && make install \
    && docker-php-ext-enable memcached \
    && apt-get clean \
    && rm -rf /var/www/html/*

#------------------------------------------------------------------------------
# Populate root file system:
# - php.ini
# - Modules defaults configuration
#------------------------------------------------------------------------------
ADD rootfs /

# Extra folder for storing SQL Errors. TODO: Change this to another log strategy.
RUN mkdir -p /var/log/sql/ && echo -n > /var/log/sql/sql_error.log && chown -R www-data:www-data /var/log/sql/ \
    && ln -sfT /dev/null "/var/log/sql/sql_error.log" \
# Download Browscap ini file
    && mkdir -p /usr/local/etc/php/extra/ \
    && curl "http://browscap.org/stream?q=Full_PHP_BrowsCapINI" -o /usr/local/etc/php/extra/full_php_browscap.ini \
# Activate Apache mod_info and configure mod_status
    && a2enmod info remoteip && a2enconf common remoteip \
    && sed -i -e "s/#Require ip 192.0.2.0\/24/Require ip 10.0.0.0\/8\n\t\tRequire ip 172.16.0.0\/12\n\t\tRequire ip 192.168.0.0\/16/g" /etc/apache2/mods-available/info.conf \
    && sed -i -e "s/#Require ip 192.0.2.0\/24/Require ip 10.0.0.0\/8\n\t\tRequire ip 172.16.0.0\/12\n\t\tRequire ip 192.168.0.0\/16/g" /etc/apache2/mods-available/status.conf

