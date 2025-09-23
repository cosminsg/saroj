#!/bin/sh
export PATH="/usr/sbin:/usr/bin:$PATH"
mkdir -p /var/log

cd /site/startup
php start.php 2>&1 | "$(command -v rotatelogs)" -l /var/log/saroj_runner-%Y-%m-%d.log 86400 &

cd /
exec /usr/sbin/apachectl -D FOREGROUND
