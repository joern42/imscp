SET FOREIGN_KEY_CHECKS=0;
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
CREATE DATABASE IF NOT EXISTS `{DATABASE_NAME}` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `{DATABASE_NAME}`;

CREATE TABLE IF NOT EXISTS `imscp_autoreply` (
  `autoreplyTime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `autoreplyFrom` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `autoreplTo` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  KEY `autoreplyTime` (`autoreplyTime`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_client_props` (
  `clientPropsID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `accountExpireDate` timestamp NULL DEFAULT NULL,
  `domainsLimit` int(11) NOT NULL DEFAULT '0',
  `mailAccountsLimit` int(11) NOT NULL DEFAULT '0',
  `ftpAccountsLimit` int(11) NOT NULL DEFAULT '0',
  `mailQuotaLimit` int(11) NOT NULL DEFAULT '0',
  `sqlDatabasesLimit` int(11) NOT NULL DEFAULT '0',
  `sqlUsersLimit` int(11) NOT NULL DEFAULT '0',
  `monthlyTrafficLimit` int(11) NOT NULL DEFAULT '0',
  `diskspaceLimit` int(11) NOT NULL DEFAULT '0',
  `diskUsage` int(11) NOT NULL DEFAULT '0',
  `webDataUsage` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `mailDataUsage` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `sqlDataUsage` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `php` tinyint(1) NOT NULL DEFAULT '0',
  `phpConfigLevel` enum('per_domain','per_site','per_user') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'per_site',
  `phpEditor` tinyint(1) NOT NULL DEFAULT '0',
  `phpEditorPermissions` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `phpEditorLimits` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `cgi` tinyint(1) NOT NULL DEFAULT '0',
  `customDNS` tinyint(1) NOT NULL DEFAULT '0',
  `externalMailServer` tinyint(1) NOT NULL DEFAULT '0',
  `supportSystem` tinyint(1) NOT NULL DEFAULT '0',
  `backup` varchar(12) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'dmn|mail|sql',
  `webstats` tinyint(1) NOT NULL DEFAULT '0',
  `webFolderProtection` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`clientPropsID`),
  UNIQUE KEY `userID` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_config` (
  `configName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `configValue` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`configName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

INSERT IGNORE INTO `imscp_config` (`configName`, `configValue`) VALUES
('DATABASE_REVISION', '0'),
('PORT_DNS', '53;tcp;DNS;1;0.0.0.0'),
('PORT_FTP', '21;tcp;FTP;1;0.0.0.0'),
('PORT_HTTP', '80;tcp;HTTP;1;0.0.0.0'),
('PORT_HTTPS', '443;tcp;HTTPS;0;0.0.0.0'),
('PORT_IMAP', '143;tcp;IMAP;1;0.0.0.0'),
('PORT_IMAP-SSL', '993;tcp;IMAP-SSL;0;0.0.0.0'),
('PORT_IMSCP_DAEMON', '9876;tcp;i-MSCP-Daemon;1;127.0.0.1'),
('PORT_POP3', '110;tcp;POP3;1;0.0.0.0'),
('PORT_POP3-SSL', '995;tcp;POP3-SSL;0;0.0.0.0'),
('PORT_SMTP', '25;tcp;SMTP;1;0.0.0.0'),
('PORT_SMTP-SSL', '465;tcp;SMTP-SSL;0;0.0.0.0'),
('PORT_SSH', '22;tcp;SSH;1;0.0.0.0'),
('PORT_TELNET', '23;tcp;TELNET;1;0.0.0.0');

CREATE TABLE IF NOT EXISTS `imscp_dns_record` (
  `dnsRecordID` int(11) NOT NULL AUTO_INCREMENT,
  `dnsZoneID` int(11) UNSIGNED NOT NULL,
  `ownerName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ttl` int(11) UNSIGNED NOT NULL DEFAULT '10800',
  `class` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL,
  `pref` int(11) UNSIGNED DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ownedBy` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'imscp',
  `status` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`dnsRecordID`),
  UNIQUE KEY `dnsRecord` (`dnsZoneID`,`ownerName`,`class`,`type`,`pref`,`name`),
  KEY `status` (`status`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_dns_zone` (
  `dnsZoneID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `zoneTTL` int(11) UNSIGNED NOT NULL DEFAULT '10800',
  `origin` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '@',
  `class` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'IN',
  `mname` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `rname` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `serial` int(11) UNSIGNED NOT NULL,
  `refresh` int(11) UNSIGNED NOT NULL DEFAULT '10800',
  `retry` int(11) UNSIGNED DEFAULT '3600',
  `expire` int(11) UNSIGNED NOT NULL DEFAULT '1209600',
  `ttl` int(11) UNSIGNED DEFAULT '3600',
  `status` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`dnsZoneID`),
  UNIQUE KEY `origin` (`origin`),
  KEY `userID` (`userID`),
  KEY `status` (`status`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_email_template` (
  `emailTemplateID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `subject` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `body` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`emailTemplateID`),
  KEY `userID` (`userID`),
  KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_error_page` (
  `errorPageID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `code` enum('401','403','404','500','503') COLLATE utf8mb4_unicode_ci NOT NULL,
  `content` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`errorPageID`),
  KEY `userID` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_ftp_group` (
  `ftpGroupID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `groupName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `gid` int(11) UNSIGNED NOT NULL,
  `members` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`ftpGroupID`),
  UNIQUE KEY `groupname` (`groupName`),
  KEY `userID` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_ftp_user` (
  `ftpUserID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `ftpGroupID` int(11) UNSIGNED NOT NULL,
  `username` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `uid` int(11) UNSIGNED NOT NULL,
  `gid` int(11) UNSIGNED NOT NULL,
  `shell` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '/bin/sh',
  `homedir` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`ftpUserID`),
  UNIQUE KEY `username` (`username`),
  KEY `userID` (`userID`),
  KEY `ftpGroupID` (`ftpGroupID`),
  KEY `status` (`status`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_hosting_plan` (
  `hostingPlanID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `properties` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` tinyint(1) UNSIGNED NOT NULL,
  PRIMARY KEY (`hostingPlanID`),
  KEY `userID` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_htaccess` (
  `htaccessID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `htpasswdID` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `htgroupID` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `authName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `authType` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `path` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`htaccessID`),
  KEY `userID` (`userID`),
  KEY `status` (`status`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_htgroup` (
  `htgroupID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `groupName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `members` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`htgroupID`),
  KEY `userID` (`userID`),
  KEY `status` (`status`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_htpasswd` (
  `htpasswdID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `username` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`htpasswdID`),
  KEY `userID` (`userID`),
  KEY `status` (`status`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_ip_address` (
  `ipAddressID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `ipAddress` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `netmask` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `nic` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `configMode` varchar(6) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'auto',
  `status` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`ipAddressID`),
  UNIQUE KEY `ipAddress` (`ipAddress`),
  KEY `status` (`status`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_log` (
  `logID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `logTime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `log` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`logID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_login` (
  `loginID` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `username` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ipAddress` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `lastAccessTime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `loginCount` tinyint(1) NOT NULL DEFAULT '0',
  `captchaCount` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`loginID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_mail_domain` (
  `mailDomainID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `domainName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`mailDomainID`),
  UNIQUE KEY `domainName` (`domainName`),
  KEY `userID` (`userID`),
  KEY `status` (`status`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_mail_mailbox` (
  `mailboxID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `mailDomainID` int(11) UNSIGNED NOT NULL,
  `mailbox` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `quota` bigint(20) UNSIGNED DEFAULT NULL,
  `aliases` text COLLATE utf8mb4_unicode_ci,
  `autoreply` text COLLATE utf8mb4_unicode_ci,
  `keepLocalCopy` tinyint(1) NOT NULL DEFAULT '1',
  `isCatchall` tinyint(1) NOT NULL DEFAULT '1',
  `isPoActive` tinyint(1) NOT NULL DEFAULT '1',
  `status` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`mailboxID`),
  UNIQUE KEY `mailbox` (`mailbox`),
  KEY `mailDomainID` (`mailDomainID`),
  KEY `poActive` (`isPoActive`),
  KEY `status` (`status`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_menu` (
  `menuID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `menuLevel` enum('A','R','C','AR','AC','RC','ARC') COLLATE utf8mb4_unicode_ci NOT NULL,
  `menuOrder` int(11) UNSIGNED NOT NULL,
  `menuName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `menuLink` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `menuTarget` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '_blank',
  PRIMARY KEY (`menuID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_php_directive` (
  `phpDirectiveID` int(11) NOT NULL AUTO_INCREMENT,
  `webDomainID` int(11) UNSIGNED NOT NULL,
  `directiveName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `directiveValue` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `directiveValidationPattern` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`phpDirectiveID`),
  UNIQUE KEY `webDomainID` (`webDomainID`),
  KEY `directiveName` (`directiveName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_plugin` (
  `pluginID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(250) COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL,
  `info` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `config` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `configPrev` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `priority` int(11) UNSIGNED NOT NULL DEFAULT '0',
  `backend` tinyint(1) NOT NULL DEFAULT '0',
  `lockers` text COLLATE utf8mb4_unicode_ci,
  `error` text COLLATE utf8mb4_unicode_ci,
  `status` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`pluginID`),
  UNIQUE KEY `name` (`name`),
  KEY `priority` (`priority`),
  KEY `status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_quota_limits` (
  `quotaName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `quotaType` enum('user','group','class','all') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'user',
  `perSession` enum('false','true') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'false',
  `limitType` enum('soft','hard') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'soft',
  `bytesInAvail` float NOT NULL DEFAULT '0',
  `bytesOutAvail` float NOT NULL DEFAULT '0',
  `bytesXferAvail` float NOT NULL DEFAULT '0',
  `filesInAvail` int(11) UNSIGNED NOT NULL DEFAULT '0',
  `filesOutAvail` int(11) UNSIGNED NOT NULL DEFAULT '0',
  `filesXferAvail` int(11) UNSIGNED NOT NULL DEFAULT '0',
  PRIMARY KEY (`quotaName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_quota_tallies` (
  `quotaName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `quotaType` enum('user','group','class','all') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'user',
  `bytesInUsed` float NOT NULL DEFAULT '0',
  `bytesOutUsed` float NOT NULL DEFAULT '0',
  `bytesXferUsed` float NOT NULL DEFAULT '0',
  `filesInUsed` int(11) UNSIGNED NOT NULL DEFAULT '0',
  `filesOutUsed` int(11) UNSIGNED NOT NULL DEFAULT '0',
  `filesXferUsed` int(11) UNSIGNED NOT NULL DEFAULT '0',
  PRIMARY KEY (`quotaName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_reseller_props` (
  `resellerPropsID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `domainsLimit` int(11) NOT NULL DEFAULT '0',
  `domainsAssigned` int(11) NOT NULL DEFAULT '0',
  `mailAccountsLimit` int(11) NOT NULL DEFAULT '0',
  `mailaccountsAssigned` int(11) NOT NULL DEFAULT '0',
  `ftpAccountsLimit` int(11) NOT NULL DEFAULT '0',
  `ftpAccountsAssigned` int(11) NOT NULL DEFAULT '0',
  `sqlDatabasesLimit` int(11) NOT NULL DEFAULT '0',
  `sqlDatabasesAssigned` int(11) NOT NULL DEFAULT '0',
  `sqlUsersLimit` int(11) NOT NULL DEFAULT '0',
  `sqlUsersAssigned` int(11) NOT NULL DEFAULT '0',
  `diskspaceLimit` int(11) NOT NULL DEFAULT '0',
  `diskspaceAssigned` int(11) NOT NULL DEFAULT '0',
  `monthlyTrafficLimit` int(11) NOT NULL DEFAULT '0',
  `monthlyTrafficAssigned` int(11) NOT NULL DEFAULT '0',
  `php` tinyint(1) NOT NULL DEFAULT '0',
  `phpEditor` tinyint(1) NOT NULL DEFAULT '0',
  `phpConfigLevel` enum('per_domain','per_site','per_user') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'per_site',
  `phpEditorPermissions` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `phpEditorLimits` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `cgi` tinyint(1) NOT NULL DEFAULT '0',
  `dns` tinyint(1) NOT NULL DEFAULT '0',
  `customDNS` tinyint(1) NOT NULL DEFAULT '0',
  `externalMailServer` tinyint(1) NOT NULL DEFAULT '0',
  `supportSystem` tinyint(1) NOT NULL DEFAULT '0',
  `backup` tinyint(1) NOT NULL DEFAULT '0',
  `webstats` tinyint(1) NOT NULL DEFAULT '0',
  `webFolderProtection` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`resellerPropsID`),
  KEY `userID` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_server_traffic` (
  `trafficTime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `bytesIn` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesOut` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesMailIn` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesMailOut` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesPopIn` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesPopOut` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesWebIn` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesWebOut` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  PRIMARY KEY (`trafficTime`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_sql_database` (
  `sqlDatabaseID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `databaseName` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`sqlDatabaseID`),
  UNIQUE KEY `databaseName` (`databaseName`),
  KEY `userID` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_sql_database_sql_user` (
  `sqlDatabaseID` int(11) UNSIGNED NOT NULL,
  `sqlUserID` int(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`sqlDatabaseID`,`sqlUserID`),
  KEY `sqlUserID` (`sqlUserID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_sql_user` (
  `sqlUserID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `username` varchar(16) COLLATE utf8mb4_unicode_ci NOT NULL,
  `host` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`sqlUserID`),
  KEY `userID` (`userID`),
  KEY `username` (`username`),
  KEY `host` (`host`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_ssl_certificate` (
  `sslCertificateID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `webDomainID` int(11) UNSIGNED NOT NULL,
  `privateKey` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `certificate` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `caBundle` text COLLATE utf8mb4_unicode_ci,
  `hsts` tinyint(1) UNSIGNED NOT NULL DEFAULT '0',
  `hstsMaxAge` int(11) NOT NULL DEFAULT '31536000',
  `hstsIncludeSubdomains` tinyint(1) UNSIGNED NOT NULL DEFAULT '0',
  `status` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`sslCertificateID`),
  UNIQUE KEY `webDomainID` (`webDomainID`),
  KEY `status` (`status`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_ticket` (
  `ticketID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `ticketLevel` int(11) NOT NULL,
  `ticketFrom` int(11) UNSIGNED NOT NULL,
  `ticketTo` int(11) UNSIGNED NOT NULL,
  `ticketStatus` int(11) UNSIGNED NOT NULL,
  `ticketReply` int(11) UNSIGNED DEFAULT NULL,
  `ticketUrgency` int(11) UNSIGNED NOT NULL,
  `ticketDate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ticketSubject` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ticketMessage` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`ticketID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_traffic` (
  `userID` int(11) UNSIGNED NOT NULL,
  `trafficTime` bigint(20) UNSIGNED NOT NULL,
  `web` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `ftp` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `smtp` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `po` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  PRIMARY KEY (`userID`,`trafficTime`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_ui_props` (
  `uiPropsID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `lang` varchar(15) COLLATE utf8mb4_unicode_ci DEFAULT 'browser',
  `layout` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'default',
  `layoutColor` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'black',
  `logo` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `showMenuLabels` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`uiPropsID`),
  UNIQUE KEY `userID` (`userID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_user` (
  `userID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `username` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('admin','reseller','client') COLLATE utf8mb4_unicode_ci NOT NULL,
  `sysName` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sysUID` int(11) DEFAULT NULL,
  `sysGroupName` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sysGID` int(11) UNSIGNED DEFAULT NULL,
  `createdAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updatedAt` timestamp NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `expireAt` timestamp NULL DEFAULT NULL,
  `customerID` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `createdBy` int(11) UNSIGNED DEFAULT NULL,
  `firstName` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lastName` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gender` enum('F','M','U') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'U',
  `firm` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `zip` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `city` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `state` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `country` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fax` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `street1` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `street2` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lastLostPasswordRequestTime` timestamp NULL DEFAULT NULL,
  `lostPasswordKey` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`userID`),
  UNIQUE KEY `username` (`username`),
  KEY `createdBy` (`createdBy`),
  KEY `status` (`status`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_user_ip_address` (
  `userID` int(11) UNSIGNED NOT NULL,
  `ipAddressID` int(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`userID`,`ipAddressID`),
  KEY `ipAddressID` (`ipAddressID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_web_domain` (
  `webDomainID` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `userID` int(11) UNSIGNED NOT NULL,
  `domainName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `domainAliases` text COLLATE utf8mb4_unicode_ci,
  `ipAddresses` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `php` tinyint(1) NOT NULL DEFAULT '0',
  `cgi` tinyint(1) NOT NULL DEFAULT '0',
  `documentRoot` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '/htdocs',
  `forwardURL` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `forwardType` enum('301','302','303','307','308','proxy') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `forwardKeepHost` tinyint(1) DEFAULT NULL,
  `webFolderProtection` tinyint(1) DEFAULT NULL,
  `status` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`webDomainID`),
  UNIQUE KEY `domainName` (`domainName`),
  KEY `userID` (`userID`),
  KEY `status` (`status`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_web_domain_ip_address` (
  `webDomainID` int(11) UNSIGNED NOT NULL,
  `ipAddressID` int(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`webDomainID`,`ipAddressID`),
  KEY `ipAddressID` (`ipAddressID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

ALTER TABLE `imscp_client_props`
  ADD CONSTRAINT `clientPropsConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_dns_record`
  ADD CONSTRAINT `dnsRecordConstraint01` FOREIGN KEY (`dnsZoneID`) REFERENCES `imscp_dns_zone` (`dnsZoneID`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `imscp_dns_zone`
  ADD CONSTRAINT `dnsZoneConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_email_template`
  ADD CONSTRAINT `emailTemplateConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_error_page`
  ADD CONSTRAINT `errorPageConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_ftp_group`
  ADD CONSTRAINT `ftpGroupConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_ftp_user`
  ADD CONSTRAINT `ftpUserConstraint02` FOREIGN KEY (`ftpGroupID`) REFERENCES `imscp_ftp_group` (`ftpGroupID`) ON DELETE CASCADE;

ALTER TABLE `imscp_hosting_plan`
  ADD CONSTRAINT `hostingPlanConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_htaccess`
  ADD CONSTRAINT `htaccessConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_htgroup`
  ADD CONSTRAINT `htgroupConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_htpasswd`
  ADD CONSTRAINT `htpasswdConstraint_01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_mail_domain`
  ADD CONSTRAINT `mailDomainConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_mail_mailbox`
  ADD CONSTRAINT `mailMailboxConstraint01` FOREIGN KEY (`mailDomainID`) REFERENCES `imscp_mail_domain` (`mailDomainID`) ON DELETE CASCADE;

ALTER TABLE `imscp_php_directive`
  ADD CONSTRAINT `phpDirectiveConstraint02` FOREIGN KEY (`webDomainID`) REFERENCES `imscp_web_domain` (`webDomainID`) ON DELETE CASCADE;

ALTER TABLE `imscp_reseller_props`
  ADD CONSTRAINT `resellerPropsConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_sql_database`
  ADD CONSTRAINT `sqlDatabaseConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_sql_database_sql_user`
  ADD CONSTRAINT `sqlDatabaseSqlUserConstraint01` FOREIGN KEY (`sqlDatabaseID`) REFERENCES `imscp_sql_database` (`sqlDatabaseID`) ON DELETE CASCADE,
  ADD CONSTRAINT `sqlDatabaseSqlUserConstraint02` FOREIGN KEY (`sqlUserID`) REFERENCES `imscp_sql_user` (`sqlUserID`) ON DELETE CASCADE;

ALTER TABLE `imscp_sql_user`
  ADD CONSTRAINT `sqlUserConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_ssl_certificate`
  ADD CONSTRAINT `sslCertificateConstraint01` FOREIGN KEY (`webDomainID`) REFERENCES `imscp_web_domain` (`webDomainID`) ON DELETE CASCADE;

ALTER TABLE `imscp_traffic`
  ADD CONSTRAINT `trafficConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_ui_props`
  ADD CONSTRAINT `uiPropsConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_user`
  ADD CONSTRAINT `userConstraint01` FOREIGN KEY (`createdBy`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_user_ip_address`
  ADD CONSTRAINT `userIpAddressConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE,
  ADD CONSTRAINT `userIpAddressConstraint02` FOREIGN KEY (`ipAddressID`) REFERENCES `imscp_ip_address` (`ipAddressID`) ON DELETE CASCADE;

ALTER TABLE `imscp_web_domain`
  ADD CONSTRAINT `webDomainConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`) ON DELETE CASCADE;

ALTER TABLE `imscp_web_domain_ip_address`
  ADD CONSTRAINT `webDomainIpAddressConstraint01` FOREIGN KEY (`webDomainID`) REFERENCES `imscp_web_domain` (`webDomainID`) ON DELETE CASCADE,
  ADD CONSTRAINT `webDomainIpAddressConstraint02` FOREIGN KEY (`ipAddressID`) REFERENCES `imscp_ip_address` (`ipAddressID`) ON DELETE CASCADE;
  

SET FOREIGN_KEY_CHECKS=1;
