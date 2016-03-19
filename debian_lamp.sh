#!/bin/bash
#===============================================================================================
#   System Required:  Debian or Ubuntu (32bit/64bit)
#   Description:  Install lamp for Debian or Ubuntu
#   Author: tennfy <admin@tennfy.com>
#   Intro:  http://www.tennfy.com
#===============================================================================================
clear
echo "#############################################################"
echo "# Install lamp for Debian or Ubuntu (32bit/64bit)"
echo "# Intro: http://www.tennfy.com"
echo "#"
echo "# Author: tennfy <admin@tennfy.com>"
echo "#"
echo "#############################################################"
echo ""
function check_sanity {
	# Do some sanity checking.
	if [ $(/usr/bin/id -u) != "0" ]
	then
		die 'Must be run by root user'
	fi

	if [ ! -f /etc/debian_version ]
	then
		die "Distribution is not supported"
	fi
}

function die {
	echo "ERROR: $1" > /dev/null 1>&2
	exit 1
}
function remove_unneeded {
	if [ -f /usr/lib/sm.bin/smtpd ]
    then
        invoke-rc.d sendmail stop
    fi
	DEBIAN_FRONTEND=noninteractive apt-get -q -y remove --purge sendmail* apache2* samba* bind9* nscd
	invoke-rc.d saslauthd stop
	invoke-rc.d xinetd stop
	update-rc.d saslauthd disable
	update-rc.d xinetd disable
}
function install_dotdeb {
	# add dotdeb.
	dv=$(cut -d. -f1 /etc/debian_version)
	if [ "$dv" = "7" ]; then
	echo -e 'deb http://packages.dotdeb.org wheezy all' >> /etc/apt/sources.list
    echo -e 'deb-src http://packages.dotdeb.org wheezy all' >> /etc/apt/sources.list
	elif [ "$dv" = "6" ]; then
    echo -e 'deb http://packages.dotdeb.org squeeze all' >> /etc/apt/sources.list
    echo -e 'deb-src http://packages.dotdeb.org squeeze all' >> /etc/apt/sources.list
	fi

	#import GnuPG key
	wget http://www.dotdeb.org/dotdeb.gpg
	cat dotdeb.gpg | apt-key add -
	rm dotdeb.gpg
	apt-get update
}
function installmysql(){
	#install mysql
    apt-get install -y mysql-server-5.5 mysql-client-5.5
	# Install a low-end copy of the my.cnf to disable InnoDB
	/etc/init.d/mysql stop
	cat > /etc/mysql/conf.d/lowendbox.cnf <<END
# These values override values from /etc/mysql/my.cnf
[mysqld]
key_buffer_size = 12M
query_cache_limit = 256K
query_cache_size = 4M
init_connect='SET collation_connection = utf8_unicode_ci'
init_connect='SET NAMES utf8' 
character-set-server = utf8 
collation-server = utf8_unicode_ci 
skip-character-set-client-handshake
default_storage_engine = MyISAM
skip-innodb
#log-slow-queries=/var/log/mysql/slow-queries.log  --- error in newer versions of mysql
[client]
default-character-set = utf8
END
	/etc/init.d/mysql start
}
function installphp(){
	#install PHP
	apt-get -y install php5-fpm php5-gd php5-common php5-curl php5-imagick php5-mcrypt php5-memcache php5-mysql php5-cgi php5-cli 
	#edit php
	/etc/init.d/php5-fpm stop
	
	sed -i  s/'listen = 127.0.0.1:9000'/'listen = \/var\/run\/php5-fpm.sock'/ /etc/php5/fpm/pool.d/www.conf
	sed -i  s/'^pm.max_children = [0-9]*'/'pm.max_children = 2'/ /etc/php5/fpm/pool.d/www.conf
	sed -i  s/'^pm.start_servers = [0-9]*'/'pm.start_servers = 1'/ /etc/php5/fpm/pool.d/www.conf
	sed -i  s/'^pm.min_spare_servers = [0-9]*'/'pm.min_spare_servers = 1'/ /etc/php5/fpm/pool.d/www.conf
	sed -i  s/'^pm.max_spare_servers = [0-9]*'/'pm.max_spare_servers = 2'/ /etc/php5/fpm/pool.d/www.conf
	sed -i  s/'memory_limit = 128M'/'memory_limit = 64M'/ /etc/php5/fpm/php.ini
	sed -i  s/'short_open_tag = Off'/'short_open_tag = On'/ /etc/php5/fpm/php.ini
	sed -i  s/'upload_max_filesize = 2M'/'upload_max_filesize = 8M'/ /etc/php5/fpm/php.ini
	
	/etc/init.d/php5-fpm start
}
function installapache(){
#install apache
apt-get -y install apache2 libapache2-mod-php5

a2enmod deflate
a2enmod rewrite

# edit apahce
/etc/init.d/apache2 stop

ln -s /etc/apache2/mods-available/expires.load /etc/apache2/mods-enabled/
ln -s /etc/apache2/mods-available/headers.load /etc/apache2/mods-enabled/

if [ -f /etc/apache2/apache2.conf ]
	then
		sed -i  s/'MaxClients          150'/'MaxClients          20'/ /etc/apache2/apache2.conf
 fi

/etc/init.d/apache2 start
}
function init(){
	remove_unneeded
	install_dotdeb
	echo "-----------" &&
	echo "init successfully!" &&
	echo "-----------"
}
function installlamp(){
if [ ! -d /var/www ];then
        mkdir /var/www
fi
#install zip unzip sendmail
apt-get install -y zip unzip sendmail-bin sendmail

installmysql
installphp
installapache
#set web dir
cd /var/www
wget --no-check-certificate https://raw.githubusercontent.com/tennfy/debian_lamp_tennfy/master/phpMyAdmin.zip
unzip phpMyAdmin.zip

echo "-----------" &&
echo "restart lamp!" &&
echo "-----------"
#restart lamp
/etc/init.d/apache2 restart
/etc/init.d/php5-fpm restart
/etc/init.d/mysql restart
echo "-----------" &&
echo "install successfully!" &&
echo "-----------"
}

function addvirtualhost(){
	echo "input hostname(like tennfy.com):"
	read hostname
	
	/etc/init.d/apache2 stop
	
 cat >/etc/apache2/sites-enabled/${hostname}<<EOF
<virtualhost *:80>
ServerName  ${hostname} 
ServerAlias  www.${hostname} 
DocumentRoot  /var/www/${hostname}
CustomLog /etc/apache2/conf.d/${hostname}/access.log combined
DirectoryIndex index.php index.html
<Directory /var/www/${hostname}>
Options +Includes -Indexes
AllowOverride All
Order Deny,Allow
Allow from All
php_admin_value open_basedir /var/www/${hostname}:/tmp
</Directory>
</virtualhost>
EOF
mkdir /var/www/${hostname}
cd /var/www/${hostname}
chown -R www-data /var/www
cat  >> /var/www/${hostname}/info.php <<EOF
	<?php phpinfo(); ?>
EOF
/etc/init.d/apache2 start
echo "-----------" &&
echo "add successfully!" &&
echo "-----------"
}

######################### Initialization ################################################
check_sanity
action=$1
[  -z $1 ] && action=install
case "$action" in
install)
    installlamp
    ;;
addvhost)
    addvirtualhost
    ;;
init)
    init
    ;;	
*)
    echo "Arguments error! [${action} ]"
    echo "Usage: `basename $0` {init|install|addvhost|repaire}"
    ;;
esac
