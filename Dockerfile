ARG DOTNET_VERSION

FROM alpine:3.24 AS builder

LABEL org.opencontainers.image.url=https://github.com/SonarSource/sonar-scanner-cli-docker

ARG SONAR_SCANNER_HOME=/opt/sonar-scanner
ARG SONAR_SCANNER_VERSION=8.0.1.6346
ENV HOME=/tmp \
    XDG_CONFIG_HOME=/tmp \
    SONAR_SCANNER_HOME=${SONAR_SCANNER_HOME} \
    SCANNER_BINARIES=https://binaries.sonarsource.com/Distribution/sonar-scanner-cli
ENV SCANNER_ZIP_URL="${SCANNER_BINARIES}/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip"

WORKDIR /opt

ADD ${SCANNER_ZIP_URL} /opt/sonar-scanner-cli.zip
ADD ${SCANNER_ZIP_URL}.asc /opt/sonar-scanner-cli.zip.asc

RUN set -eux; \
    apk add --no-cache --virtual build-dependencies gnupg unzip wget; \
    gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys 679F1EE92B19609DE816FDE81DB198F93525EC1A; \
    gpg --verify /opt/sonar-scanner-cli.zip.asc /opt/sonar-scanner-cli.zip; \
    unzip sonar-scanner-cli.zip; \
    rm sonar-scanner-cli.zip sonar-scanner-cli.zip.asc; \
    mv "sonar-scanner-${SONAR_SCANNER_VERSION}" "${SONAR_SCANNER_HOME}"; \
    apk del --purge build-dependencies;


FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS scanner-cli-base

ENV PATH=${PATH}:/.dotnet/tools
ARG DOTNET_SONAR_SCANNER_VERSION=7.1.1
RUN mkdir -p /.dotnet/tools \
    && dotnet tool install --tool-path /.dotnet/tools dotnet-sonarscanner --version ${DOTNET_SONAR_SCANNER_VERSION} \
    && chmod -R a+r /.dotnet/tools \
    && find /.dotnet/tools/ -type f -executable -exec chmod a+x {} \;

ARG SONAR_SCANNER_HOME=/opt/sonar-scanner
ENV HOME=/tmp \
    XDG_CONFIG_HOME=/tmp \
    SONAR_SCANNER_HOME=${SONAR_SCANNER_HOME} \
    SONAR_USER_HOME=${SONAR_SCANNER_HOME}/.sonar \
    PATH=${SONAR_SCANNER_HOME}/bin:/opt/poetry/venv/bin:${PATH} \
    SRC_PATH=/usr/src \
    SCANNER_WORKDIR_PATH=/tmp/.scannerwork \
    POETRY_CACHE_DIR=/opt/poetry/cache \
    POETRY_VIRTUALENVS_PATH=/opt/poetry/virtualenvs \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Copy Scanner installation from builder image
COPY --from=builder /opt/sonar-scanner /opt/sonar-scanner

RUN \
    apt-get -qqy update \
    # Security updates
    && apt-get upgrade -y \
    && apt-get install -y git \
    && apt-get install -y tar \
    && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && apt-get install -y python3 python3-venv \
    && python3 -m venv /opt/poetry/venv \
    && /opt/poetry/venv/bin/pip install --no-cache-dir --only-binary=poetry poetry==2.3.2 \
    && /opt/poetry/venv/bin/pip cache purge \
    && rm -rf /var/lib/apt/lists/* \
    && set -eux \
    # Reuse the existing .NET 10+ user with UID 1000; create it for root-only base images.
    && if ! getent passwd 1000 >/dev/null; then \
      getent group 1000 >/dev/null || groupadd --system --gid 1000 scanner-cli; \
      useradd --system -d "${HOME}" --uid 1000 --gid 1000 scanner-cli; \
    fi \
    && chown -R 1000:1000 "${SONAR_SCANNER_HOME}" "${SRC_PATH}" \
    && mkdir -p "${SRC_PATH}" "${SONAR_USER_HOME}" "${SONAR_USER_HOME}/cache" "${SCANNER_WORKDIR_PATH}" \
       "${POETRY_CACHE_DIR}" "${POETRY_VIRTUALENVS_PATH}" \
    && chown -R 1000:1000 "${SONAR_SCANNER_HOME}" "${SRC_PATH}" "${SCANNER_WORKDIR_PATH}" \
       "${POETRY_CACHE_DIR}" "${POETRY_VIRTUALENVS_PATH}" \
    && chmod -R 555 "${SONAR_SCANNER_HOME}" \
    && chmod -R 754 "${SRC_PATH}" "${SONAR_USER_HOME}" "${SCANNER_WORKDIR_PATH}" \
       "${POETRY_CACHE_DIR}" "${POETRY_VIRTUALENVS_PATH}"

COPY --chown=1000:1000 bin /usr/bin/

USER 1000

WORKDIR ${SRC_PATH}

ENTRYPOINT ["/usr/bin/entrypoint.sh"]

CMD ["sonar-scanner"]
