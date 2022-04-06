# Docker Environment Builder

Scripts to Build Test Environment(s) for the Application using docker.

You can also use this as an example of how to build an environment for other systems.

## Development OS

The script was developed on Ubuntu 20.04 LTS.
In theory it should be executable on other Linux distributions.

## Usage

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

4. (On 1st Use) Load Initial Data into Shard 0

