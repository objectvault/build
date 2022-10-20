-- IMPORTANT MySQL SERVER SETTINGS SHOULD BE SET so that ALL TIMESTAMPS
-- are RETRIEVED as UTC:
-- [mysqld]
-- default_time_zone='+00:00'

-- CREATE DATABASE
-- CREATE DATABASE
--  IF NOT EXISTS vault
--  CHARACTER SET utf8
--  COLLATE utf8_general_ci;
-- SET DEFAULT
-- USE vault;

-- ORGANIZATION PROFILE
CREATE TABLE IF NOT EXISTS `orgs` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'LOCAL ID',
    `orgname` VARCHAR(40) NOT NULL COMMENT 'ORGANIZATION Alias (DNS COMPLIANT)',
    `name` NVARCHAR(80) NULL COMMENT 'Organization Name (UNICODE)',
    `creator` BIGINT UNSIGNED NOT NULL COMMENT 'GLOBAL USER ID of Creation User',
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation TimeStamp',
    `modifier` BIGINT UNSIGNED NULL COMMENT 'GLOBAL USER ID of Last Modifier User',
    `modified` TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last Modification TimeStamp',
    `object` TEXT NULL COMMENT 'Organization JSON Profile Object',
    PRIMARY KEY (`id`),
    UNIQUE INDEX `UI_orgname` (`orgname` ASC) VISIBLE
);

-- USER PROFILE
CREATE TABLE IF NOT EXISTS `users` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'LOCAL ID',
    `name` NVARCHAR(80) NOT NULL COMMENT 'Full Name (UNICODE)',
    `username` VARCHAR(40) NOT NULL COMMENT 'USER Alias',
    `email` VARCHAR(320) NOT NULL COMMENT 'USER Email',
    `object` TEXT NULL COMMENT 'User JSON Profile Object',
    `ciphertext` VARBINARY(255) NOT NULL COMMENT 'Ciphertext to Validate User Credentials',
    `dt_expires` DATETIME NULL COMMENT 'Account Expire Date in UTC or NULL',
    `dt_lastpwdchg` TIMESTAMP NULL COMMENT 'Date/Time UTC of Last Password Change',
    `maxpwddays`SMALLINT UNSIGNED NULL COMMENT 'Maximum Days Before Password Change',
    `creator` BIGINT UNSIGNED NOT NULL COMMENT 'GLOBAL USER ID of Creation User',
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation TimeStamp',
    `modifier` BIGINT UNSIGNED NULL COMMENT 'GLOBAL USER ID of Last Modifier User',
    `modified` TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last Modification TimeStamp',
    PRIMARY KEY (`id`),
    UNIQUE INDEX `UI_username` (`username` ASC) VISIBLE,
    UNIQUE INDEX `UI_email` (`email` ASC) VISIBLE
);

-- GLOBAL USERS REGISTRY (HOUSED ON SINGLE SERVER for QUICK ACCESS)
CREATE TABLE IF NOT EXISTS `registry_users` (
    `id_user` BIGINT UNSIGNED NOT NULL COMMENT 'USER SHARD Distributed ID',
    `name` NVARCHAR(80) NOT NULL COMMENT 'Full Name (UNICODE)',
    `username` VARCHAR(40) NOT NULL COMMENT 'USER Alias',
    `email` VARCHAR(320) NOT NULL COMMENT 'USER Email',
    `state` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'GLOBAL USER State',
    `ciphertext` VARBINARY(255) NOT NULL COMMENT 'Ciphertext to Validate User Credentials',
    PRIMARY KEY (`id_user`),
    UNIQUE INDEX `UI_username` (`username` ASC) VISIBLE,
    UNIQUE INDEX `UI_email` (`email` ASC) VISIBLE
);

-- GLOBAL ORGS REGISTRY (HOUSED ON SINGLE SERVER for QUICK ACCESS)
CREATE TABLE IF NOT EXISTS `registry_orgs` (
    `id_org` BIGINT UNSIGNED NOT NULL COMMENT 'ORG SHARD Distributed ID',
    `orgname` VARCHAR(40) NOT NULL COMMENT 'ORGANIZATION Alias (DNS COMPLIANT)',
    `name` NVARCHAR(80) NULL COMMENT 'Organization Name (UNICODE)',
    `state` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'ORGANIZATION State',
    PRIMARY KEY (`id_org`),
    UNIQUE INDEX `UI_orgname` (`orgname` ASC) VISIBLE
);

