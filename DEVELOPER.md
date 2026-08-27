# How to build the Docker image

Get the latest version of the cli from [SonarScanner](https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/).

```bash
docker build --pull --platform linux/amd64 --build-arg SONAR_SCANNER_VERSION=5.0.1.3006 --build-arg DOTNET_SONAR_SCANNER_VERSION=6.2.0 --build-arg DOTNET_VERSION=8.0 --tag oidatiftla/sonarscanner:net8.0. \
    && docker push oidatiftla/sonarscanner:net8.0
docker build --pull --platform linux/amd64 --build-arg SONAR_SCANNER_VERSION=5.0.1.3006 --build-arg DOTNET_SONAR_SCANNER_VERSION=6.2.0 --build-arg DOTNET_VERSION=7.0 --tag oidatiftla/sonarscanner:net7.0. \
    && docker push oidatiftla/sonarscanner:net7.0
docker build --pull --platform linux/amd64 --build-arg SONAR_SCANNER_VERSION=5.0.1.3006 --build-arg DOTNET_SONAR_SCANNER_VERSION=6.2.0 --build-arg DOTNET_VERSION=6.0 --tag oidatiftla/sonarscanner:net6.0. \
    && docker push oidatiftla/sonarscanner:net6.0
docker tag oidatiftla/sonarscanner:net8.0 oidatiftla/sonarscanner \
    && docker push oidatiftla/sonarscanner
```

## How to run the Docker image

### On Linux with a local SonarQube

With a SonarQube (SQ) running on default configuration (`http://localhost:9000`), the following will analyze the project in the directory `/path/to/project`:

```bash
docker run -it -v "/path/to/project:/usr/src" --network="host" -e SONAR_HOST_URL=http://localhost:9000 scanner-cli-local
```

To analyze the project in the current directory:

```bash
docker run -it -v "$PWD:/usr/src" --network="host"  -e SONAR_HOST_URL=http://localhost:9000 scanner-cli-local
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
docker run -e SONAR_HOST_URL=http://sq:9000 --network="scanner-sq-network" -it -v "/path/to/project:/usr/src" scanner-cli-local
```

### On Mac with local SonarQube

On Mac, `host.docker.internal` should be used instead of `localhost`.

To analyze the project located in `/path/to/project`, execute:

```bash
docker run -e SONAR_HOST_URL=http://host.docker.internal:9000 -it -v "/path/to/project:/usr/src" scanner-cli-local
```

To analyze the project in the current directory, execute:

```bash
docker run -e SONAR_HOST_URL=http://host.docker.internal:9000 -it -v "$(pwd):/usr/src" scanner-cli-local
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
docker run -e SONAR_HOST_URL=http://sq:9000 --network="scanner-sq-network" -it -v "/path/to/project:/usr/src" scanner-cli-local
```
## CI image publishing

The `Publish SonarScanner Images` workflow runs every Monday at 06:00 UTC and can be started manually. It checks current scanner versions, builds each supported .NET SDK image, and publishes the tags to Docker Hub.

### Configure a fork

1. Create a Docker Hub personal access token with Read and Write permissions. Do not use your Docker Hub password.
2. In the fork, open **Settings > Secrets and variables > Actions**.
3. Add the `DOCKERHUB_USERNAME` repository secret with the Docker Hub username.
4. Add the `DOCKERHUB_TOKEN` repository secret with the access token.
5. Add the `DOCKER_IMAGE` repository variable with the Docker Hub image name, for example `your-dockerhub-user/sonarscanner`.
6. Run the `Publish SonarScanner Images` workflow from the Actions tab.

GitHub Secrets keep the Docker Hub token out of the repository and workflow logs. See the [GitHub Actions secrets documentation](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions) and [Docker Hub access token documentation](https://docs.docker.com/security/for-developers/access-tokens/).
