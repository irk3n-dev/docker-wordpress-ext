#!/bin/bash

# wp = definitions
if [[ $WP_REVERSE_HTTPS_PROXY == "true" || $WP_REVERSE_HTTPS_PROXY == "1" ]]; then
    echo "Enabling reverse proxy support..."
    if ! grep -q "\$_SERVER\['HTTP_X_FORWARDED_PROTO'\]" wp-config.php; then
      value="if (\$_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https') \$_SERVER['HTTPS']='on';"
      sed -i "0,/^define(.*/s/^define(.*/$value\n&/" wp-config.php # insert before first occurence of "define(..."
    fi

    if ! grep -q "\$_SERVER\['HTTP_X_FORWARDED_HOST'\]" wp-config.php; then
      value="if (isset(\$_SERVER['HTTP_X_FORWARDED_HOST'])) \$_SERVER['HTTP_HOST'] = \$_SERVER['HTTP_X_FORWARDED_HOST'];"
      sed -i "0,/^define(.*/s/^define(.*/$value\n&/" wp-config.php # insert before first occurence of "define(..."
    fi
    if ! grep -q "\$_SERVER\['HTTP_X_FORWARDED_FOR'\]" wp-config.php; then
      value="if (isset(\$_SERVER['HTTP_X_FORWARDED_FOR'])) \$_SERVER['REMOTE_ADDR'] = trim(end(explode(',', \$_SERVER['HTTP_X_FORWARDED_FOR'])));"
      sed -i "0,/^define(.*/s/^define(.*/$value\n&/" wp-config.php # insert before first occurence of "define(..."
    fi
else
  echo "Disabling reverse proxy support..."
  sed -i '/HTTP_X_FORWARDED_PROTO/d' wp-config.php
  sed -i '/HTTP_X_FORWARDED_HOST/d' wp-config.php
  sed -i '/HTTP_X_FORWARDED_FOR/d' wp-config.php
fi

# redis
redis-server --daemonize yes