-- STORE OBJECT
CREATE TABLE IF NOT EXISTS `stores` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'LOCAL ID',
    `id_org` BIGINT UNSIGNED NOT NULL COMMENT 'ORG SHARD ID',
    `storename` VARCHAR(40) NOT NULL COMMENT 'STORE Alias',
    `name` NVARCHAR(80) NULL COMMENT 'STORE Long Name (UNICODE)',
    `object` BLOB NULL COMMENT 'OPTIONAL ENCRYPTED JSON Object',
    `creator` BIGINT UNSIGNED NOT NULL COMMENT 'GLOBAL USER ID of Creation User',
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation TimeStamp',
    `modifier` BIGINT UNSIGNED NULL COMMENT 'GLOBAL USER ID of Last Modifier User',
    `modified` TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last Modification TimeStamp',
    PRIMARY KEY (`id`),
    UNIQUE INDEX `UI_idorg_storename` (`id_org` ASC, `storename` ASC) VISIBLE
);

-- REGISTRY : ORG -> STORES live on SAME Shard as the Parent Organization
CREATE TABLE IF NOT EXISTS `registry_org_stores` (
    `id_org` BIGINT UNSIGNED NOT NULL COMMENT 'ORG SHARD ID',
    `id_store` BIGINT UNSIGNED NOT NULL COMMENT 'STORE SHARD ID',
    `storename` VARCHAR(40) NOT NULL COMMENT 'STORE Alias',
    `state` SMALLINT UNSIGNED NULL DEFAULT 0 COMMENT 'Store State',
    PRIMARY KEY (`id_org`, `id_store`),
    UNIQUE INDEX `UI_idorg_storename` (`id_org` ASC, `storename` ASC) VISIBLE
);

-- REGISTRY : OBJECT -> USERS live on SAME Shard as the Parent Container
CREATE TABLE IF NOT EXISTS `registry_object_users` (
    `id_object` BIGINT UNSIGNED NOT NULL COMMENT 'OBJECT SHARD ID',
    `id_user` BIGINT UNSIGNED NOT NULL COMMENT 'USER SHARD ID',
    `username` VARCHAR(40) NOT NULL COMMENT 'USER Alias',
    `state` SMALLINT UNSIGNED NULL DEFAULT 0 COMMENT 'USER State in Container',
    `roles` VARCHAR(1023) NULL DEFAULT NULL COMMENT 'CSV List of User Roles in Container',
    `ciphertext` VARBINARY(255) NULL COMMENT 'Encrypted Store Object Decrypt Key',
    PRIMARY KEY (`id_object`, `id_user`),
    UNIQUE INDEX `UI_object_username` (`id_object` ASC, `username` ASC) VISIBLE
);

-- REGISTRY : USERS -> OBJECTS (HOUSED ON SAME SHARD AS USER PROFILE)
CREATE TABLE IF NOT EXISTS `registry_user_objects` (
    `id_user` BIGINT UNSIGNED NOT NULL COMMENT 'USER SHARD Distributed ID',
    `type` SMALLINT UNSIGNED NOT NULL COMMENT 'OBJECT Type',
    `id_object` BIGINT UNSIGNED NOT NULL COMMENT 'OBJECT SHARD Distributed ID',
    `alias` VARCHAR(40) NOT NULL COMMENT 'Container Alias',
    `favorite` TINYINT UNSIGNED NULL DEFAULT 0 COMMENT 'Marked as Favorite Object',
    PRIMARY KEY (`id_user`, `type`, `id_object`),
    INDEX `I_user_alias` (`id_user` ASC, `type` ASC, `alias` ASC) VISIBLE
);

