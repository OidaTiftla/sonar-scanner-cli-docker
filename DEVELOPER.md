# How to build the Docker image

Each major scanner version gets its image in a specific directory.

E.g., to build sonar-scanner 5.x under the image name `scanner-cli` (get the latest version of the cli `5.0.1.3006` from [SonarScanner](https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/)):

```bash
docker build --pull --platform linux/amd64 --build-arg SONAR_SCANNER_VERSION=5.0.1.3006 --build-arg DOTNET_SONAR_SCANNER_VERSION=6.2.0 --build-arg DOTNET_VERSION=8.0 --tag oidatiftla/sonarscanner:net8.0 -f 5/Dockerfile 5 \
    && docker push oidatiftla/sonarscanner:net8.0
docker build --pull --platform linux/amd64 --build-arg SONAR_SCANNER_VERSION=5.0.1.3006 --build-arg DOTNET_SONAR_SCANNER_VERSION=6.2.0 --build-arg DOTNET_VERSION=7.0 --tag oidatiftla/sonarscanner:net7.0 -f 5/Dockerfile 5 \
    && docker push oidatiftla/sonarscanner:net7.0
docker build --pull --platform linux/amd64 --build-arg SONAR_SCANNER_VERSION=5.0.1.3006 --build-arg DOTNET_SONAR_SCANNER_VERSION=6.2.0 --build-arg DOTNET_VERSION=6.0 --tag oidatiftla/sonarscanner:net6.0 -f 5/Dockerfile 5 \
    && docker push oidatiftla/sonarscanner:net6.0
docker build --pull --platform linux/amd64 --build-arg SONAR_SCANNER_VERSION=5.0.1.3006 --build-arg DOTNET_SONAR_SCANNER_VERSION=6.2.0 --build-arg DOTNET_VERSION=5.0 --tag oidatiftla/sonarscanner:net5.0 -f 5/Dockerfile 5 \
    && docker push oidatiftla/sonarscanner:net5.0
docker build --pull --platform linux/amd64 --build-arg SONAR_SCANNER_VERSION=5.0.1.3006 --build-arg DOTNET_SONAR_SCANNER_VERSION=6.2.0 --build-arg DOTNET_VERSION=3.1 --tag oidatiftla/sonarscanner:net3.1 -f 5/Dockerfile 5 \
    && docker push oidatiftla/sonarscanner:net3.1
docker tag oidatiftla/sonarscanner:net7.0 oidatiftla/sonarscanner \
    && docker push oidatiftla/sonarscanner
```

## How to run the Docker image

### On Linux with a local SonarQube

With a SonarQube (SQ) running on default configuration (`http://localhost:9000`), the following will analyze the project in the directory `/path/to/project`:

```bash
docker run --user="$(id -u):$(id -g)" -it -v "/path/to/project:/usr/src" sonarsource/sonar-scanner-cli
```

To analyze the project in the current directory:

```bash
docker run --user="$(id -u):$(id -g)" -it -v "$PWD:/usr/src" sonarsource/sonar-scanner-cli
```

If SQ is running on another port, you can specify it by adding the following to the `docker run` command:

```bash
-e SONAR_HOST_URL=http://localhost:9010
```

### On Linux with SonarQube running in Docker

Create a network and boot SonarQube:

```bash
docker network create "scanner-sq-network"
docker run --network="scanner-sq-network" --name="sq" -d sonarqube
```

And run the scanner:

```bash
# make sure SQ is up and running
docker run -e SONAR_HOST_URL=http://sq:9000 --network="scanner-sq-network" --user="$(id -u):$(id -g)" -it -v "/path/to/project:/usr/src" sonarsource/sonar-scanner-cli
```

### On Mac with local SonarQube

On Mac, `host.docker.internal` should be used instead of `localhost`.

To analyze the project located in `/path/to/project`, execute:

```bash
docker run -e SONAR_HOST_URL=http://host.docker.internal:9000 -it -v "/path/to/project:/usr/src" sonarsource/sonar-scanner-cli
```

To analyze the project in the current directory, execute:

```bash
docker run -e SONAR_HOST_URL=http://host.docker.internal:9000 -it -v "$(pwd):/usr/src" sonarsource/sonar-scanner-cli
```

### On Mac with SonarQube running in Docker

Create a network and boot SonarQube:

```bash
docker network create "scanner-sq-network"
docker run --network="scanner-sq-network" --name="sq" -d sonarqube
```

And run the scanner:

```bash
# make sure SQ is up and running
docker run -e SONAR_HOST_URL=http://sq:9000 --network="scanner-sq-network" -it -v "/path/to/project:/usr/src" sonarsource/sonar-scanner-cli
```

## How to publish the Docker image

### Docker-hub official image release

Sonar-scanner-cli is now part of the docker hub official images; you can find more details on the release doc [here](./RELEASE.md)

### [DEPRECATED] Release on SonarSource docker hub account

This image was built every day on master through the rebuild.yml and pushed to the docker hub SonarSource account [here](https://hub.docker.com/u/sonarsource); this workflow was used to rebuild the image in case a new base image patch was released.

The same workflow was also triggered when a GitHub release was created. 

We are removing entirely the rebuild workflow, replacing it with sonar-scanner-cli-docker, which is available as a [docker hub official image](https://docs.docker.com/docker-hub/official_images/). You can find more details on the doc [here](./RELEASE.md)

In the meantime, to allow everyone to use that new repo, we are keeping the release.yml workflow.

## Automatic tests

The QA process is handled on `.cirrus.yml`, which is responsible for the following:

- linting the Dockerfile to make sure it complies with best practices
- build the image
- test the image by running a scan on a sample project
- run scans to find potential vulnerabilities
