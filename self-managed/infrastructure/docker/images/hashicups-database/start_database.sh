#!/bin/bash

LOGFILE="/tmp/database.log"

export PGDATA="/var/lib/postgresql/data"
export POSTGRES_DB="products"
export POSTGRES_USER="postgres"
export POSTGRES_PASSWORD="p05tgr35"
# Get latest Postgres version installed
PSQL_VERSION=`ls /usr/lib/postgresql -1 | sort -r | head`

PATH=$PATH:/usr/lib/postgresql/${PSQL_VERSION}/bin

killall postgres >> ${LOGFILE} 2>&1 &
rm -rf ${PGDATA}/*

/usr/local/bin/docker-entrypoint.sh postgres >> ${LOGFILE} 2>&1 &

sleep 1

if test -f "${LOGFILE}"; then
    until grep -q "PostgreSQL init process complete; ready for start up." ${LOGFILE}; do
        echo "Postgres is still starting - sleeping ..."
        sleep 2
    done
else
    echo "Something went wrong - exiting"
    exit 1
fi


## Check Parameters
if   [ "$1" == "local" ]; then
    echo "Starting DB on local insteface"
else

    echo "Reloading config to listen on all available interfaces."

    killall postgres >> ${LOGFILE} 2>&1 &

    rm ${PGDATA}/postmaster.pid >> ${LOGFILE} 2>&1 &

    sleep 2

    # cp /home/app/pg_hba.conf /etc/postgresql/${PSQL_VERSION}/main/pg_hba.conf
    cp /home/admin/pg_hba.conf ${PGDATA}/pg_hba.conf

    # printf "\n listen_addresses = 'localhost' \n" >> /etc/postgresql/${PSQL_VERSION}/main/conf.d/listen_address.conf
    printf "\n listen_addresses = '*' \n" >> ${PGDATA}/postgresql.conf

    /usr/local/bin/docker-entrypoint.sh postgres >> ${LOGFILE} 2>&1 &
fi