-- STORE OBJECTS --
-- STORE Objects live on SAME SHARD as Parent STORE
CREATE TABLE IF NOT EXISTS `objects` (
    `id_store` INT UNSIGNED NOT NULL COMMENT 'LOCAL STORE ID',
    `id_parent` INT UNSIGNED DEFAULT 0 COMMENT 'Parent Entry ID',
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'UNIQUE ENTRY ID',
    `title` NVARCHAR(40) NOT NULL COMMENT 'Short Description (UNICODE)',
    `type` SMALLINT UNSIGNED NOT NULL COMMENT 'Entry Type',
    `object` BLOB DEFAULT NULL COMMENT 'OPTIONAL ENCRYPTED JSON Object',
    `creator` BIGINT UNSIGNED NOT NULL COMMENT 'GLOBAL USER ID of Creation Entry',
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation TimeStamp',
    `modifier` BIGINT UNSIGNED NULL COMMENT 'GLOBAL USER ID of Last Modifier Entry',
    `modified` TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last Modification TimeStamp',
    PRIMARY KEY (`id`),
    UNIQUE INDEX `UI_store_entries` (`id_store` ASC, `id_parent` ASC, `id` ASC) VISIBLE,
    UNIQUE INDEX `UI_store_title` (`id_store` ASC, `title` ASC) VISIBLE
);

-- INVITATIONS OBJECT
CREATE TABLE IF NOT EXISTS `registry_invites` (
    `id_invite` BIGINT UNSIGNED NOT NULL COMMENT 'SHARD ID of Invitation',
    `uid` CHAR(40) NOT NULL COMMENT 'UNIQUE String ID for INVITE',
    `id_creator` BIGINT UNSIGNED NOT NULL COMMENT 'SHARD ID Creator of ',
    `id_object` BIGINT UNSIGNED NOT NULL COMMENT 'SHARD ID: INVITE Into Object',
    `invitee_email` VARCHAR(320) NOT NULL COMMENT 'INVITEE Email',
    `expiration` TIMESTAMP NOT NULL COMMENT 'Invitation Experiration Date',
    `state` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Invitation State - 0 Active, 1 - Accepted, 2 - Declined',
    PRIMARY KEY (`id_invite`),
    UNIQUE INDEX `UI_uid` (`uid` ASC) VISIBLE
);

-- INVITATIONS OBJECT
CREATE TABLE IF NOT EXISTS `invites` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'LOCAL ID of Invitation',
    `uid` CHAR(40) NOT NULL COMMENT 'UNIQUE String ID for INVITE',
    `id_creator` BIGINT UNSIGNED NOT NULL COMMENT 'SHARD ID Creator of ',
    `invitee_email` VARCHAR(320) NOT NULL COMMENT 'INVITEE Email',
    `id_object` BIGINT UNSIGNED NOT NULL COMMENT 'SHARD ID: INVITE Into Object',
    `roles` VARCHAR(1023) NULL DEFAULT NULL COMMENT 'CSV List of User Roles in Object',
    `message` TEXT NULL DEFAULT NULL COMMENT 'OPTIONAL Multi line Message',
    `id_key` BIGINT UNSIGNED NULL COMMENT 'SHARD ID: Key Object',
    `key_pick` VARBINARY(255) NULL COMMENT 'Key Pick',
    `expiration` TIMESTAMP NOT NULL COMMENT 'Invitation Experiration Date',
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation TimeStamp',
    PRIMARY KEY (`id`),
    UNIQUE INDEX `UI_uid` (`uid` ASC) VISIBLE
);

-- TEMPORARY KEYS OBJECT
-- CIPHER TEXT contain ENCRYPTED KEY
-- KEY used to decrypt cyphertext is stored else where
-- IDEA: This Table will be regularly cleaned, where as the table containg the decryption key won't
CREATE TABLE IF NOT EXISTS `ciphers` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'LOCAL ID of Key',
    `ciphertext` VARBINARY(1024) NOT NULL COMMENT 'Encrypted Bytes',
    `expiration` TIMESTAMP NOT NULL COMMENT 'Key Experiration Date',
    `id_creator` BIGINT UNSIGNED NOT NULL COMMENT 'SHARD ID of Creator',
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation TimeStamp',
    PRIMARY KEY (`id`)
);

