# xo-cli Docker Container

This repository provides a flexible and automated solution for interacting with your Xen-Orchestra instance using the `xo-cli` within a Docker container. It is designed to handle common tasks like authentication and certificate management, allowing you to focus on your automation scripts.

## Features

- **Automated Authentication:** Automatically registers with the XO instance using either a username/password or a token.
- **Flexible Execution:** Supports running single `xo-cli` commands directly from the command line or executing complex, multi-line scripts.
- **JSON Processing:** Includes `jq` for parsing and filtering the JSON output from `xo-cli`.
- **Certificate Handling:** Can bypass self-signed certificate errors, which is common in development environments.
- **Permission-Agnostic Scripts:** Executes scripts from a mounted volume without requiring specific file permissions on the host.

## Prerequisites

- [Docker](https://www.docker.com/) installed on your machine.

## How to Build the Image

1.  **Clone this repository** (or save the `Dockerfile`, `entrypoint.sh` and `README.md` files).
2.  **Open a terminal** in the directory containing the files.
3.  **Build the Docker image** with the name `xo-cli`.

    ```bash
    docker build -t xo-cli .
    ```

---

## How to Use the Container

The container requires environment variables for authentication. You must choose one of the two methods below.

### Authentication

- **Using Username and Password:**
  - `XO_URL`: The URL of your Xen-Orchestra instance (e.g., `https://192.168.1.20:8443`).
  - `XO_USERNAME`: The username for your XO account.
  - `XO_PASSWORD`: The password for your XO account.

- **Using a Token:**
  - `XO_URL`: The URL of your Xen-Orchestra instance.
  - `XO_TOKEN`: A valid authentication token.

### Optional Environment Variables

- `XO_ALLOW_UNAUTHORIZED`: Set to `true` to allow connections to XO instances with self-signed certificates.

---

### 1. Running a Single Command

Use this method for quick, ad-hoc commands or simple queries.

#### a. With Username and Password

This example gets the ID of the `admin` user and filters the JSON output. The entire command is wrapped in `sh -c` to ensure the pipe (`|`) works correctly.

```bash
docker run --rm -it \
  -e XO_URL="[https://192.168.1.20:8443](https://192.168.1.20:8443)" \
  -e XO_USERNAME="admin" \
  -e XO_PASSWORD="m3gaFox50" \
  -e XO_ALLOW_UNAUTHORIZED="true" \
  xo-cli \
  sh -c "xo-cli user.getAll --json | jq -r '.[] | select(.email == \"admin\") | .id'"
```
#### b. With a Token

This example performs the same action as above, but uses an authentication token instead of a username and password.
Bash

```bash
docker run --rm -it \
  -e XO_URL="[https://192.168.1.20:8443](https://192.168.1.20:8443)" \
  -e XO_TOKEN="your-super-secret-token" \
  -e XO_ALLOW_UNAUTHORIZED="true" \
  xo-cli \
  sh -c "xo-cli user.getAll --json | jq -r '.[] | select(.email == \"admin\") | .id'"
```

### 2. Running a Script

This is the recommended method for running a series of commands or more complex automation tasks. The script file is mounted from your host into the container.

Create your script file (e.g., my_script.sh) in your local directory.

Add 2>/dev/null to xo-cli commands that output JSON to prevent log messages from breaking the JSON pipe.

```bash
    #!/bin/sh
    echo "Starting script execution..."
    echo "Listing all VMs:"
    xo-cli rest get vms fields=name_label,power_state --json 2>/dev/null | jq '.'
```
Run the container by mounting your local directory to the container's /scripts directory and using the SCRIPT_FILE environment variable to specify the script.

#### a. With Username and Password

```bash
docker run --rm -it \
  -e XO_URL="[https://192.168.1.20:8443](https://192.168.1.20:8443)" \
  -e XO_USERNAME="admin" \
  -e XO_PASSWORD="m3gaFox50" \
  -e SCRIPT_FILE="my_script.sh" \
  -v $(pwd):/scripts \
  xo-cli
```
#### b. With a Token

```bash
docker run --rm -it \
  -e XO_URL="[https://192.168.1.20:8443](https://192.168.1.20:8443)" \
  -e XO_TOKEN="your-super-secret-token" \
  -e SCRIPT_FILE="my_script.sh" \
  -v $(pwd):/scripts \
  xo-cli
```
### Troubleshooting

- parse error: Invalid numeric literal: This means jq is trying to parse non-JSON text. Ensure you're filtering out log messages from the xo-cli command by using 2>/dev/null.

- not found error: Check that the SCRIPT_FILE variable is set correctly and that the volume is properly mounted.

- write /dev/stdout: broken pipe: This occurs when the process supplying data to a pipe terminates prematurely. Enclose the command pipeline in sh -c "..." to ensure it runs entirely within the container.

- Command "hangs" and does not return: This indicates a network or authentication problem. Verify your XO_URL, credentials, and firewall rules to ensure the container can communicate with your XO instance.
