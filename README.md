# Disk Space Optimizer (GitHub Action)

![License](https://img.shields.io/static/v1?label=License&message=MIT&style=flat-square "License")
[![GitHub Repository](https://img.shields.io/badge/Repository-181717?logo=github&logoColor=ffffff&style=flat-square "GitHub Repository")](https://github.com/hugoalh/disk-space-optimizer-ghaction)
[![GitHub Stars](https://img.shields.io/github/stars/hugoalh/disk-space-optimizer-ghaction?label=Stars&logo=github&logoColor=ffffff&style=flat-square "GitHub Stars")](https://github.com/hugoalh/disk-space-optimizer-ghaction/stargazers)
[![GitHub Contributors](https://img.shields.io/github/contributors/hugoalh/disk-space-optimizer-ghaction?label=Contributors&logo=github&logoColor=ffffff&style=flat-square "GitHub Contributors")](https://github.com/hugoalh/disk-space-optimizer-ghaction/graphs/contributors)
[![GitHub Issues](https://img.shields.io/github/issues-raw/hugoalh/disk-space-optimizer-ghaction?label=Issues&logo=github&logoColor=ffffff&style=flat-square "GitHub Issues")](https://github.com/hugoalh/disk-space-optimizer-ghaction/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr-raw/hugoalh/disk-space-optimizer-ghaction?label=Pull%20Requests&logo=github&logoColor=ffffff&style=flat-square "GitHub Pull Requests")](https://github.com/hugoalh/disk-space-optimizer-ghaction/pulls)
[![GitHub Discussions](https://img.shields.io/github/discussions/hugoalh/disk-space-optimizer-ghaction?label=Discussions&logo=github&logoColor=ffffff&style=flat-square "GitHub Discussions")](https://github.com/hugoalh/disk-space-optimizer-ghaction/discussions)
[![CodeFactor Grade](https://img.shields.io/codefactor/grade/github/hugoalh/disk-space-optimizer-ghaction?label=Grade&logo=codefactor&logoColor=ffffff&style=flat-square "CodeFactor Grade")](https://www.codefactor.io/repository/github/hugoalh/disk-space-optimizer-ghaction)

| **Releases** | **Latest** (![GitHub Latest Release Date](https://img.shields.io/github/release-date/hugoalh/disk-space-optimizer-ghaction?label=&style=flat-square "GitHub Latest Release Date")) | **Pre** (![GitHub Latest Pre-Release Date](https://img.shields.io/github/release-date-pre/hugoalh/disk-space-optimizer-ghaction?label=&style=flat-square "GitHub Latest Pre-Release Date")) |
|:-:|:-:|:-:|
| [![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=ffffff&style=flat-square "GitHub")](https://github.com/hugoalh/disk-space-optimizer-ghaction/releases) ![GitHub Total Downloads](https://img.shields.io/github/downloads/hugoalh/disk-space-optimizer-ghaction/total?label=&style=flat-square "GitHub Total Downloads") | ![GitHub Latest Release Version](https://img.shields.io/github/release/hugoalh/disk-space-optimizer-ghaction?sort=semver&label=&style=flat-square "GitHub Latest Release Version") | ![GitHub Latest Pre-Release Version](https://img.shields.io/github/release/hugoalh/disk-space-optimizer-ghaction?include_prereleases&sort=semver&label=&style=flat-square "GitHub Latest Pre-Release Version") |

## 📝 Description

A GitHub Action to optimize disk space for GitHub hosted runner.

This action is inspired from:

- [data-intuitive/reclaim-the-bytes](https://github.com/data-intuitive/reclaim-the-bytes)
- [easimon/maximize-build-space](https://github.com/easimon/maximize-build-space)
- [jlumbroso/free-disk-space](https://github.com/jlumbroso/free-disk-space)
- [ShubhamTatvamasi/free-disk-space-action](https://github.com/ShubhamTatvamasi/free-disk-space-action)
- [ThewApp/free-actions](https://github.com/ThewApp/free-actions)

| **Name *(Case Insensitive)*** | **Description** | **Remove Method** | **OS** |
|:-:|:--|:-:|:-:|
| `AndroidLibrary` / `AndroidSdk` | Android SDK library. | Hard | Linux |
| `AzureCli` | Azure CLI. | Soft | Linux |
| `DockerImages` | Docker images, mostly pre-cached. | Soft | Linux, MacOS, Windows |
| `DotNet` | .Net (Dot Net) SDK. | Soft, Hard | Linux |
| `Firefox` | Mozilla Firefox browser. | Soft | Linux |
| `GoogleChrome` | Google Chrome browser. | Soft | Linux |
| `GoogleCloudSdk` | Google Cloud SDK. | Soft | Linux |
| `HaskellGhc` | Haskell GHC. | Hard | Linux |
| `Llvm` | LLVM. | Soft | Linux |
| `Mono` | Mono. | Soft | Linux |
| `MySql` | MySQL. | Soft | Linux |
| `MongoDb` | MongoDB. | Soft | Linux |
| `OpenGlDri` | Free implementation of the OpenGL API DRI modules. | Soft | Linux |
| `Php` | PHP. | Soft | Linux |
| `RunnerBoost` | GitHub Actions runner boost. | Hard | Linux |
| `RunnerToolsCache/All` | GitHub Actions runner tool cache. | Hard | Linux |
| `RunnerToolsCache/CodeQl` | GitHub Actions runner tool cache, CodeQL only. | Hard | Linux |
| `RunnerToolsCache/Go` | GitHub Actions runner tool cache, Go Lang only. | Hard | Linux |
| `Swap` | Linux swap space. | Hard | Linux |
| `Swift` | Swift. | Hard | Linux, MacOS, Windows |

## 📚 Documentation

### Getting Started

- GitHub Actions Runner >= v2.303.0
  - PowerShell >= v7.2.0

```yml
jobs:
  job_id:
    runs-on: "________" # Any
    steps:
      - uses: "hugoalh/disk-space-optimizer-ghaction@<Version>"
```

### 📥 Input

> **ℹ Notice:**
>
> All of the inputs are optional; Use this action without any inputs will remove all of the soft items.

#### `input_listdelimiter`

`<RegEx = ",|;|\r?\n">` Delimiter when the input is type of list (i.e.: array), by regular expression.

#### `remove_soft`

`<RegEx[]>` Remove item softly, less risk than hard remove.

#### `remove_hard`

`<RegEx[]>` Remove item hardly, can cause more issues than soft remove.

### 📤 Output

*N/A*

### Example

```yml
jobs:
  job_id:
    name: "Hello World"
    runs-on: "ubuntu-latest"
    steps:
      - uses: "hugoalh/disk-space-optimizer-ghaction@v1.0.0"
        with:
          remove_soft: ".+"
          remove_hard: ".+"
```
