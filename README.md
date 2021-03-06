# Docker Build Manager (work in progress)

<!-- Tagline -->
<p align="center">
    <b>Simplify the Development and Testing of Docker Images</b>
    <br />
</p>


<!-- Badges -->
<p align="center">
    <a href="https://github.com/markdumay/dbm/commits/main" alt="Last commit">
        <img src="https://img.shields.io/github/last-commit/markdumay/dbm.svg" />
    </a>
    <a href="https://github.com/markdumay/dbm/issues" alt="Issues">
        <img src="https://img.shields.io/github/issues/markdumay/dbm.svg" />
    </a>
    <a href="https://github.com/markdumay/dbm/pulls" alt="Pulls">
        <img src="https://img.shields.io/github/issues-pr-raw/markdumay/dbm.svg" />
    </a>
    <a href="https://github.com/markdumay/dbm/blob/main/LICENSE" alt="License">
        <img src="https://img.shields.io/github/license/markdumay/dbm" />
    </a>
</p>

<!-- Table of Contents -->
<p align="center">
  <a href="#about">About</a> •
  <a href="#built-with">Built With</a> •
  <a href="#prerequisites">Prerequisites</a> •
  <a href="#deployment">Deployment</a> •
  <a href="#usage">Usage</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#donate">Donate</a> •
  <a href="#license">License</a>
</p>


## About
Docker Compose is a popular tool to deploy Docker images. This repository uses Docker Compose to further simplify the development of custom Docker images. It includes versioning support, the definition of development and production images, and simplified commands to run images in detached or terminal mode. It supports both regular builds and multi-architecture builds. The repository also contains a script to harden a standard Linux Alpine base image.

<!-- TODO: add tutorial deep-link 
Detailed background information is available on the author's [personal blog][blog].
-->

## Built With
The project uses the following core software components:
* [Docker][docker_url] - Open-source container platform.
* POSIX shell - Included shell scripts are all POSIX compliant.

## Prerequisites
### Host Requirements
The Docker Build Manager (*dbm*) can run on any Docker-capable host that supports the execution of POSIX-shell scripts. Docker Compose needs to be installed too. The tool [jq][jq_download] is required for running dependency checks. The setup has been tested locally on macOS Big Sur and in production on a server running Ubuntu 20.04 LTS. 

### Repository Requirements
*dbm* assumes your repository defines three Docker Compose configurations. Both the production and development configuration are relative to the base image. See the [nginx-certbot][nginx-cerbot] repository for an example.
1. `docker-compose.yml` - The base configuration of the Docker image using Docker Compose notation
2. `docker-compose.prod.yml` - Production modifications to the base configuration
3. `docker-compose.dev.yml` - Development modifications to the base configuration

For proper versioning support, the file `VERSION` needs to be present at the root of your repository. It is recommended to use [semantic versioning][semver_url].


## Deployment
Docker Build Manager works best if integrated as a submodule in your repository. Run the following command from within your repository directory to add *dbm* as a submodule.

```console
git submodule add https://github.com/markdumay/dbm dbm
```

Setup an `alias` to simplify the execution of *dbm*.
```console
alias dbm="dbm/dbm.sh"  
```

Add the same line to your shell settings (e.g. `~/.zshrc` on macOS or `~/.bashrc` on Ubuntu with bash login) to make the `alias` persistent.


## Usage
Use the following command to invoke *dbm* from the command line.

```
dbm COMMAND [SUBCOMMAND] [OPTIONS] [SERVICE...]
```

### Commands
*dbm* supports the following commands. 

| Command       | Description |
|---------------|-------------|
| **`prod`**    | Target a production image |
| **`dev`**     | Target a development image |
| **`check`**     | Check for dependency upgrades |
| **`version`** | Show version information |

The commands `prod` and `dev` support the following subcommands.
| Subcommand   | Applicable to | Description |
|--------------|---------------|-------------|
| **`build`**  | `prod`, `dev` | Build a Docker image |
| **`deploy`** | `prod`, `dev` | Deploy the container as Docker Stack service |
| **`down`**   | `prod`, `dev` | Stop a running container and remove defined containers/networks |
| **`up`**     | `prod`, `dev` | Run a Docker image as container |
| **`stop`**   | `prod`, `dev` | Stop a running container |


The following options are available also.

| Option | Alias        | Description |
|--------|--------------|-------------|
| `-d`   | `--detached` | Run in detached mode |
| `-t`   | `--terminal` | Run in detached mode and start terminal (if supported by image) |

Lastly, adding the name of one or more services restricts the operation to the specified services only. If omitted, *dbm* processes all services defined by the Docker Compose configuration.

### Configuration
*dbm* supports several advanced settings through a `dbm.ini` file. An example `sample.ini` is available in the git [repository][repository].

| Variable              | Required | Example                   | Description |
|-----------------------|----------|---------------------------|-------------|
| `DOCKER_WORKING_DIR`  | `No`     | `./`                      | Working directory for building Docker images |
| `DOCKER_BASE_YML`     | `No`     | `docker-compose.yml`      | Base configuration of the Docker image using Docker Compose notation |
| `DOCKER_PROD_YML`     | `No`     | `docker-compose.prod.yml` | Production modifications to the base configuration |
| `DOCKER_DEV_YML`      | `No`     | `docker-compose.dev.yml`  | Development modifications to the base configuration |
| `DOCKER_SERVICE_NAME` | `No`     | `example`                 | Prefix to use when deploying images as containers |

### Defining Custom Variables
*Dbm* supports custom variables in addition to the predefined variables described in the previous section. Any variable starting with the prefix `DBM_` within the `dbm.ini` file is exported to be used by any of the *dbm* commands `build`, `deploy`, `down`, `up`, and `stop`.

