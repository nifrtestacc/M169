FROM moodlehq/moodle-php-apache:8.2

LABEL maintainer="Kubilay Yildiz"
LABEL version="1.0."

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
      wget \
      unzip \
      zip \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --branch MOODLE_401_STABLE https://github.com/moodle/moodle.git /var/www/html

COPY config.php /var/www/html/config.php

COPY php.ini /usr/local/etc/php/conf.d/99-moodle.ini

RUN chown -R www-data:www-data /var/www/html /var/www/moodledata \
 && chmod -R 755 /var/www/html \
 && chmod -R 0777 /var/www/moodledata
