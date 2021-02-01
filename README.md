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
Docker Compose is a popular tool to deploy Docker images. This repository uses Docker Compose to further simplify the development of custom Docker images. It includes versioning support, the definition of development and production images, and simplified commands to run images in detached or terminal mode. The repository also contains a script to harden a standard Linux Alpine base image.

<!-- TODO: add tutorial deep-link 
Detailed background information is available on the author's [personal blog][blog].
-->

## Built With
The project uses the following core software components:
* [Docker][docker_url] - Open-source container platform.
* POSIX shell - Included shell scripts are all POSIX compliant.

## Prerequisites
### Host Requirements
The Docker Build Manager (*dbm*) can run on any Docker-capable host that supports the execution of POSIX-shell scripts. Docker Compose needs to be installed too. The setup has been tested locally on macOS Big Sur and in production on a server running Ubuntu 20.04 LTS. 

### Repository Requirements
*dbm* assumes your repository defines three Docker Compose configurations. The production configuration amends or modifies the base image, and, similarly, the development configuration adjusts the production configuration. See the [nginx-certbot][nginx-cerbot] repository for an example.
1. `docker-compose.yml` - The base configuration of the Docker image using Docker Compose notation
2. `docker-compose.prod.yml` - Production modifications to the base configuration
3. `docker-compose.dev.yml`  - Development modifications to the production configuration

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
| `DOCKER_DEV_YML`      | `No`     | `docker-compose.dev.yml`  | Development modifications to the production configuration |
| `DOCKER_SERVICE_NAME` | `No`     | `example`                 | Prefix to use when deploying images as containers |


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

<!-- MARKDOWN MAINTAINED LINKS -->
<!-- TODO: add blog link
[blog]: https://markdumay.com
-->
[blog]: https://github.com/markdumay
[repository]: https://github.com/markdumay/dbm.git
[nginx-cerbot]: https://github.com/markdumay/nginx-certbot
