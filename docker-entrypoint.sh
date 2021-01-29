#!/bin/bash

set -e

# if service discovery was activated, we overwrite the BACKEND_SERVER_LIST with the
# results of DNS service lookup
if [ -n "$DB_SERVICE_NAME" ]; then
  BACKEND_SERVER_LIST=`getent hosts tasks.$DB_SERVICE_NAME|awk '{print $1}'|tr '\n' ' '`
fi



# We break our IP list into array
IFS=', ' read -r -a backend_servers <<< "$BACKEND_SERVER_LIST"


config_file="/etc/maxscale.cnf"

# We start config file creation

cat <<EOF > $config_file
[maxscale]
threads=$MAX_THREADS
admin_enabled = $ADMIN_ENABLED
admin_host = $ADMIN_HOST
admin_port = $ADMIN_PORT
admin_gui = $ADMIN_GUI
admin_secure_gui = $ADMIN_SECURE_GUI

[GaleraService]
type=service
router=readconnroute
router_options=$ROUTER_OPTIONS
servers=${BACKEND_SERVER_LIST// /,}
connection_timeout=$CONNECTION_TIMEOUT
user=$MAX_USER
password=$MAX_PASS
enable_root_user=$ENABLE_ROOT_USER

[GaleraListener]
type=listener
service=GaleraService
protocol=mariadbclient
port=$ROUTER_PORT

[SplitterService]
type=service
router=readwritesplit
servers=${BACKEND_SERVER_LIST// /,}
connection_timeout=$CONNECTION_TIMEOUT
user=$MAX_USER
password=$MAX_PASS
enable_root_user=$ENABLE_ROOT_USER
use_sql_variables_in=$USE_SQL_VARIABLES_IN

[SplitterListener]
type=listener
service=SplitterService
protocol=mariadbclient
port=$SPLITTER_PORT

[GaleraMonitor]
type=monitor
module=galeramon
servers=${BACKEND_SERVER_LIST// /,}
disable_master_failback=1
user=$MAX_USER
password=$MAX_PASS

#[CLI]
#type=service
#router=cli

#[CLIListener]
#type=listener
#service=CLI
#protocol=maxscaled
#port=6603

# Start the Server block
EOF

# add the [server] block
for i in ${!backend_servers[@]}; do
cat <<EOF >> $config_file
[${backend_servers[$i]}]
type=server
address=${backend_servers[$i]}
port=$BACKEND_SERVER_PORT
protocol=MySQLBackend
persistpoolmax=$PERSIST_POOLMAX
persistmaxtime=$PERSIST_MAXTIME

EOF

done

chown maxscale:maxscale $config_file
exec "$@"