For example, the following pseudo code uses the variables `UID` and `GID` to add a non-root user to the Docker image.

1. Use the prefix `DBM_` to define custom variables in **dbm.ini**
```
[...]
DBM_BUILD_UID=1234
DBM_BUILD_GID=1234
DBM_BUILD_USER=myuser
```

2. Expose the custom variables as build arguments in **docker-compose.yml** (removing the `DBM_` prefix)
```
version: "3.7"

services:
  <service-name>:
    image: <image-name>
    build:
      dockerfile: Dockerfile
      context: .
      args:
        BUILD_UID:  "${BUILD_UID}"
        BUILD_GID:  "${BUILD_GID}"
        BUILD_USER: "${BUILD_USER}"
```

3. Define the build arguments with default values in **Dockerfile**
```
ARG BUILD_UID=1001
ARG BUILD_GID=1001
ARG BUILD_USER=user
FROM <base-image>

RUN set -eu; \
    apk update -f; \
    apk --no-cache add -f shadow; \
    rm -rf /var/cache/apk/*; \
    /usr/sbin/groupadd -g "${BUILD_GID}" "${BUILD_USER}"; \
    /usr/sbin/useradd -s /bin/sh -g "${BUILD_GID}" -u "${BUILD_UID}" "${BUILD_USER}"; \
[...]
```

### Defining Dependencies
*Dbm* supports versioning of dependencies. Dependencies are identified by the pattern `DBM_*_VERSION` as a variant to a custom variable. Invoking the command `check` scans all dependencies and verifies if a newer version is available in a repository. Currently supported repository providers are `github.com` and `hub.docker.com`. The algorithm expects a semantic versioning pattern, following the pattern `MAJOR.MINOR.PATCH` with a potential extension. The matching is not strict, as version strings consisting of only `MAJOR` or `MAJOR.MINOR` are also considered valid. A `v` or `V` prefix is optional. Dependencies are exported as environment variables in similar fashion to custom variables. The provider url is removed in this case.

#### Input Definitions
The format of a dependency takes the following form:
```
DBM_<IDENTIFIER>_VERSION=<MAJOR>[.MINOR][.PATCH][EXTENSION]
DBM_<IDENTIFIER>_VERSION=[{http|https}]<PROVIDER>[/r]/<OWNER>/<REPO> [{v|V}]<MAJOR>[.MINOR][.PATCH][EXTENSION]
```

The following dependency definitions are all valid examples.
```
DBM_GOLANG_VERSION=https://hub.docker.com/_/golang 1.16-buster
DBM_ALPINE_GIT_VERSION=https://hub.docker.com/r/alpine/git v2.30
DBM_RESTIC_VERSION=github.com/restic/restic 0.12.0 # this is a comment
DBM_ALPINE_VERSION=3.12
```

The following *version strings* are examples of valid or invalid inputs:
| Version string           | Format  | Comments |
|--------------------------|---------|----------|
| `1.14-buster`            | Valid   | `MAJOR='1'`, `MINOR='14'`, `EXTENSION='-buster'` |
| `1.14.15`                | Valid   | `MAJOR='1'`, `MINOR='14'`, `PATCH='15'` |
| `alpine3.13`             | Invalid | Starts with `EXTENSION='alpine'` instead of `MAJOR` |
| `windowsservercore-1809` | Invalid | Starts with `EXTENSION='windowsservercore'` instead of `MAJOR` |

#### Potential Outcomes of Check Command
Invoking the command `check` scans all dependencies for potential version updates. The outcome for each dependency can be one of the following:

* **No repository link, skipping** - The dependency does not specify a repository, e.g. `DBM_ALPINE_VERSION=3.12`.
* **Malformed, skipping** - At least one of the mandatory arguments `PROVIDER`, `OWNER`, `REPO`, or `MAJOR` is missing. For example, in the dependency `DBM_RESTIC_VERSION=github.com/restic 0.12.0` the `REPO` is missing.
* **Provider not supported, skipping** - The specified provider is not supported, currently only `github.com` and `hub.docker.com` are supported. For example. `DBM_YAML_VERSION=gopkg.in/yaml.v2 v2.4.0` refers to the unsupported provider `gopkg.in`.
* **No tags found, skipping** - The repository did not return any tags matching the (optional) extension. Ensure the `OWNER` and `REPO` are correct.
* **Different version found** - The repository returned a different version as latest (which might be newer). It is recommended to verify the available release and to update the dependency version as required.

## Contributing
1. Clone the repository and create a new branch 
    ```console
    git checkout https://github.com/markdumay/dbm.git -b name_for_new_branch
    ```
2. Make and test the changes
3. Submit a Pull Request with a comprehensive description of the changes


## Donate
<a href="https://www.buymeacoffee.com/markdumay" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/lato-orange.png" alt="Buy Me A Coffee" style="height: 51px !important;width: 217px !important;"></a>

## License
<a href="https://github.com/markdumay/dbm/blob/main/LICENSE" alt="License">
    <img src="https://img.shields.io/github/license/markdumay/dbm" />
</a>

Copyright © [Mark Dumay][blog]



<!-- MARKDOWN PUBLIC LINKS -->
[docker_url]: https://docker.com
[semver_url]: https://semver.org
[jq_download]: https://stedolan.github.io/jq/download/

<!-- MARKDOWN MAINTAINED LINKS -->
<!-- TODO: add blog link
[blog]: https://markdumay.com
-->
[blog]: https://github.com/markdumay
[repository]: https://github.com/markdumay/dbm.git
[nginx-cerbot]: https://github.com/markdumay/nginx-certbot
