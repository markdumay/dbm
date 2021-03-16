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
Docker Build Manager (**DBM**) is a helper utility to simplify the development of custom Docker images. It includes versioning support, the definition of development and production images, and simplified commands to run images in detached or terminal mode. The repository also contains a script to harden a standard Linux Alpine base image. **DBM** uses Docker Compose under the hood.

<!-- TODO: add tutorial deep-link 
Detailed background information is available on the author's [personal blog][blog].
-->

## Built With
The project uses the following core software components:
* [Docker][docker_url] - Open-source container platform.
* [Notary][notary] - Client to interact with trusted collections, such as the Docker Hub.
* [ShellSpec][shellspec] - Framework for unit testing of shell scripts.

## Prerequisites
### Host Requirements
The Docker Build Manager (*dbm*) can run on any Docker-capable host that supports the execution of POSIX-shell scripts. Docker Compose needs to be installed too. The tool [jq][jq_download] is required for running dependency checks. The setup has been tested locally on macOS Big Sur and in production on a server running Ubuntu 20.04 LTS. 

### Repository Requirements
**DBM** assumes your repository defines three Docker Compose configurations. Both the production and development configuration are relative to the base image. See [nginx-certbot][nginx-cerbot] and [restic-unattended][restic-unattended] for an example.
1. `docker-compose.yml` - The base configuration of the Docker image using Docker Compose notation
2. `docker-compose.prod.yml` - Production modifications to the base configuration
3. `docker-compose.dev.yml` - Development modifications to the base configuration

For proper versioning support, the file `VERSION` needs to be present at the root of your repository. It is recommended to use [semantic versioning][semver_url].


## Deployment
Docker Build Manager works best if integrated as a submodule in your repository. Run the following command from within your repository directory to add **DBM** as a submodule.

```console
$ git submodule add https://github.com/markdumay/dbm dbm
```

Setup an `alias` to simplify the execution of *dbm*.
```console
$ alias dbm="dbm/dbm.sh"  
```

Add the same line to your shell settings (e.g. `~/.zshrc` on macOS or `~/.bashrc` on Ubuntu with bash login) to make the `alias` persistent.


## Usage
Use the following command to invoke **DBM** from the command line.

```
$ dbm <command> [flags]

```

### Commands
**DBM** supports the following commands. The Wiki contains a more extensive overview of the [available commands][wiki_commands] and their options.

| Command       | Description |
|---------------|-------------|
| **`build`**   | Build a Docker image |
| **`check`**   | Check for dependency upgrades |
| **`config`**  | Generate a merged Docker Compose file |
| **`deploy`**  | Deploy Docker Stack service(s) |
| **`down`**    | Stop running container(s) and network(s) |
| **`info`**    | Display current system information |
| **`stop`**    | Stop running container(s) |
| **`up`**      | Run Docker image(s) as container(s) |
| **`version`** | Show version information |


### Configuration
**DBM** supports several advanced settings through a `dbm.ini` file. An example `sample.ini` is available in the git [repository][repository]. The configuration files accepts [custom variables][wiki_vars] too, see the Wiki for more details. The Wiki also explains how to [define dependencies][wiki_dependencies] with version tracking.

| Variable              | Required | Example                   | Description |
|-----------------------|----------|---------------------------|-------------|
| `DOCKER_WORKING_DIR`  | `No`     | `./`                      | Working directory for building Docker images |
| `DOCKER_BASE_YML`     | `No`     | `docker-compose.yml`      | Base configuration of the Docker image using Docker Compose notation |
| `DOCKER_PROD_YML`     | `No`     | `docker-compose.prod.yml` | Production modifications to the base configuration |
| `DOCKER_DEV_YML`      | `No`     | `docker-compose.dev.yml`  | Development modifications to the base configuration |
| `DOCKER_SERVICE_NAME` | `No`     | `example`                 | Prefix to use when deploying images as Docker Stack services |


## Contributing
1. Clone the repository and create a new branch 
    ```console
    $ git checkout https://github.com/markdumay/dbm.git -b name_for_new_branch
    ```
2. Make and test the changes
3. Submit a Pull Request with a comprehensive description of the changes


## Donate
<a href="https://www.buymeacoffee.com/markdumay" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/lato-orange.png" alt="Buy Me A Coffee" style="height: 51px !important;width: 217px !important;"></a>

## License
The **DBM** codebase is released under the [MIT license][license]. The README.md file and files in the "[wiki][wiki]" repository are licensed under the Creative Commons *Attribution-NonCommercial 4.0 International* ([CC BY-NC 4.0)][cc-by-nc-4.0] license.

<!-- MARKDOWN PUBLIC LINKS -->
[docker_url]: https://docker.com
[semver_url]: https://semver.org
[jq_download]: https://stedolan.github.io/jq/download/

<!-- MARKDOWN MAINTAINED LINKS -->
<!-- TODO: add blog link
[blog]: https://markdumay.com
-->
[cc-by-nc-4.0]: https://creativecommons.org/licenses/by-nc/4.0/
[blog]: https://github.com/markdumay
[license]: https://github.com/markdumay/dbm/blob/main/LICENSE
[repository]: https://github.com/markdumay/dbm.git
[nginx-cerbot]: https://github.com/markdumay/nginx-certbot
[restic-unattended]: https://github.com/markdumay/restic-unattended
[notary]: https://github.com/theupdateframework/notary
[shellspec]: https://shellspec.info
[wiki]: https://github.com/markdumay/dbm/wiki/
[wiki_commands]: https://github.com/markdumay/dbm/wiki/Available-Commands
[wiki_dependencies]: https://github.com/markdumay/dbm/wiki/Defining-Dependencies
[wiki_vars]: https://github.com/markdumay/dbm/wiki/Defining-Custom-Variables
