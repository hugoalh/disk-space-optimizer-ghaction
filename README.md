# Disk Space Optimizer (GitHub Action)

[**⚖️** MIT](./LICENSE.md)

[![GitHub: hugoalh/disk-space-optimizer-ghaction](https://img.shields.io/github/v/release/hugoalh/disk-space-optimizer-ghaction?label=hugoalh/disk-space-optimizer-ghaction&labelColor=181717&logo=github&logoColor=ffffff&sort=semver&style=flat "GitHub: hugoalh/disk-space-optimizer-ghaction")](https://github.com/hugoalh/disk-space-optimizer-ghaction)

A GitHub Action to optimize the disk space for the GitHub hosted GitHub Actions runner.

This project is inspired from:

- [Free Disk Space](https://github.com/jlumbroso/free-disk-space)
- [Free Disk Space Action](https://github.com/ShubhamTatvamasi/free-disk-space-action)
- [Free Up Actions](https://github.com/ThewApp/free-actions)
- [Maximize Build Space](https://github.com/easimon/maximize-build-space)
- [Reclaim The Bytes](https://github.com/data-intuitive/reclaim-the-bytes)

> [!IMPORTANT]
> - This documentation is v0.8.0 based; To view other version's documentation, please visit the [versions list](https://github.com/hugoalh/disk-space-optimizer-ghaction/tags) and select the correct version.

## 🌟 Features

- Always continue on error to not breaking any process.
- Support all of the platforms.
- Support multiple types:
  - APT caches
  - [APT packages][list]
  - [Chocolatey packages][list]
  - [Directly bundled programs][list]
  - Docker caches
  - Docker images
  - Homebrew caches
  - [Homebrew packages][list]
  - NPM caches
  - [NPM packages][list]
  - OS page/swap file
  - [Pipx packages][list]
  - [Windows programs (WMIC)][list]

## 🔰 Begin

### 🎯 Targets

|  | **GitHub** |
|:--|:--|
| **[GitHub Actions](https://docs.github.com/en/actions)** | ✔️ |

> [!NOTE]
> - It is possible to use this action in other methods/ways which not listed in here, however it is not officially supported.

### #️⃣ Registries Identifier

- **GitHub:**
  ```
  hugoalh/disk-space-optimizer-ghaction[@{Tag}]
  ```

> [!NOTE]
> - It is recommended to use this module with tag for immutability.

### 🛡️ Permissions

*This module does not require any permission.*

## 🧩 Inputs

> [!NOTE]
> - All of the inputs are optional; Use this action without any input will default to do nothing.

> | **Legend** | **Description** |
> |:-:|:--|
> | 🔀 | Switch with groups (e.g.: `{E}`). |

### `operate_async`

`{Boolean = False}` Whether to operate in asynchronously, possibly reduce the operation duration.

### `operate_sudo`

`{Boolean = False}` Whether to execute this action in sudo mode in order to able operate protected resources on the non-Windows environment.

### `general_include`

`{RegEx[]}` Remove items which listed in the [list][list], by regular expression of the item name, separate each value per line.

### `general_exclude`

`{RegEx[]}` Exclude remove items which listed in the [list][list], by regular expression of the item name, separate each value per line.

### `docker_include`

`{RegEx[]}` Remove Docker images, by regular expression of the Docker image name, separate each value per line.

### `docker_exclude`

`{RegEx[]}` Exclude remove Docker images, by regular expression of the Docker image name, separate each value per line.

### `docker_prune`

`{Boolean = False}` Whether to prune Docker all of the dangling images.

### `docker_clean`

`{Boolean = False}` Whether to remove Docker cache, include all of the:

- build caches
- stopped/unused containers
- dangling and/or unreferenced images
- unused networks

### `apt_enable`

**🔀{E}** `{Boolean = False}` Whether to optimize via APT. Only affect items which listed in the [list][list].

If all of the inputs inside this switch group are `false`, this input will default to `true`.

### `apt_prune`

`{Boolean = False}` Whether to prune APT all of the packages that were automatically installed to satisfy dependencies for other packages and are now no longer needed.

### `apt_clean`

`{Boolean = False}` Whether to remove APT cache, include the local repository of retrieved package files.

### `chocolatey_enable`

**🔀{E}** `{Boolean = False}` Whether to optimize via Chocolatey. Only affect items which listed in the [list][list].

If all of the inputs inside this switch group are `false`, this input will default to `true`.

### `homebrew_enable`

**🔀{E}** `{Boolean = False}` Whether to optimize via Homebrew. Only affect items which listed in the [list][list].

If all of the inputs inside this switch group are `false`, this input will default to `true`.

### `homebrew_prune`

`{Boolean = False}` Whether to prune Homebrew all of the packages that were only installed as a dependency of other packages and are now no longer needed.

### `homebrew_clean`

`{Boolean = False}` Whether to remove Homebrew cache, include all of the:

- outdated downloads
- old versions of installed formulae
- stale lock files

### `npm_enable`

**🔀{E}** `{Boolean = False}` Whether to optimize via NPM. Only affect items which listed in the [list][list].

If all of the inputs inside this switch group are `false`, this input will default to `true`.

### `npm_prune`

`{Boolean = False}` Whether to prune NPM all of the extraneous packages.

### `npm_clean`

`{Boolean = False}` Whether to remove NPM cache.

### `pipx_enable`

**🔀{E}** `{Boolean = False}` Whether to optimize via Pipx. Only affect items which listed in the [list][list].

If all of the inputs inside this switch group are `false`, this input will default to `true`.

### `wmic_enable`

**🔀{E}** `{Boolean = False}` Whether to optimize via WMIC. Only affect items which listed in the [list][list].

If all of the inputs inside this switch group are `false`, this input will default to `true`.

### `fs_enable`

**🔀{E}** `{Boolean = False}` Whether to optimize via file system.

If all of the inputs inside this switch group are `false`, this input will default to `true`.

### `os_swap`

`{Boolean = False}` Whether to remove system page/swap file.

## 🧩 Outputs

*This action does not have any output.*

## ✍️ Example

- ```yml
  jobs:
    job_id:
      runs-on: "ubuntu-latest"
      steps:
        - name: "Optimize Disk Space"
          uses: "hugoalh/disk-space-optimizer-ghaction@v0.8.0"
          with:
            operate_sudo: "True"
            general_include: ".+"
            docker_include: ".+"
            docker_prune: "True"
            docker_clean: "True"
            apt_prune: "True"
            apt_clean: "True"
            homebrew_prune: "True"
            homebrew_clean: "True"
            npm_prune: "True"
            npm_clean: "True"
            os_swap: "True"
  ```

## 📚 Guides

- GitHub Actions
  - [Enabling debug logging](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/enabling-debug-logging)

[list]: ./list.tsv
