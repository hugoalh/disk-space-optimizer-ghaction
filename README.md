[list]: ./list.json

# Disk Space Optimizer (GitHub Action)

[**⚖️** MIT](./LICENSE.md)

**🗂️**
[![GitHub: hugoalh/disk-space-optimizer-ghaction](https://img.shields.io/badge/hugoalh/disk--space--optimizer--ghaction-181717?logo=github&logoColor=ffffff&style=flat "GitHub: hugoalh/disk-space-optimizer-ghaction")](https://github.com/hugoalh/disk-space-optimizer-ghaction)

**🆙** ![Latest Release Version](https://img.shields.io/github/release/hugoalh/disk-space-optimizer-ghaction?sort=semver&color=2187C0&label=&style=flat "Latest Release Version") (![Latest Release Date](https://img.shields.io/github/release-date/hugoalh/disk-space-optimizer-ghaction?color=2187C0&label=&style=flat "Latest Release Date"))

A GitHub Action to optimize disk space for GitHub hosted runner.

This project is inspired from:

- [data-intuitive/reclaim-the-bytes](https://github.com/data-intuitive/reclaim-the-bytes)
- [easimon/maximize-build-space](https://github.com/easimon/maximize-build-space)
- [jlumbroso/free-disk-space](https://github.com/jlumbroso/free-disk-space)
- [ShubhamTatvamasi/free-disk-space-action](https://github.com/ShubhamTatvamasi/free-disk-space-action)
- [ThewApp/free-actions](https://github.com/ThewApp/free-actions)

> [!IMPORTANT]
> This documentation is v0.8.0 based; To view other version's documentation, please visit the [versions list](https://github.com/hugoalh/disk-space-optimizer-ghaction/tags) and select the correct version.

## 🌟 Feature

- Always continue on error to not breaking any process.
- Support all of the platforms.
- Support multiple types:
  - APT (Advanced Packaging Tools) caches
  - [APT (Advanced Packaging Tools) packages][list]
  - [Chocolatey packages][list]
  - [Directly bundled programs][list]
  - Docker caches
  - Docker images
  - Homebrew caches
  - [Homebrew packages][list]
  - NPM (NodeJS Package Manager) caches
  - [NPM (NodeJS Package Manager) packages][list]
  - OS page/swap file
  - [Pipx packages][list]
  - [Windows programs (WMIC)][list]

## 🎯 Target

- GitHub Actions Runner
  > **🛡️ Require Permission**
  >
  > *N/A*

  > **💽 Require Software**
  >
  > - PowerShell >= v7.2.0

## 🔰 Usage

### Composite Action

1. Import at the metadata (`action.yml`):
    ```yml
    runs:
      using: "composite"
      steps:
        - uses: "hugoalh/disk-space-optimizer-ghaction@<Tag>"
    ```

### Workflow

1. Import at the workflow (`.github/workflows/<WorkflowName>.yml`):
    ```yml
    jobs:
      job_id:
        runs-on: "________" # Any
        steps:
          - uses: "hugoalh/disk-space-optimizer-ghaction@<Tag>"
    ```

## 🧩 Input

> [!NOTE]
> All of the inputs are optional; Use this action without any input will default to do nothing.

> | **Legend** | **Description** |
> |:-:|:--|
> | 🔀 | Switch with groups (e.g.: `{E}`). |

### `operate_async`

> **🧪 Experimental**
>
> This is in testing, maybe available in the latest version and/or future version.

`<Boolean = False>` Whether to operate in asynchronously to reduce the operation duration.

### `operate_sudo`

`<Boolean = False>` Whether to execute this action in sudo mode on non-Windows environment. This can set to `True` in order to able operate protected resources on non-Windows environment.

### `general_include`

`<RegEx[]>` Remove general item, by regular expression and [general list][list], separate each value per line.

### `general_exclude`

`<RegEx[]>` Exclude remove general item, by regular expression and [general list][list], separate each value per line.

### `docker_include`

`<RegEx[]>` Remove Docker image, by regular expression, separate each value per line.

### `docker_exclude`

`<RegEx[]>` Exclude remove Docker image, by regular expression, separate each value per line.

### `docker_prune`

`<Boolean = False>` Whether to prune Docker all of the dangling images.

### `docker_clean`

`<Boolean = False>` Whether to remove Docker cache, include all of the:

- build caches
- stopped/unused containers
- dangling and/or unreferenced images
- unused networks

### `apt_enable`

**🔀{E}** `<Boolean = False>` Whether to optimize via APT. Only affect general optimization.

If all of the inputs inside this switch group are `False`, this input will default to `True`.

### `apt_prune`

`<Boolean = False>` Whether to prune APT (Advanced Packaging Tools) all of the packages that were automatically installed to satisfy dependencies for other packages and are now no longer needed.

### `apt_clean`

`<Boolean = False>` Whether to remove APT (Advanced Packaging Tools) cache, include the local repository of retrieved package files.

### `chocolatey_enable`

**🔀{E}** `<Boolean = False>` Whether to optimize via Chocolatey. Only affect general optimization.

If all of the inputs inside this switch group are `False`, this input will default to `True`.

### `homebrew_enable`

**🔀{E}** `<Boolean = False>` Whether to optimize via Homebrew. Only affect general optimization.

If all of the inputs inside this switch group are `False`, this input will default to `True`.

### `homebrew_prune`

`<Boolean = False>` Whether to prune Homebrew all of the packages that were only installed as a dependency of other packages and are now no longer needed.

### `homebrew_clean`

`<Boolean = False>` Whether to remove Homebrew cache, include all of the:

- outdated downloads
- old versions of installed formulae
- stale lock files

### `npm_enable`

**🔀{E}** `<Boolean = False>` Whether to optimize via NPM. Only affect general optimization.

If all of the inputs inside this switch group are `False`, this input will default to `True`.

### `npm_prune`

`<Boolean = False>` Whether to prune NPM (NodeJS Package Manager) all of the extraneous packages.

### `npm_clean`

`<Boolean = False>` Whether to remove NPM (NodeJS Package Manager) cache.

### `pipx_enable`

**🔀{E}** `<Boolean = False>` Whether to optimize via Pipx. Only affect general optimization.

If all of the inputs inside this switch group are `False`, this input will default to `True`.

### `wmic_enable`

**🔀{E}** `<Boolean = False>` Whether to optimize via WMIC. Only affect general optimization.

If all of the inputs inside this switch group are `False`, this input will default to `True`.

### `fs_enable`

**🔀{E}** `<Boolean = False>` Whether to optimize via file system.

If all of the inputs inside this switch group are `False`, this input will default to `True`.

### `os_swap`

`<Boolean = False>` Whether to remove system page/swap file.

## 🧩 Output

*N/A*

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

## 📚 Guide

- GitHub Actions
  - [Enabling debug logging](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/enabling-debug-logging)
