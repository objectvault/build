# Docker Environment Builder

Scripts to Build Test Environment(s) for the Application using docker.

You can also use this as an example of how to build an environment for other systems.

## Development OS

The script was developed on Ubuntu 20.04 LTS.
In theory it should be executable on other Linux distributions.

## Run ObjectVault Application

To run the application, in more or less, debug mode you have to

1. Build Docker IMAGES

```shell
./run build all 
```

2. Run the Application

```shell
./run start all 
```

3. (On 1st Use) Create Database on DB Server(s)
  * Use schema.sql
    * This creates the database and all required tables

4. (On 1st Use) Load Initial Data into Shard 0. 
  * Use startup-data.sql
  * This adds:
    1. System Administrator (admin, password: adminADMIN)
    2. System Organization (system)
    3. Basic Template for Objects

Currently, initializing the database servers, ***has to be done by hand*** (i.e. you have to connect to the DB servers, one by one, and execute the SQL scripts).

The SQL files are in the directory init/mariadb

## Notes for 1st Application Use

### The application has several main ***objects***

1. User (represents an actor with access to the system)
2. Organization (represents a Security Zone and Container for Object Stores)
3. Store (represents a Security Zone and Secure Container for Objects)
4. Store Object (represents Encrypted Object)

By default, the system is initialized with:

1. System Organization: system
    * System Administration Organization *ONLY** (***can not*** have Object Stores associated)
    * All users that can create Organization's have to be associated with ***system*** organization
2. System Admin: admin, password: adminADMIN
    * Has ***ALL*** Roles and Permissions over the ***system*** organization
    * As a basic rule, a user ***can not*** modify **is own roles** and permissions

### The application works by invitation ***only***

In order for a user to have any sort of access to the system, a user, with permissions to ***invite*** has to create a new invitation for the user.

Basic workflow would be something like:

1. User with permissions to invite (into the organization to which the user is being granted access), creates a new invitation
    * In a fully functioning application, this would generate an email message with the invitation link.
    * ***NOW*** it creates an invitation database object that has to be ***consulted*** and ***manually*** accepted (description below)
2. The user clicks on the link, and is taken to invitation accept / decline
    * ***Decline*** just simply marks the invitation as declined and consumed
3. On acceptance, if the user is:
    1. ***NEW*** He is requested to create a new user in the system to accept the invitation
    2. ***Existing*** He is requested to login, to accept the invitation

***Currently*** the action server required to send email messages, is currently in development, so ***in order to accept invitations*** you have to ***manually*** access the invitation acceptance page:

* LINK - http://localhost:5000/#/invitation/{Unique Invitation ID}

To get the invitation ID, you have to query the database ***directly*** to retrieve the UID . Something like:

```sql
SELECT a.invitee_email, a.id_object, b.{orgname | storename}, a.uid 
  FROM vault.invites as a
  INNER JOIN vault.{registry_orgs | registry_org_stores} as b ON a.id_object = b.{id_org | id_store}
```

Use:

* registry_orgs / orgname - for invitations to organization, or
* registry_org_stores / storename - for invitations to store
