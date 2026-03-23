# IS-DevOps: Local Development Environment

This repository contains setups to run the ISTEAMX project locally. You can choose between a simple setup (backend, frontend, database) or a full AWS simulation.

---

## Workflow 1: Simple Docker Compose Setup

This workflow is for developers who only need the core application running and do not need to test AWS integration.

### Prerequisites
- Docker

### Startup
This will start the backend, frontend, and database containers.

```bash
# From the IS-DevOps/ root directory
docker-compose -f docker-compose/docker-compose.simple.yml up --build -d
```

### Accessing the Application
- **Frontend Application:** [http://localhost:80](http://localhost:80)
- **Backend API:** [http://localhost:8080](http://localhost:8080)

### Shutdown
```bash
# From the IS-DevOps/ root directory
docker-compose -f docker-compose/docker-compose.simple.yml down
```

---

## Workflow 2: Full Local AWS Environment

This workflow simulates a real AWS environment using Terraform and LocalStack. It is for developers who need to build or test features that interact with AWS services (like S3).

### One-Time Setup

<details>
<summary><strong>macOS Instructions</strong></summary>

> We recommend using [Homebrew](https://brew.sh/) to install prerequisites.

```bash
# Install Tools
brew install terraform node python awscli

# Install Python Packages
pip3 install awscli-local
```
</details>

<details>
<summary><strong>Windows Instructions</strong></summary>

> We recommend using [Chocolatey](https://chocolatey.org/install) to install prerequisites. Run these commands in an **Administrator** PowerShell.

```powershell
# Install Tools
choco install terraform nodejs python awscli -y

# Install Python Packages (in a new, non-admin terminal)
pip install awscli-local
```
</details>

### Environment Configuration

<details>
<summary><strong>macOS Instructions</strong></summary>

**For Colima Users:** If you use Colima instead of Docker Desktop, you must export the `DOCKER_HOST` environment variable. Add this line to your `~/.zshrc` or `~/.bash_profile` for convenience.
```bash
export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
```

**For All Users:** Create the backend `.env` file. This only needs to be done once.
```bash
# From the IS-DevOps/ root directory
cp ../IS-Backend/.env.example ../IS-Backend/.env
```
</details>

<details>
<summary><strong>Windows Instructions</strong></summary>

**For Docker Desktop Users:** No special Docker configuration is needed.

**For All Users:** Create the backend `.env` file. This only needs to be done once.
```powershell
# From the IS-DevOps/ root directory
copy ..\IS-Backend\.env.example ..\IS-Backend\.env
```
> **Note:** For best compatibility, we recommend running all subsequent commands in a terminal that understands Unix-style paths, like Git Bash or Windows Subsystem for Linux (WSL).
</details>

### Full Startup
Follow these steps to bring the entire environment online.

1.  **(macOS Colima Users):** Make sure your `DOCKER_HOST` variable is set in your terminal.
2.  **Start Infrastructure & Services:**
    ```bash
    # From the IS-DevOps/terraform/ directory
    terraform apply -auto-approve

    # From the IS-DevOps/ root directory
    docker-compose -f docker-compose/docker-compose.yml up -d
    ```
3.  **Build & Deploy Frontend:**
    ```bash
    # From the IS-DevOps/ root directory
    npm run build --prefix ../IS-Frontend
    awslocal s3 sync ../IS-Frontend/dist s3://isteamx-frontend
    ```

### Accessing the Application
- **Frontend Application:** [http://isteamx-frontend.s3-website.us-east-1.localhost.localstack.cloud:4566](http://isteamx-frontend.s3-website.us-east-1.localhost.localstack.cloud:4566)
- **Backend API:** [http://localhost:8080](http://localhost:8080)

### Shutting Down
This two-step process is required to avoid errors.

1.  **Stop App Containers:** This frees up the network.
    ```bash
    # From the IS-DevOps/ root directory
    docker-compose -f docker-compose/docker-compose.yml down
    ```
2.  **Destroy Infrastructure:** This removes the LocalStack container and S3 bucket.
    ```bash
    # From the IS-DevOps/terraform/ directory
    # (macOS Colima users must have DOCKER_HOST set)
    terraform destroy -auto-approve
    ```
