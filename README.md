# Docker Environment Builder

The ObjectVault Builder project is a series os BASH scripts whose functions is to create a set of environments to be used to test the application.

It also serves as a reference of how to configure the set of required servers/containers required to run the application.

## Components

The Builder Projects is comprised of a set of script, with 3 basic funcions:

1. Helper scripts
   - A set of common utility functions (Ex: docker.sh, git.sh, etc)
2. Module scripts
   - A module wraps as set of actions that can be performed on a container, or
   - the 'all' module, which performs common action on a set of container
3. The execution script ```run.sh```
   - Main script that wraps access to all the modules

## Execution Modes

There are 3 run modes for the script:

1. DEBUG
   - Simplest Application Run Mode (Application Session Managed by Cookies)
2. SINGLE
   - A closer to production environment mode 
     - Session is managed through a REDIS Server
3. CLUSTER
   - An example of how to setup the application with cluster load balancing for the the various servers
     - Session is managed through REDIS Server
     - Database is run in SHARD Mode (2 Balanced DB Servers)
     - API Server is run Load Balancing Mode (2 API Servers)
   - Reverse Proxy Container is used to serve as both frontend (to both the UI and API Servers) and Load Balancing for the API Servers

> :warning: Currently, **I have only tested/ran the DEBUG Mode**. I have not created container configurations for REDIS Session Server or the Frontend Load Balancer, ***nor***, have I created configurations for the application containers, for these other modes.

## Development OS

The script was developed on Ubuntu Linux.
In theory it should be executable on other Linux distributions.

## Examples Execution

### Main Execution Script Help

To display main execution scripts help you can do the following:

```shell
./run.sh 
```

or

```shell
./run.sh help
```

This will list the modules available (containers) as well as commannd format.

### Module Script Help

To display the help for the ***all*** module

```shell
./run.sh all help
```

### Start a ***single*** container

To start database container (in DEBUG mode)

```shell
./run.sh db start
```

To start database container (in CLUSTER mode)

```shell
./run.sh db start cluster
```

### Start ***all*** containers

Start all containers required for a DEBUG environment

```shell
./run.sh all start
```

Start ***all*** containers required for a CLUSTER environment

```shell
./run.sh all start cluster
```

# Running the Application

> :warning: Please use a release of this project, and not a **git clone** as the latest code for the scripts might not work.

## Setup Builder Environment

After downloading the release, decompress the file into an empty directory.

Decompressing the file, should produce a basic directory layout:

```shell
>$ ls -l
total 124
drwxrwxr-x  3 **   **    4096 abr  2  2022 init
drwxrwxr-x  3 **   **    4096 out  6 13:50 lib
-rw-rw-r--  1 **   **   34354 mar 18  2022 LICENSE.md
-rw-rw-r--  1 **   **    6245 out  7 12:18 README.md
-rwxr-xr-x  1 **   **    1713 out  6 14:16 run.sh
drwxrwxr-x  7 **   **    4096 out  6 11:38 sources.example

```

The important directories/files are:

- ***init***, contains database schemas and initial data to be loaded
- ***sources.example***, contains example sample configuration files that can be used as models for real container settings.

Other directories that will be created, during the execution of the script:

```shell
drwxrwxr-x  5 **   **    4096 out  6 13:31 builds
drwxrwxr-x 10 **   **    4096 out  6 11:46 containers
drwxrwxr-x  3 **   **    4096 out  6 16:38 dumps
```

By function:

- ***builds*** is the directory used to build the application docker container images
- ***containers*** is the directory that contains the **run** configuration files for the containers
- ***dumps*** is the directory used by the **export** action to save data or container configuration dumps

### Initialize Execution Environment

1. Duplicate the directory ***sources.example*** to ***source***
2. Modify Existing configuration files, to fill in missing information/passwords, etc.

## Execution STEP-BY-STEP

> The step-by-step is only to be used in a **first run scenario**. After that, you will probably only need to ***start*** or ***stop*** the application containers.

To run the application, in **DEBUG** mode you basically have to just do the following

1. Build Docker IMAGES for containers

```shell
./run.sh all build
```

2. Initialize the Containers work areas

```shell
./run.sh all init
```

3. Start the Application

```shell
./run.sh all start
```

4. Use a web browser to [Open Application UI](http://127.0.0.1:5000)

5. Stop the Application

```shell
./run.sh all stop
```

6. Backup up data/configuration in case of problems

```shell
./run.sh all export
```

## Notes for 1st Application Use

### The application has several main ***objects***

1. User (represents an actor with access to the system)
2. Organization (represents a Security Zone and Container for Object Stores)
3. Store (represents a Security Zone and Secure Container for Objects)
4. Store Object (represents Encrypted Object)

By default, the system is initialized with:

1. System Organization: system
   - System Administration Organization **ONLY** (***can not*** have Object Stores associated)
   - All users that can create Organization's have to be associated with ***system*** organization
2. System Admin: admin, password: adminADMIN
   - Has ***ALL*** Roles and Permissions over the ***system*** organization
   - As a basic rule, a user ***can not*** modify **is own roles** and permissions

### The application works by invitation ***only***

In order for a user to have any sort of access to the system, a user, with permissions to ***invite*** has to create a new invitation for the user.

Basic workflow would be something like:

1. User with permissions to invite (into the organization to which the user is being granted access), creates a new invitation
   - In a fully functioning application, this would generate an email message with the invitation link.
   - ***NOW*** it creates an invitation database object that has to be ***consulted*** and ***manually*** accepted (description below)
2. The user clicks on the link, and is taken to invitation accept / decline
   - ***Decline*** just simply marks the invitation as declined and consumed
3. On acceptance, if the user is:
    1. ***NEW*** He is requested to create a new user in the system to accept the invitation
    2. ***Existing*** He is requested to login, to accept the invitation

***Currently*** the action server sends an email messages, with the **link** to accept the invitation. If you don't have the configuration correctly setup, the email is lost and ***in order to accept invitations*** you have to ***manually*** access the invitation acceptance page:

> LINK - http://localhost:5000/#/invitation/{Unique Invitation ID}

To get the invitation ID, you have to query the database ***directly*** to retrieve the UID . Something like:

```sql
SELECT a.invitee_email, a.id_object, b.{orgname | storename}, a.uid 
  FROM vault.invites as a
  INNER JOIN vault.{registry_orgs | registry_org_stores} as b ON a.id_object = b.{id_org | id_store}
```

Use:

- registry_orgs / orgname - for invitations to organization, or
- registry_org_stores / storename - for invitations to store
