# Security Policy

## Supported Versions

> ```mermaid
> ---
> title: Versions Status Flow
> ---
> flowchart LR
>   Unstable("Unstable")
>   Pre("Pre Release")
>   Release("Release")
>   LTS("Long Term Support")
>   Maintenance("Maintenance")
>   EOL("End Of Life")
>   Unstable --> Pre
>   Pre --> Release
>   subgraph Support
>     Release -- Major = 0 --> Maintenance
>     Release -- Major > 0 --> LTS
>     LTS --> Maintenance
>   end
>   Maintenance --> EOL
> ```

| **Versions** | **Release Date** | **Long Term Support Date** | **End Of Life Date** |
|:-:|:-:|:-:|:-:|
| v0.8.X | 2024-01-15 | *N/A* | *Unknown* |
| v0.7.X | 2023-09-16 | *N/A* | 2024-04-15 |

> **ℹ️ Note**
>
> - The date format is according to ISO 8601 standard.
> - Values in italic format are subject to change.
> - Versions which not in the list are also end of life.

## Report A Vulnerability

You can report a security vulnerability by [create a security vulnerability report](https://github.com/hugoalh/hugoalh/blob/main/universal-guide/contributing.md#create-a-security-vulnerability-report).
