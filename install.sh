# A script to automate the installation of a Moodle server. Basically doing the steps listed here:
# https://docs.moodle.org/404/en/Installation_quick_guide

copyOrDownload () {
    echo Copying $1 to $2, mode $3...
    if [ -f $1 ]; then
        cp $1 $2
    elif [ -f moodle-server/$1 ]; then
        cp moodle-server/$1 $2
    else
        wget https://github.com/dhicks6345789/moodle-server/raw/master/$1 -O $2
    fi
    chmod $3 $2
}

# Set default command-line flag values.
servertitle="Moodle Server"

# Read user-defined command-line flags.
while test $# -gt 0; do
    case "$1" in
        -servername)
            shift
            servername=$1
            shift
            ;;
        -servertitle)
            shift
            pagetitle=$1
            shift
            ;;
        -dbpassword)
            shift
            dbpassword=$1
            shift
            ;;
        *)
            echo "$1 is not a recognized flag."
            exit 1;
            ;;
    esac
done

# Check all required flags are set, print a usage message if not.
if [ -z "$servername" ] || [ -z "$dbpassword" ]; then
    echo "Usage: install.sh -servername SERVERNAME -dbpassword DATABASEPASSWORD [-servertitle SERVERTITLE]"
    echo "SERVERNAME: The full domain name of the Moodle server (e.g. moodle.example.com)."
    echo "DATABASEPASSWORD: The root password to set for the MariaDB database."
    echo "Optional: SERVERTITLE: A title for the Moodle server (e.g. \"My Company Moodle Server\"."
    exit 1;
fi

echo Installing Moodle server \""$servertitle"\"...

# Make sure the Apache web server is installed.
if [ ! -d "/etc/apache2" ]; then
    apt install -y apache2
fi

# Make sure the MariaDB database server is installed.
if [ ! -f "/usr/bin/mariadb" ]; then
    apt install -y mariadb-server
    # After installing MariaDB, it seems to be best practice to run the "mysql_secure_installation" script to reconfigure a few default settings to be more secure.
    # Here, we automate this process using the approach outlined at: https://bertvv.github.io/notes-to-self/2015/11/16/automating-mysql_secure_installation/
    mysql --user=root -e "UPDATE mysql.user SET Password=PASSWORD('$dbpassword') WHERE User='root';"
    mysql --user=root --password=$dbpassword -e "DELETE FROM mysql.user WHERE User='';"
    mysql --user=root --password=$dbpassword -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql --user=root --password=$dbpassword -e "DROP DATABASE IF EXISTS test;"
    mysql --user=root --password=$dbpassword -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    mysql --user=root --password=$dbpassword -e "FLUSH PRIVILEGES;"
fi

# Make sure PHP is installed.
if [ ! -d "/etc/php" ]; then
    apt install -y php libapache2-mod-php php-mysql
fi

# Get Moodle 4.4 via Git.
if [ ! -d "moodle" ]; then
    git clone -b MOODLE_404_STABLE git://git.moodle.org/moodle.git
fi

# Create / set up the Moodle database.
mysql --user=root --password=$dbpassword -e "CREATE DATABASE moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql --user=root --password=$dbpassword -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON moodle.* TO 'moodleuser'@'localhost' IDENTIFIED BY '$dbpassword';"

# Set up the Moodle data folder.
if [ ! -d "/var/lib/moodle" ]; then
    mkdir /var/lib/moodle
    chown www-data:www-data /var/lib/moodle
fi

# Copy the Moodle code to the web server.
cp -r moodle /var/www/html
rm /var/www/html/moodle/config-dist.php
copyOrDownload config.php /var/www/html/moodle/config.php 0644
sed -i "s/{{DBPASSWORD}}/$dbpassword/g" /var/www/html/moodle/config.php
sed -i "s/{{SERVERNAME}}/$servername/g" /var/www/html/moodle/config.php

# Set up Crontab if it doesn't already exist.
copyOrDownload crontab crontab 0644
crontab crontab
rm crontab
