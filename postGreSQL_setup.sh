#!/bin/bash
# -*- coding: UTF8 -*-

##
#   PostGreSQL debian installation
#
#   Tested on debian 6 (squeeze)
#   @timestamp 2012/12/07 16:21:16
#
#   Sources :
#   @see http://www.postgresql.org/download/linux/debian/
#   @see http://php.net/manual/en/pgsql.installation.php
#   @see http://phppgadmin.sourceforge.net/
#

#       Debian includes PostgreSQL by default. To install PostgreSQL on Debian, use the apt-get (or other apt-driving) command:
apt-get install postgresql -y

#       Then install php support
apt-get install php5-pgsql -y
service apache2 restart


#----------------------------------------
#       Setup first user
#       @todo 2012/12/07 17:05:11 - rewrite those for inline execution

su - postgres
psql
    CREATE USER mypguser WITH PASSWORD 'mypguserpass';
    \q


#----------------------------------------
#       Setup first database

psql
    CREATE DATABASE mypgdatabase;
    GRANT ALL PRIVILEGES ON DATABASE mypgdatabase to mypguser;
    \q


#----------------------------------------
#       Install PhpPgAdmin
#       @see http://phppgadmin.sourceforge.net/doku.php?id=download

#       Edit conf/config.inc.php,
#           replace :
$conf['servers'][0]['host'] = '';
#           with :
$conf['servers'][0]['host'] = 'localhost';



#----------------------------------------
#       Snippets

#       Import a backup file
pg_restore --username "mypguser" --dbname "mypgdatabase" --verbose --ignore-version /path/to/file/dump.backup




#------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#       Alternative packets (untested)
#       @see https://wiki.postgresql.org/wiki/Apt

#       Import the repository key from http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc:
wget -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | sudo apt-key add -

#       Edit /etc/apt/sources.list.d/pgdg.list. The distributions are called codename-pgdg. In the example, replace squeeze with the actual distribution you are using:
deb http://apt.postgresql.org/pub/repos/apt/ squeeze-pgdg main

#       Configure apt's package pinning to prefer the PGDG packages over the Debian ones in /etc/apt/preferences.d/pgdg.pref:
#       Note: this will replace all your Debian/Ubuntu packages with available packages from the PGDG repository. If you do not want this, skip this step.
Package: *
Pin: release o=apt.postgresql.org
Pin-Priority: 500

#       Update the package lists, and install the pgdg-keyring package to automatically get repository key updates:
apt-get update
apt-get install pgdg-keyring

