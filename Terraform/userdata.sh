#!/bin/bash
# Connect to RDS instance using the endpoint
mysql -h '${aws_db_instance.mysql-rds.endpoint}' -u admin -p'yourpass' -e "CREATE DATABASE IF NOT EXISTS web_2_tier; exit;"
mysql -h '${aws_db_instance.mysql-rds.endpoint}' -u admin -p'yourpass' -e "CREATE DATABASE IF NOT EXISTS web_3_tier; exit;"
cd /var/www
cd inc
cat <<EOL > dbinfo.inc
<?php
define('DB_SERVER','${aws_db_instance.mysql-rds.endpoint}');
define('DB_USERNAME', 'admin');
define('DB_PASSWORD', 'yourpass');
define('DB_DATABASE', 'db_web_2_tier');
?>
EOL
