#!/bin/bash

# Howto use:
#
# 1. Upload this script on your backup server
# 2. Generate SSH key for root user on backup server
# 3. Add the generated SSH key into authorized_keys file of root user on target server
# 4. Set REMOTE_HOST_IP and REMOTE_HOST_PORT (ssh) variables below
# 5. Adjust the path variables below if needed
# 6. Execute the script as root user on backup server
#
# Note that it is assumed that you'll use default i-MSCP installation layout on target server

TARGET_HOST_IP="<ip>"
TARGET_HOST_SSH_PORT="22"

# i-MSCP config directory
LOCAL_HOST_IMSCP_CONF_DIR="/etc/imscp"
LOCAL_HOST_IMSCP_ROOT_DIR="/var/www/imscp"
LOCAL_HOST_MYSQL_CONF_DIR="/etc/mysql"
LOCAL_HOST_MYSQL_DATA_DIR="/var/lib/mysql"
LOCAL_HOST_WWW_DIR="/var/www/virtual"
LOCAL_HOST_MAIL_DIR="/var/mail/virtual"

# On remote host, run first:
# We don't care about TTY related warnings
ssh root@${TARGET_HOST_IP} -p ${TARGET_HOST_SSH_PORT} <<"SSH_COMMANDS"
mkdir -p ${LOCAL_HOST_IMSCP_CONF_DIR} ${LOCAL_HOST_IMSCP_WWW_DIR} ${LOCAL_HOST_WWW_DIR $LOCAL_HOST_MAIL_DIR}
sed -i.bak '/^Ciphers/d' /etc/ssh/sshd_config
echo "Ciphers $(ssh -Q cipher localhost | paste -d , -s)" >> /etc/ssh/sshd_config
service ssh restart
SSH_COMMANDS

function sync {
    for dir in ${1}/*; do
        if [[ -d ${dir} ]]; then
            echo "Syncing ${dir} directory into ${2}..."
            rsync -az --partial --numeric-ids --info=progress2 --delete -e "ssh -p ${TARGET_HOST_SSH_PORT} -T -c arcfour -o Compression=no -x" ${dir} root@${TARGET_HOST_IP}:${2}
        fi
    done
}

# Sync data
rsync -az --partial --numeric-ids --info=progress2 --delete -e "ssh -p $TARGET_HOST_SSH_PORT -T -c arcfour -o Compression=no -x" ${LOCAL_HOST_IMSCP_CONF_DIR} root@${TARGET_HOST_IP}:/etc
rsync -az --partial --numeric-ids --info=progress2 --delete -e "ssh -p $TARGET_HOST_SSH_PORT -T -c arcfour -o Compression=no -x" ${LOCAL_HOST_IMSCP_ROOT_DIR} root@${TARGET_HOST_IP}:/var/www
rsync -az --partial --numeric-ids --info=progress2 --delete -e "ssh -p $TARGET_HOST_SSH_PORT -T -c arcfour -o Compression=no -x" ${LOCAL_HOST_MYSQL_CONF_DIR} root@${TARGET_HOST_IP}:/etc
rsync -az --partial --numeric-ids --info=progress2 --delete -e "ssh -p $TARGET_HOST_SSH_PORT -T -c arcfour -o Compression=no -x" ${LOCAL_HOST_MYSQL_DATA_DIR} root@${TARGET_HOST_IP}:/var/lib
sync ${LOCAL_HOST_WWW_DIR}/var/www/virtual
sync ${LOCAL_HOST_MAIL_DIR} /var/mail/virtual



#!/usr/bin/perl;

use strict;
use warnings;
use File::Basename;

for my $sqlDumpFile (glob "/usr/local/src/nuxwin_support/mysql/*") {
    my ($dbName) = fileparse($sqlDumpFile, '.sql.gz');
    print "Creating $dbName database\n";
    system("echo 'CREATE DATABASE IF NOT EXISTS `$dbName`' | mysql -u root -pdefault123") == 0 or die("Could not create database: $!");
    print "Restoring $dbName Database\n";
    system("gunzip -c $sqlDumpFile | mysql -u root -pdefault123 '$dbName'") == 0 or warn("WARNING: Could not restore database: $!");
}

<?php


$dbh = new PDO('mysql:host=localhost;dbname=ispcp', 'root', 'default123');
$stmt = $dbh->query('SELECT * from sql_user');

while($row = $stmt->fetch()) {
    $stmt2 = $dbh->query("SELECT * FROM sql_database WHERE sqld_id = {$row['sqld_id']} LIMIT 1");

    if($stmt2->rowCount()) {
        $row2 = $stmt2->fetch();
        $dbh->exec("GRANT ALL PRIVILEGES ON `{$row2['sqld_name']}`.* TO '{$row['sqlu_name']}'@'{$row['sqlu_host']}' IDENTIFIED BY '{$row['sqlu_pass']}'");
    }
}