-- REQUESTS
-- REQUEST OBJECT
CREATE TABLE IF NOT EXISTS `requests` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'UNIQUE ENTRY ID',
    `guid` CHAR(36) NOT NULL COMMENT 'GUID for Request',
    `type` VARCHAR(128) NOT NULL COMMENT 'Request Type',
    `ref_object` BIGINT UNSIGNED NULL COMMENT 'OPTIONAL: If Request is Relative to an Object',
    `params` TEXT COMMENT 'OPTIONAL (JSON Object): Request Parameters',
    `props` TEXT COMMENT 'OPTIONAL (JSON Object): Request Properties',
    `expiration` TIMESTAMP NULL COMMENT 'Request Experiration Date',
    `creator` BIGINT UNSIGNED NULL COMMENT 'GLOBAL USER ID of Creator',
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation TimeStamp',
    `modifier` BIGINT UNSIGNED NULL COMMENT 'GLOBAL USER ID of Last Modifier User',
    `modified` TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last Modification TimeStamp',
    PRIMARY KEY (`id`),
    UNIQUE INDEX `UIRQ_ti` (`type` ASC, `id` ASC) VISIBLE
);

-- REQUEST REGISTRY
CREATE TABLE IF NOT EXISTS `registry_requests` (
    `id_request` BIGINT UNSIGNED NOT NULL COMMENT 'SHARD ID of Invitation',
    `guid` CHAR(36) NOT NULL COMMENT 'GUID for Request',
    `type` VARCHAR(128) NOT NULL COMMENT 'Request Type',
    `ref_object` BIGINT UNSIGNED NULL COMMENT 'OPTIONAL: If Request is Relative to an Object',
    `expiration` TIMESTAMP NULL COMMENT 'Request Experiration Date',
    `state` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Request Processing State',
    `creator` BIGINT UNSIGNED NULL COMMENT 'GLOBAL USER ID of Creator',
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation TimeStamp',
    PRIMARY KEY (`id_request`),
    UNIQUE INDEX `UIRQ_guid` (`guid` ASC) VISIBLE,
    INDEX `IRQ_ots` (`ref_object` ASC, `type` ASC, `state` ASC) VISIBLE,
    INDEX `IRQ_ts` (`type` ASC, `state` ASC) VISIBLE,
    INDEX `IRQ_sti` (`state` ASC, `type` ASC, `id_request` ASC) VISIBLE
);

-- ACTION QUEUE
-- ASYNCHRONOUS ACTIONs (like Invitation Requests, Email Confirmation, etc.)
CREATE TABLE IF NOT EXISTS `actions` (
    `guid` CHAR(36) NOT NULL COMMENT 'GUID for Action',
    `parent` CHAR(36) NULL COMMENT 'Parent GUID for Action',
    `type` VARCHAR(128) NOT NULL COMMENT 'Action Type',
    `request` BIGINT UNSIGNED NULL COMMENT 'GLOBAL REQUEST ID',
    `params` TEXT COMMENT 'OPTIONAL (JSON Object): Action Parameters',
    `props` TEXT COMMENT 'OPTIONAL (JSON Object): Action Properties',
    `state` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Action Processing State',
    `creator` BIGINT UNSIGNED NULL COMMENT 'GLOBAL USER ID of Creator',
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation TimeStamp',
    PRIMARY KEY (`guid`),
    INDEX `IACT_tg` (`type` ASC, `guid` ASC) VISIBLE
);

-- TEMPLATE OBJECTS
CREATE TABLE IF NOT EXISTS `templates` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'LOCAL ID of Template',
    `name` VARCHAR(40) NOT NULL COMMENT 'TEMPLATE Name',
    `version` SMALLINT UNSIGNED NOT NULL COMMENT 'TEMPLATE Version',
    `title` NVARCHAR(40) NOT NULL COMMENT 'Short Description (UNICODE)',
    `description` TEXT(80) NULL COMMENT 'TEMPLATE Short Description (UNICODE)',
    `model` TEXT NOT NULL COMMENT 'TEMPLATE JSON Model (UNICODE)',
    `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation TimeStamp',
    PRIMARY KEY (`id`),
    UNIQUE INDEX `UI_nv` (`name` ASC, `version` ASC) VISIBLE
);

-- REGISTRY : OBJECT -> TEMPLATES live on SAME Shard as id_object
CREATE TABLE IF NOT EXISTS `registry_object_templates` (
    `id_object` BIGINT UNSIGNED NOT NULL COMMENT 'OBJECT SHARD ID',
    `template` VARCHAR(40) NOT NULL COMMENT 'TEMPLATE Name',
    `title` NVARCHAR(40) NOT NULL COMMENT 'Short Description (UNICODE)',
    PRIMARY KEY (`id_object`, `template`)
);
