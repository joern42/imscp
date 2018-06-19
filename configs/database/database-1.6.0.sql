SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";

CREATE DATABASE IF NOT EXISTS `{DATABASE_NAME}`
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `{DATABASE_NAME}`;

CREATE TABLE IF NOT EXISTS `imscp_autoreply` (
  `autoreplyTime` datetime     NOT NULL,
  `autoreplyFrom` varchar(255) NOT NULL,
  `autoreplTo`    varchar(255) NOT NULL,
  KEY `autoreplyTime` (`autoreplyTime`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_client_properties` (
  `clientPropertiesID`   int(11) UNSIGNED                                  NOT NULL AUTO_INCREMENT,
  `userID`               int(11) UNSIGNED                                  NOT NULL,
  `accountExpireDate`    datetime                                                   DEFAULT NULL,
  `domainsLimit`         int(11)                                           NOT NULL DEFAULT '0',
  `domainAliasesLimit`   int(11)                                           NOT NULL DEFAULT '0',
  `subdomainsLimit`      int(11)                                           NOT NULL DEFAULT '0',
  `mailboxesLimit`       int(11)                                           NOT NULL DEFAULT '0',
  `mailQuotaLimit`       int(11)                                           NOT NULL DEFAULT '0',
  `ftpUsersLimit`        int(11)                                           NOT NULL DEFAULT '0',
  `sqlDatabasesLimit`    int(11)                                           NOT NULL DEFAULT '0',
  `sqlUsersLimit`        int(11)                                           NOT NULL DEFAULT '0',
  `monthlyTrafficLimit`  int(11)                                           NOT NULL DEFAULT '0',
  `diskspaceLimit`       int(11)                                           NOT NULL DEFAULT '0',
  `diskUsage`            int(11)                                           NOT NULL DEFAULT '0',
  `webDataUsage`         bigint(20) UNSIGNED                               NOT NULL DEFAULT '0',
  `mailDataUsage`        bigint(20) UNSIGNED                               NOT NULL DEFAULT '0',
  `sqlDataUsage`         bigint(20) UNSIGNED                               NOT NULL DEFAULT '0',
  `php`                  tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `phpEditor`            tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `phpConfigLevel`       enum ('domain', 'site', 'user') COLLATE ascii_bin NOT NULL DEFAULT 'site',
  `phpEditorPermissions` text COLLATE ascii_bin                            NOT NULL,
  `phpEditorLimits`      text COLLATE ascii_bin                            NOT NULL,
  `cgi`                  tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `dns`                  tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `dnsEditor`            tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `externalMailServer`   tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `backup`               set ('mail', 'sql', 'web', '') COLLATE ascii_bin           DEFAULT NULL,
  `protectedArea`        tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `customErrorPages`     tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `supportSystem`        tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `webFolderProtection`  tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `webstats`             tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  PRIMARY KEY (`clientPropertiesID`),
  UNIQUE KEY `userID` (`userID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_config` (
  `configName`  varchar(255) CHARACTER SET ascii
  COLLATE ascii_bin                                 NOT NULL,
  `configValue` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`configName`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  ROW_FORMAT = DYNAMIC;

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

CREATE TABLE IF NOT EXISTS `imscp_cp_custom_menu` (
  `cpCustomMenuID` int(11) UNSIGNED                 NOT NULL AUTO_INCREMENT,
  `menuLevel`      enum ('A', 'R', 'C', 'AR', 'AC', 'RC', 'ARC') CHARACTER SET ascii
  COLLATE ascii_bin                                 NOT NULL,
  `menuOrder`      int(11) UNSIGNED                 NOT NULL DEFAULT '0',
  `menuName`       varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `menuLink`       varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `menuTarget`     varchar(128) CHARACTER SET ascii
  COLLATE ascii_bin                                 NOT NULL DEFAULT '_blank',
  `isActive`       tinyint(1) UNSIGNED              NOT NULL DEFAULT '1',
  PRIMARY KEY (`cpCustomMenuID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_dns_record` (
  `dnsRecordID` int(11) UNSIGNED    NOT NULL AUTO_INCREMENT,
  `dnsZoneID`   int(11) UNSIGNED    NOT NULL,
  `serverID`    int(11) UNSIGNED    NOT NULL,
  `name`        varchar(255)        NOT NULL,
  `type`        varchar(15)         NOT NULL,
  `class`       char(2)             NOT NULL,
  `ttl`         int(11)             NOT NULL DEFAULT '3600',
  `rdata`       text                NOT NULL,
  `owner`       varchar(255)        NOT NULL DEFAULT 'core',
  `isActive`    tinyint(1) UNSIGNED NOT NULL DEFAULT '1',
  PRIMARY KEY (`dnsRecordID`),
  KEY `dnsZoneID` (`dnsZoneID`),
  KEY `serverID` (`serverID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_dns_zone` (
  `dnsZoneID` int(11) UNSIGNED    NOT NULL AUTO_INCREMENT,
  `userID`    int(11) UNSIGNED    NOT NULL,
  `serverID`  int(11) UNSIGNED    NOT NULL,
  `zoneType`  enum ('master', 'slave') CHARACTER SET ascii
  COLLATE ascii_bin               NOT NULL DEFAULT 'master',
  `zoneTTL`   int(11) UNSIGNED    NOT NULL DEFAULT '10800',
  `origin`    varchar(255)        NOT NULL,
  `name`      varchar(255)        NOT NULL DEFAULT '@',
  `class`     varchar(15)         NOT NULL DEFAULT 'IN',
  `mname`     varchar(255)        NOT NULL,
  `rname`     varchar(255)        NOT NULL,
  `serial`    int(11) UNSIGNED    NOT NULL,
  `refresh`   int(11) UNSIGNED    NOT NULL DEFAULT '10800',
  `retry`     int(11) UNSIGNED    NOT NULL DEFAULT '3600',
  `expire`    int(11) UNSIGNED    NOT NULL DEFAULT '1209600',
  `ttl`       int(11) UNSIGNED    NOT NULL DEFAULT '3600',
  `isActive`  tinyint(1) UNSIGNED NOT NULL DEFAULT '1',
  PRIMARY KEY (`dnsZoneID`),
  UNIQUE KEY `origin` (`origin`),
  KEY `userID` (`userID`),
  KEY `serverID` (`serverID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_email_template` (
  `emailTemplateID`      int(11) UNSIGNED                 NOT NULL AUTO_INCREMENT,
  `userID`               int(11) UNSIGNED                 NOT NULL,
  `emailTemplateName`    varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `emailTemplateSubject` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `emailTemplateBody`    longtext COLLATE utf8mb4_bin     NOT NULL,
  PRIMARY KEY (`emailTemplateID`),
  KEY `userID` (`userID`),
  KEY `emailTemplateName` (`emailTemplateName`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_ftp_group` (
  `ftpGroupID` int(11) UNSIGNED               NOT NULL AUTO_INCREMENT,
  `userID`     int(11) UNSIGNED               NOT NULL,
  `serverID`   int(11) UNSIGNED               NOT NULL,
  `groupName`  varchar(255) COLLATE ascii_bin NOT NULL,
  `gid`        int(11) UNSIGNED               NOT NULL,
  `members`    text COLLATE ascii_bin,
  PRIMARY KEY (`ftpGroupID`),
  UNIQUE KEY `groupname` (`groupName`),
  KEY `userID` (`userID`),
  KEY `serverID` (`serverID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_ftp_user` (
  `ftpUserID`    int(11) UNSIGNED               NOT NULL AUTO_INCREMENT,
  `userID`       int(11) UNSIGNED               NOT NULL,
  `serverID`     int(11) UNSIGNED               NOT NULL,
  `ftpGroupID`   int(11) UNSIGNED               NOT NULL,
  `username`     varchar(255) COLLATE ascii_bin NOT NULL,
  `passwordHash` varchar(255) COLLATE ascii_bin NOT NULL,
  `uid`          int(11) UNSIGNED               NOT NULL,
  `gid`          int(11) UNSIGNED               NOT NULL,
  `shell`        varchar(255) COLLATE ascii_bin NOT NULL DEFAULT '/bin/sh',
  `homedir`      varchar(255) CHARACTER SET utf8mb4
  COLLATE utf8mb4_bin                           NOT NULL,
  `isActive`     tinyint(1) UNSIGNED            NOT NULL DEFAULT '1',
  PRIMARY KEY (`ftpUserID`),
  UNIQUE KEY `username` (`username`),
  KEY `userID` (`userID`),
  KEY `serverID` (`serverID`),
  KEY `ftpGroupID` (`ftpGroupID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_hosting_plan` (
  `hostingPlanID` int(11) UNSIGNED                NOT NULL AUTO_INCREMENT,
  `userID`        int(11) UNSIGNED                NOT NULL,
  `name`          varchar(255) CHARACTER SET utf8mb4
  COLLATE utf8mb4_bin                             NOT NULL,
  `description`   text COLLATE utf8mb4_unicode_ci NOT NULL,
  `properties`    text CHARACTER SET ascii
  COLLATE ascii_bin                               NOT NULL,
  `isActive`      tinyint(1) UNSIGNED             NOT NULL DEFAULT '1',
  PRIMARY KEY (`hostingPlanID`),
  KEY `userID` (`userID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_ip_address` (
  `ipAddressID` int(11) UNSIGNED                          NOT NULL AUTO_INCREMENT,
  `serverID`    int(11) UNSIGNED                          NOT NULL,
  `ipAddress`   varchar(255) COLLATE ascii_bin            NOT NULL,
  `netmask`     varchar(255) COLLATE ascii_bin            NOT NULL,
  `nic`         varchar(255) COLLATE ascii_bin            NOT NULL,
  `configMode`  enum ('auto', 'manual') COLLATE ascii_bin NOT NULL DEFAULT 'manual',
  PRIMARY KEY (`ipAddressID`),
  UNIQUE KEY `ipAddress` (`ipAddress`),
  KEY `serverID` (`serverID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_job` (
  `jobID`        int(11) UNSIGNED                                                                               NOT NULL AUTO_INCREMENT,
  `userID`       int(11) UNSIGNED                                                                               NOT NULL,
  `serverID`     int(11) UNSIGNED                                                                                        DEFAULT NULL,
  `objectID`     int(11) UNSIGNED                                                                               NOT NULL,
  `moduleName`   varchar(255) COLLATE ascii_bin                                                                 NOT NULL,
  `moduleGroup`  enum ('dns', 'mail', 'plugin', 'server', 'sql', 'web') COLLATE ascii_bin                       NOT NULL,
  `moduleAction` enum ('toadd', 'tochange', 'torestore', 'toenable', 'todisable', 'todelete') COLLATE ascii_bin NOT NULL,
  `moduleData`   longtext CHARACTER SET utf8mb4
  COLLATE utf8mb4_bin                                                                                           NOT NULL,
  `state`        enum ('scheduled', 'pending', 'processed') COLLATE ascii_bin                                   NOT NULL DEFAULT 'scheduled',
  `error`        longtext COLLATE ascii_bin,
  PRIMARY KEY (`jobID`),
  KEY `userID` (`userID`),
  KEY `serverID` (`serverID`),
  KEY `moduleName` (`moduleName`),
  KEY `moduleGroup` (`moduleGroup`),
  KEY `state` (`state`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_log` (
  `logID`   int(11) UNSIGNED         NOT NULL AUTO_INCREMENT,
  `logTime` datetime                 NOT NULL,
  `log`     text COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`logID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_login` (
  `loginID`        varchar(255) COLLATE ascii_bin NOT NULL,
  `username`       varchar(255) CHARACTER SET utf8mb4
  COLLATE utf8mb4_bin                                      DEFAULT NULL,
  `ipAddress`      varchar(255) COLLATE ascii_bin NOT NULL,
  `lastAccessTime` datetime                       NOT NULL,
  `loginCount`     int(11) UNSIGNED               NOT NULL DEFAULT '0',
  `captchaCount`   int(11) UNSIGNED               NOT NULL DEFAULT '0',
  PRIMARY KEY (`loginID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_mailbox` (
  `mailboxID`     int(11) UNSIGNED                 NOT NULL AUTO_INCREMENT,
  `mailDomainID`  int(11) UNSIGNED                 NOT NULL,
  `userID`        int(11) UNSIGNED                 NOT NULL,
  `serverID`      int(11) UNSIGNED                 NOT NULL,
  `mailbox`       varchar(255) CHARACTER SET ascii NOT NULL,
  `passwordHash`  varchar(255) COLLATE ascii_bin            DEFAULT NULL,
  `quota`         bigint(20) UNSIGNED                       DEFAULT NULL,
  `aliases`       text CHARACTER SET ascii,
  `autoreply`     text CHARACTER SET utf8mb4
  COLLATE utf8mb4_bin,
  `keepLocalCopy` tinyint(1) UNSIGNED              NOT NULL DEFAULT '0',
  `isDefault`     tinyint(1) UNSIGNED              NOT NULL DEFAULT '0',
  `isCatchall`    tinyint(1) UNSIGNED              NOT NULL DEFAULT '0',
  `isPoActive`    tinyint(1) UNSIGNED              NOT NULL DEFAULT '1',
  `isActive`      tinyint(1) UNSIGNED              NOT NULL DEFAULT '1',
  PRIMARY KEY (`mailboxID`),
  UNIQUE KEY `mailbox` (`mailbox`),
  KEY `userID` (`userID`),
  KEY `serverID` (`serverID`),
  KEY `mailDomainID` (`mailDomainID`),
  KEY `poActive` (`isPoActive`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_mail_domain` (
  `mailDomainID` int(11) UNSIGNED    NOT NULL AUTO_INCREMENT,
  `userID`       int(11) UNSIGNED    NOT NULL,
  `serverID`     int(11) UNSIGNED    NOT NULL,
  `domainName`   varchar(255)        NOT NULL,
  `automaticDNS` tinyint(1) UNSIGNED NOT NULL DEFAULT '1',
  `isActive`     tinyint(1) UNSIGNED NOT NULL DEFAULT '1',
  PRIMARY KEY (`mailDomainID`),
  UNIQUE KEY `domainName` (`domainName`),
  KEY `userID` (`userID`),
  KEY `serverID` (`serverID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_plugin` (
  `pluginID`   int(11) UNSIGNED         NOT NULL AUTO_INCREMENT,
  `name`       varchar(250) CHARACTER SET ascii
  COLLATE ascii_bin                     NOT NULL,
  `type`       varchar(15) CHARACTER SET ascii
  COLLATE ascii_bin                     NOT NULL,
  `info`       text COLLATE utf8mb4_bin NOT NULL,
  `config`     text COLLATE utf8mb4_bin NOT NULL,
  `configPrev` text COLLATE utf8mb4_bin NOT NULL,
  `priority`   int(11)                  NOT NULL DEFAULT '0',
  `backend`    tinyint(1) UNSIGNED      NOT NULL DEFAULT '0',
  `lockers`    text CHARACTER SET ascii
  COLLATE ascii_bin,
  `error`      text COLLATE utf8mb4_bin,
  `state`      varchar(15) CHARACTER SET ascii
  COLLATE ascii_bin                     NOT NULL,
  PRIMARY KEY (`pluginID`),
  UNIQUE KEY `name` (`name`),
  KEY `priority` (`priority`),
  KEY `state` (`state`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_quota_limits` (
  `quotaName`      varchar(255) CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci                                                NOT NULL,
  `quotaType`      enum ('user', 'group', 'class', 'all') COLLATE ascii_bin NOT NULL DEFAULT 'user',
  `perSession`     enum ('false', 'true') COLLATE ascii_bin                 NOT NULL DEFAULT 'false',
  `limitType`      enum ('soft', 'hard') COLLATE ascii_bin                  NOT NULL DEFAULT 'soft',
  `bytesInAvail`   float                                                    NOT NULL DEFAULT '0',
  `bytesOutAvail`  float                                                    NOT NULL DEFAULT '0',
  `bytesXferAvail` float                                                    NOT NULL DEFAULT '0',
  `filesInAvail`   int(11) UNSIGNED                                         NOT NULL DEFAULT '0',
  `filesOutAvail`  int(11) UNSIGNED                                         NOT NULL DEFAULT '0',
  `filesXferAvail` int(11) UNSIGNED                                         NOT NULL DEFAULT '0',
  PRIMARY KEY (`quotaName`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_quota_tallies` (
  `quotaName`     varchar(255) COLLATE ascii_bin                           NOT NULL,
  `quotaType`     enum ('user', 'group', 'class', 'all') COLLATE ascii_bin NOT NULL DEFAULT 'user',
  `bytesInUsed`   float                                                    NOT NULL DEFAULT '0',
  `bytesOutUsed`  float                                                    NOT NULL DEFAULT '0',
  `bytesXferUsed` float                                                    NOT NULL DEFAULT '0',
  `filesInUsed`   int(11) UNSIGNED                                         NOT NULL DEFAULT '0',
  `filesOutUsed`  int(11) UNSIGNED                                         NOT NULL DEFAULT '0',
  `filesXferUsed` int(11) UNSIGNED                                         NOT NULL DEFAULT '0',
  PRIMARY KEY (`quotaName`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_reseller_properties` (
  `resellerPropertiesID`   int(11) UNSIGNED                                  NOT NULL AUTO_INCREMENT,
  `userID`                 int(11) UNSIGNED                                  NOT NULL,
  `domainsLimit`           int(11)                                           NOT NULL DEFAULT '0',
  `domainsAssigned`        int(11)                                           NOT NULL DEFAULT '0',
  `domainAliasesLimit`     int(11)                                           NOT NULL DEFAULT '0',
  `domainAssigned`         int(11)                                           NOT NULL DEFAULT '0',
  `subdomainsLimit`        int(11)                                           NOT NULL DEFAULT '0',
  `subdomainsAssigned`     int(11)                                           NOT NULL DEFAULT '0',
  `domainAliasesAssigned`  int(11)                                           NOT NULL DEFAULT '0',
  `mailboxesLimit`         int(11)                                           NOT NULL DEFAULT '0',
  `mailaccountsAssigned`   int(11)                                           NOT NULL DEFAULT '0',
  `ftpUsersLimit`          int(11)                                           NOT NULL DEFAULT '0',
  `ftpUsersAssigned`       int(11)                                           NOT NULL DEFAULT '0',
  `sqlDatabasesLimit`      int(11)                                           NOT NULL DEFAULT '0',
  `sqlDatabasesAssigned`   int(11)                                           NOT NULL DEFAULT '0',
  `sqlUsersLimit`          int(11)                                           NOT NULL DEFAULT '0',
  `sqlUsersAssigned`       int(11)                                           NOT NULL DEFAULT '0',
  `diskspaceLimit`         int(11)                                           NOT NULL DEFAULT '0',
  `diskspaceAssigned`      int(11)                                           NOT NULL DEFAULT '0',
  `monthlyTrafficLimit`    int(11)                                           NOT NULL DEFAULT '0',
  `monthlyTrafficAssigned` int(11)                                           NOT NULL DEFAULT '0',
  `php`                    tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `phpEditor`              tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `phpConfigLevel`         enum ('domain', 'site', 'user') COLLATE ascii_bin NOT NULL DEFAULT 'site',
  `phpEditorPermissions`   text COLLATE ascii_bin                            NOT NULL,
  `phpEditorLimits`        text COLLATE ascii_bin                            NOT NULL,
  `cgi`                    tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `dns`                    tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `dnsEditor`              tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `externalMailServer`     tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `supportSystem`          tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `backup`                 tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `protectedArea`          tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `customErrorPages`       tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `webFolderProtection`    tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  `webstats`               tinyint(1) UNSIGNED                               NOT NULL DEFAULT '0',
  PRIMARY KEY (`resellerPropertiesID`),
  KEY `userID` (`userID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_server` (
  `serverID`         int(11) UNSIGNED                                            NOT NULL AUTO_INCREMENT,
  `description`      text CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci                                                     NOT NULL,
  `hostname`         varchar(255) CHARACTER SET ascii                            NOT NULL,
  `type`             enum ('host', 'node') COLLATE ascii_bin                     NOT NULL DEFAULT 'host',
  `metadata`         text COLLATE ascii_bin                                      NOT NULL,
  `hmacSharedSecret` varchar(255) COLLATE ascii_bin                                       DEFAULT NULL,
  `services`         set ('dns', 'ftp', 'http', 'mail', 'sql') COLLATE ascii_bin NOT NULL DEFAULT 'dns,ftp,http,mail,sql',
  `apiVersion`       varchar(20) COLLATE ascii_bin                               NOT NULL,
  `isActive`         tinyint(1) UNSIGNED                                         NOT NULL DEFAULT '1',
  PRIMARY KEY (`serverID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_server_traffic` (
  `trafficTime`  datetime            NOT NULL,
  `serverID`     int(11) UNSIGNED    NOT NULL,
  `bytesIn`      bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesOut`     bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesMailIn`  bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesMailOut` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesPopIn`   bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesPopOut`  bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesWebIn`   bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `bytesWebOut`  bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  PRIMARY KEY (`trafficTime`),
  KEY `serverID` (`serverID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_sql_database` (
  `sqlDatabaseID` int(11) UNSIGNED                       NOT NULL AUTO_INCREMENT,
  `userID`        int(11) UNSIGNED                       NOT NULL,
  `serverID`      int(11) UNSIGNED                       NOT NULL,
  `databaseName`  varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`sqlDatabaseID`),
  UNIQUE KEY `databaseName` (`databaseName`),
  KEY `userID` (`userID`),
  KEY `serverID` (`serverID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_sql_database_sql_user` (
  `sqlDatabaseID` int(11) UNSIGNED NOT NULL,
  `sqlUserID`     int(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`sqlDatabaseID`, `sqlUserID`),
  KEY `sqlUserID` (`sqlUserID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_sql_user` (
  `sqlUserID` int(11) UNSIGNED    NOT NULL AUTO_INCREMENT,
  `userID`    int(11) UNSIGNED    NOT NULL,
  `serverID`  int(11) UNSIGNED    NOT NULL,
  `username`  varchar(16)         NOT NULL,
  `host`      varchar(255)        NOT NULL,
  `isActive`  tinyint(1) UNSIGNED NOT NULL DEFAULT '1',
  PRIMARY KEY (`sqlUserID`),
  KEY `userID` (`userID`),
  KEY `serverID` (`serverID`),
  KEY `username` (`username`),
  KEY `host` (`host`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_ticket` (
  `ticketID`   int(11) UNSIGNED                 NOT NULL AUTO_INCREMENT,
  `fromUserID` int(11) UNSIGNED                 NOT NULL,
  `toUserID`   int(11) UNSIGNED                 NOT NULL,
  `replyTo`    int(11) UNSIGNED                          DEFAULT NULL,
  `date`       datetime                         NOT NULL,
  `level`      tinyint(1) UNSIGNED              NOT NULL,
  `urgency`    int(11) UNSIGNED                 NOT NULL,
  `subject`    varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `body`       text COLLATE utf8mb4_bin         NOT NULL,
  `state`      tinyint(1) UNSIGNED              NOT NULL,
  PRIMARY KEY (`ticketID`),
  KEY `fromUserID` (`fromUserID`),
  KEY `toUserID` (`toUserID`),
  KEY `replyTo` (`replyTo`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_traffic` (
  `userID`      int(11) UNSIGNED    NOT NULL,
  `trafficTime` bigint(20) UNSIGNED NOT NULL,
  `web`         bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `ftp`         bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `smtp`        bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `po`          bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  PRIMARY KEY (`userID`, `trafficTime`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_ui_props` (
  `uiPropsID`      int(11) UNSIGNED               NOT NULL     AUTO_INCREMENT,
  `userID`         int(11) UNSIGNED               NOT NULL,
  `lang`           varchar(15) COLLATE ascii_bin               DEFAULT 'browser',
  `layout`         varchar(100) COLLATE ascii_bin NOT NULL     DEFAULT 'default',
  `layoutColor`    varchar(15) COLLATE ascii_bin  NOT NULL     DEFAULT 'black',
  `layoutLogo`     varchar(255) CHARACTER SET utf8mb4
  COLLATE utf8mb4_bin                                          DEFAULT NULL,
  `showMenuLabels` tinyint(1) UNSIGNED            NOT NULL     DEFAULT '0',
  PRIMARY KEY (`uiPropsID`),
  UNIQUE KEY `userID` (`userID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_user` (
  `userID`                      int(11) UNSIGNED                        NOT NULL AUTO_INCREMENT,
  `createdBy`                   int(11) UNSIGNED                                 DEFAULT NULL,
  `username`                    varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `passwordHash`                varchar(255) CHARACTER SET ascii
  COLLATE ascii_bin                                                     NOT NULL,
  `type`                        enum ('admin', 'client', 'reseller') CHARACTER SET ascii
  COLLATE ascii_bin                                                     NOT NULL,
  `email`                       varchar(255) CHARACTER SET ascii
  COLLATE ascii_bin                                                     NOT NULL,
  `sysName`                     varchar(32) CHARACTER SET ascii
  COLLATE ascii_bin                                                              DEFAULT NULL,
  `sysUID`                      int(11)                                          DEFAULT NULL,
  `sysGroupName`                varchar(32) CHARACTER SET ascii
  COLLATE ascii_bin                                                              DEFAULT NULL,
  `sysGID`                      int(11) UNSIGNED                                 DEFAULT NULL,
  `createdAt`                   datetime                                NOT NULL,
  `updatedAt`                   datetime                                         DEFAULT NULL,
  `expireAt`                    datetime                                         DEFAULT NULL,
  `customerID`                  varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `firstName`                   varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `lastName`                    varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `gender`                      enum ('F', 'M', 'U') CHARACTER SET ascii
  COLLATE ascii_bin                                                     NOT NULL DEFAULT 'U',
  `firm`                        varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `street1`                     varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `street2`                     varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `state`                       varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `city`                        varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `zip`                         varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `country`                     varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `phone`                       varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `fax`                         varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `lastLostPasswordRequestTime` datetime                                         DEFAULT NULL,
  `lostPasswordKey`             varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `isActive`                    tinyint(1) UNSIGNED                     NOT NULL DEFAULT '1',
  PRIMARY KEY (`userID`),
  UNIQUE KEY `username` (`username`),
  KEY `createdBy` (`createdBy`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_user_ip_address` (
  `userID`      int(11) UNSIGNED NOT NULL,
  `ipAddressID` int(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`userID`, `ipAddressID`),
  KEY `ipAddressID` (`ipAddressID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_user_php_editor_limit` (
  `userPhpEditorlimitID` int(11) UNSIGNED               NOT NULL AUTO_INCREMENT,
  `userID`               int(11) UNSIGNED               NOT NULL,
  `name`                 varchar(255) COLLATE ascii_bin NOT NULL,
  `value`                text COLLATE ascii_bin         NOT NULL,
  PRIMARY KEY (`userPhpEditorlimitID`),
  UNIQUE KEY `userPhpEditorLimit` (`userID`, `name`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_user_php_editor_permission` (
  `userPhpEditorPermissionID` int(11) UNSIGNED               NOT NULL AUTO_INCREMENT,
  `userID`                    int(11) UNSIGNED               NOT NULL,
  `name`                      varchar(255) COLLATE ascii_bin NOT NULL,
  `value`                     text COLLATE ascii_bin         NOT NULL,
  PRIMARY KEY (`userPhpEditorPermissionID`),
  UNIQUE KEY `userPhpEditorPermission` (`userID`, `name`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_web_domain` (
  `webDomainID`         int(11) UNSIGNED                        NOT NULL AUTO_INCREMENT,
  `webDomainPID`        int(11) UNSIGNED                                 DEFAULT NULL,
  `userID`              int(11) UNSIGNED                        NOT NULL,
  `domainName`          varchar(255) CHARACTER SET ascii
  COLLATE ascii_bin                                             NOT NULL,
  `automaticDNS`        tinyint(1) UNSIGNED                     NOT NULL DEFAULT '1',
  `php`                 tinyint(1) UNSIGNED                     NOT NULL DEFAULT '0',
  `cgi`                 tinyint(1) UNSIGNED                     NOT NULL DEFAULT '0',
  `documentRoot`        varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '/htdocs',
  `forwardURL`          varchar(255) COLLATE utf8mb4_unicode_ci          DEFAULT NULL,
  `forwardType`         enum ('301', '302', '303', '307', '308', 'proxy') CHARACTER SET ascii
  COLLATE ascii_bin                                                      DEFAULT NULL,
  `forwardKeepHost`     tinyint(1) UNSIGNED                     NOT NULL DEFAULT '0',
  `webFolderProtection` tinyint(1) UNSIGNED                     NOT NULL DEFAULT '0',
  `isActive`            tinyint(1) UNSIGNED                     NOT NULL DEFAULT '1',
  PRIMARY KEY (`webDomainID`),
  UNIQUE KEY `domainName` (`domainName`),
  KEY `webDomainPID` (`webDomainPID`),
  KEY `userID` (`userID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_web_domain_alias` (
  `webDomainAliasId` int(11) UNSIGNED               NOT NULL AUTO_INCREMENT,
  `userID`           int(11) UNSIGNED               NOT NULL,
  `domainAliasName`  varchar(255) COLLATE ascii_bin NOT NULL,
  `automaticDNS`     tinyint(1) UNSIGNED            NOT NULL DEFAULT '1',
  PRIMARY KEY (`webDomainAliasId`),
  UNIQUE KEY `domainAliasName` (`domainAliasName`),
  KEY `userID` (`userID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_web_domain_ip_address` (
  `webDomainID` int(11) UNSIGNED NOT NULL,
  `ipAddressID` int(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`webDomainID`, `ipAddressID`),
  KEY `ipAddressID` (`ipAddressID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_web_domain_php_directive` (
  `webDomainPhpDirectiveID` int(11)                        NOT NULL AUTO_INCREMENT,
  `webDomainID`             int(11) UNSIGNED               NOT NULL,
  `name`                    varchar(255) COLLATE ascii_bin NOT NULL,
  `value`                   text CHARACTER SET utf8mb4
  COLLATE utf8mb4_bin                                      NOT NULL,
  PRIMARY KEY (`webDomainPhpDirectiveID`),
  UNIQUE KEY `webDomainID` (`webDomainID`),
  KEY `name` (`name`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_web_domain_web_domain_alias` (
  `webDomainID`      int(11) UNSIGNED NOT NULL,
  `webDomainAliasId` int(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`webDomainID`, `webDomainAliasId`),
  KEY `webDomainAliasId` (`webDomainAliasId`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_web_error_page` (
  `webErrorPageID` int(11) UNSIGNED                NOT NULL AUTO_INCREMENT,
  `userID`         int(11) UNSIGNED                NOT NULL,
  `code`           enum ('401', '403', '404', '500', '503') CHARACTER SET ascii
  COLLATE ascii_bin                                NOT NULL,
  `content`        text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`webErrorPageID`),
  KEY `userID` (`userID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_web_htaccess` (
  `webHtaccessID` int(11) UNSIGNED                 NOT NULL AUTO_INCREMENT,
  `userID`        int(11) UNSIGNED                 NOT NULL,
  `serverID`      int(11) UNSIGNED                 NOT NULL,
  `webHtpasswdID` int(11) UNSIGNED                          DEFAULT NULL,
  `webHtgroupID`  int(11) UNSIGNED                          DEFAULT NULL,
  `authName`      varchar(255) CHARACTER SET ascii
  COLLATE ascii_bin                                NOT NULL,
  `authType`      varchar(255) CHARACTER SET ascii
  COLLATE ascii_bin                                NOT NULL,
  `path`          varchar(255) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`webHtaccessID`),
  KEY `userID` (`userID`),
  KEY `serverID` (`serverID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_web_htgroup` (
  `webHtgroupID` int(11) UNSIGNED               NOT NULL AUTO_INCREMENT,
  `userID`       int(11) UNSIGNED               NOT NULL,
  `serverID`     int(11) UNSIGNED               NOT NULL,
  `groupName`    varchar(255) COLLATE ascii_bin NOT NULL,
  `members`      text COLLATE ascii_bin,
  PRIMARY KEY (`webHtgroupID`),
  KEY `userID` (`userID`),
  KEY `serverID` (`serverID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_web_htpasswd` (
  `webHtpasswdID` int(11) UNSIGNED               NOT NULL AUTO_INCREMENT,
  `userID`        int(11) UNSIGNED               NOT NULL,
  `serverID`      int(11) UNSIGNED               NOT NULL,
  `username`      varchar(255) COLLATE ascii_bin NOT NULL,
  `passwordHash`  varchar(255) COLLATE ascii_bin NOT NULL,
  PRIMARY KEY (`webHtpasswdID`),
  KEY `userID` (`userID`),
  KEY `serverID` (`serverID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;

CREATE TABLE IF NOT EXISTS `imscp_web_ssl_certificate` (
  `webSslCertificateID`   int(11) UNSIGNED       NOT NULL AUTO_INCREMENT,
  `webDomainID`           int(11) UNSIGNED       NOT NULL,
  `privateKey`            text COLLATE ascii_bin NOT NULL,
  `certificate`           text COLLATE ascii_bin NOT NULL,
  `caBundle`              text COLLATE ascii_bin,
  `hsts`                  tinyint(1) UNSIGNED    NOT NULL DEFAULT '0',
  `hstsMaxAge`            int(11) UNSIGNED       NOT NULL DEFAULT '31536000',
  `hstsIncludeSubdomains` tinyint(1) UNSIGNED    NOT NULL DEFAULT '0',
  PRIMARY KEY (`webSslCertificateID`),
  UNIQUE KEY `webDomainID` (`webDomainID`)
)
  ENGINE = InnoDB
  DEFAULT CHARSET = ascii
  COLLATE = ascii_bin
  ROW_FORMAT = DYNAMIC;


ALTER TABLE `imscp_client_properties`
  ADD CONSTRAINT `clientPropertiesConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_dns_record`
  ADD CONSTRAINT `dnsRecordConstraint01` FOREIGN KEY (`dnsZoneID`) REFERENCES `imscp_dns_zone` (`dnsZoneID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_dns_zone`
  ADD CONSTRAINT `dnsZoneConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_email_template`
  ADD CONSTRAINT `emailTemplateConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_ftp_group`
  ADD CONSTRAINT `ftpGroupConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_ftp_user`
  ADD CONSTRAINT `ftpUserConstraint02` FOREIGN KEY (`ftpGroupID`) REFERENCES `imscp_ftp_group` (`ftpGroupID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_hosting_plan`
  ADD CONSTRAINT `hostingPlanConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_ip_address`
  ADD CONSTRAINT `ipAddressConstraint01` FOREIGN KEY (`serverID`) REFERENCES `imscp_server` (`serverID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_job`
  ADD CONSTRAINT `jobConstraint01` FOREIGN KEY (`serverID`) REFERENCES `imscp_server` (`serverID`)
  ON DELETE CASCADE,
  ADD CONSTRAINT `jobConstraint02` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_mailbox`
  ADD CONSTRAINT `mailboxConstraint01` FOREIGN KEY (`mailDomainID`) REFERENCES `imscp_mail_domain` (`mailDomainID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_mail_domain`
  ADD CONSTRAINT `mailDomainConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_reseller_properties`
  ADD CONSTRAINT `resellerPropertiesConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_sql_database`
  ADD CONSTRAINT `sqlDatabaseConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_sql_database_sql_user`
  ADD CONSTRAINT `sqlDatabaseSqlUserConstraint01` FOREIGN KEY (`sqlDatabaseID`) REFERENCES `imscp_sql_database` (`sqlDatabaseID`)
  ON DELETE CASCADE,
  ADD CONSTRAINT `sqlDatabaseSqlUserConstraint02` FOREIGN KEY (`sqlUserID`) REFERENCES `imscp_sql_user` (`sqlUserID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_sql_user`
  ADD CONSTRAINT `sqlUserConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_ticket`
  ADD CONSTRAINT `ticketConstraint01` FOREIGN KEY (`fromUserID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE,
  ADD CONSTRAINT `ticketConstraint02` FOREIGN KEY (`toUserID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE,
  ADD CONSTRAINT `ticketConstraint03` FOREIGN KEY (`replyTo`) REFERENCES `imscp_ticket` (`ticketID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_traffic`
  ADD CONSTRAINT `trafficConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_ui_props`
  ADD CONSTRAINT `uiPropsConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_user`
  ADD CONSTRAINT `userConstraint01` FOREIGN KEY (`createdBy`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_user_ip_address`
  ADD CONSTRAINT `userIpAddressConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE,
  ADD CONSTRAINT `userIpAddressConstraint02` FOREIGN KEY (`ipAddressID`) REFERENCES `imscp_ip_address` (`ipAddressID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_user_php_editor_limit`
  ADD CONSTRAINT `userPhpEditorLimitConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`);

ALTER TABLE `imscp_user_php_editor_permission`
  ADD CONSTRAINT `userPhpEditorPermissionConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`);

ALTER TABLE `imscp_web_domain`
  ADD CONSTRAINT `webDomainConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_web_domain_ip_address`
  ADD CONSTRAINT `webDomainIpAddressConstraint01` FOREIGN KEY (`webDomainID`) REFERENCES `imscp_web_domain` (`webDomainID`)
  ON DELETE CASCADE,
  ADD CONSTRAINT `webDomainIpAddressConstraint02` FOREIGN KEY (`ipAddressID`) REFERENCES `imscp_ip_address` (`ipAddressID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_web_domain_php_directive`
  ADD CONSTRAINT `webDomainPhpDirectiveConstraint01` FOREIGN KEY (`webDomainID`) REFERENCES `imscp_web_domain` (`webDomainID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_web_domain_web_domain_alias`
  ADD CONSTRAINT `webDomainWebDomainAliasConstraint01` FOREIGN KEY (`webDomainID`) REFERENCES `imscp_web_domain` (`webDomainID`)
  ON DELETE CASCADE,
  ADD CONSTRAINT `webDomainWebDomainAliasConstraint02` FOREIGN KEY (`webDomainAliasId`) REFERENCES `imscp_web_domain_alias` (`webDomainAliasId`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_web_error_page`
  ADD CONSTRAINT `errorPageConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_web_htaccess`
  ADD CONSTRAINT `webHtaccessConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_web_htgroup`
  ADD CONSTRAINT `webHtgroupConstraint01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_web_htpasswd`
  ADD CONSTRAINT `webHtpasswdConstraint_01` FOREIGN KEY (`userID`) REFERENCES `imscp_user` (`userID`)
  ON DELETE CASCADE;

ALTER TABLE `imscp_web_ssl_certificate`
  ADD CONSTRAINT `sslCertificateConstraint01` FOREIGN KEY (`webDomainID`) REFERENCES `imscp_web_domain` (`webDomainID`)
  ON DELETE CASCADE;

SET FOREIGN_KEY_CHECKS = 1;
