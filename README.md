[list]: ./list.json

# Disk Space Optimizer (GitHub Action)

[⚖️ MIT](./LICENSE.md)
[![CodeFactor Grade](https://img.shields.io/codefactor/grade/github/hugoalh/disk-space-optimizer-ghaction?label=Grade&logo=codefactor&logoColor=ffffff&style=flat-square "CodeFactor Grade")](https://www.codefactor.io/repository/github/hugoalh/disk-space-optimizer-ghaction)

|  | **Heat** | **Release - Latest** | **Release - Pre** |
|:-:|:-:|:-:|:-:|
| [![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=ffffff&style=flat-square "GitHub")](https://github.com/hugoalh/disk-space-optimizer-ghaction) | [![GitHub Stars](https://img.shields.io/github/stars/hugoalh/disk-space-optimizer-ghaction?label=&logoColor=ffffff&style=flat-square "GitHub Stars")](https://github.com/hugoalh/disk-space-optimizer-ghaction/stargazers) \| ![GitHub Total Downloads](https://img.shields.io/github/downloads/hugoalh/disk-space-optimizer-ghaction/total?label=&style=flat-square "GitHub Total Downloads") | ![GitHub Latest Release Version](https://img.shields.io/github/release/hugoalh/disk-space-optimizer-ghaction?sort=semver&label=&style=flat-square "GitHub Latest Release Version") (![GitHub Latest Release Date](https://img.shields.io/github/release-date/hugoalh/disk-space-optimizer-ghaction?label=&style=flat-square "GitHub Latest Release Date")) | ![GitHub Latest Pre-Release Version](https://img.shields.io/github/release/hugoalh/disk-space-optimizer-ghaction?include_prereleases&sort=semver&label=&style=flat-square "GitHub Latest Pre-Release Version") (![GitHub Latest Pre-Release Date](https://img.shields.io/github/release-date-pre/hugoalh/disk-space-optimizer-ghaction?label=&style=flat-square "GitHub Latest Pre-Release Date")) |

A GitHub Action to optimize disk space for GitHub hosted runner.

This project is inspired from:

- [data-intuitive/reclaim-the-bytes](https://github.com/data-intuitive/reclaim-the-bytes)
- [easimon/maximize-build-space](https://github.com/easimon/maximize-build-space)
- [jlumbroso/free-disk-space](https://github.com/jlumbroso/free-disk-space)
- [ShubhamTatvamasi/free-disk-space-action](https://github.com/ShubhamTatvamasi/free-disk-space-action)
- [ThewApp/free-actions](https://github.com/ThewApp/free-actions)

> **⚠️ Important:** This documentation is v0.7.0 based; To view other version's documentation, please visit the [versions list](https://github.com/hugoalh/disk-space-optimizer-ghaction/tags) and select the correct version.

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

## 🔰 Begin

### GitHub Actions

- **Target Version:** Runner >= v2.308.0, &:
  - PowerShell >= v7.2.0
- **Require Permission:** *N/A*

```yml
jobs:
  job_id:
    runs-on: "________" # Any
    steps:
      - uses: "hugoalh/disk-space-optimizer-ghaction@<Version>"
```

## 🧩 Input

> **ℹ️ Notice:** All of the inputs are optional; Use this action without any input will default to do nothing.

### `input_listdelimiter`

`<RegEx = ",|;|\r?\n">` Delimiter when the input is accept list of values, by regular expression.

### `operate_async`

> **🧪 Experimental:** This is in testing, maybe available in the latest version and/or future version.

`<Boolean = False>` Whether to operate in asynchronously to reduce the operation duration.

### `operate_sudo`

`<Boolean = False>` Whether to execute this action in sudo mode on non-Windows environment. This can set to `True` in order to able operate protected resources on non-Windows environment.

### `general_include`

`<RegEx[]>` Remove general item, by regular expression and [general list][list], separate each name by [list delimiter (input `input_listdelimiter`)](#input_listdelimiter).

### `general_exclude`

`<RegEx[]>` Exclude remove general item, by regular expression and [general list][list], separate each name by [list delimiter (input `input_listdelimiter`)](#input_listdelimiter).

### `docker_include`

`<RegEx[]>` Remove Docker image, by regular expression, separate each name by [list delimiter (input `input_listdelimiter`)](#input_listdelimiter).

### `docker_exclude`

`<RegEx[]>` Exclude remove Docker image, by regular expression, separate each name by [list delimiter (input `input_listdelimiter`)](#input_listdelimiter).

### `docker_prune`

`<Boolean = False>` Whether to prune Docker all of the dangling images.

### `docker_clean`

`<Boolean = False>` Whether to remove Docker cache, include all of the:

- build caches
- stopped/unused containers
- dangling and/or unreferenced images
- unused networks

### `apt_enable`

`<Boolean = True>` Whether to optimize via APT. Only affect general optimization.

### `apt_prune`

`<Boolean = False>` Whether to prune APT (Advanced Packaging Tools) all of the packages that were automatically installed to satisfy dependencies for other packages and are now no longer needed.

### `apt_clean`

`<Boolean = False>` Whether to remove APT (Advanced Packaging Tools) cache, include the local repository of retrieved package files.

### `chocolatey_enable`

`<Boolean = True>` Whether to optimize via Chocolatey. Only affect general optimization.

### `homebrew_enable`

`<Boolean = True>` Whether to optimize via Homebrew. Only affect general optimization.

### `homebrew_prune`

`<Boolean = False>` Whether to prune Homebrew all of the packages that were only installed as a dependency of other packages and are now no longer needed.

### `homebrew_clean`

`<Boolean = False>` Whether to remove Homebrew cache, include all of the:

- outdated downloads
- old versions of installed formulae
- stale lock files

### `npm_enable`

`<Boolean = True>` Whether to optimize via NPM. Only affect general optimization.

### `npm_prune`

`<Boolean = False>` Whether to prune NPM (NodeJS Package Manager) all of the extraneous packages.

### `npm_clean`

`<Boolean = False>` Whether to remove NPM (NodeJS Package Manager) cache.

### `pipx_enable`

`<Boolean = True>` Whether to optimize via Pipx. Only affect general optimization.

### `wmic_enable`

`<Boolean = True>` Whether to optimize via WMIC. Only affect general optimization.

### `fs_enable`

`<Boolean = True>` Whether to optimize via file system.

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
          uses: "hugoalh/disk-space-optimizer-ghaction@v0.7.0"
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
