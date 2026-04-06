# Local Development: IS-DevOps

## Overview
For rapid development, we use **Docker Compose** to run the core application services locally. This setup includes the backend, frontend, and a local PostgreSQL database, all pre-configured to work together without an AWS dependency.

## Prerequisites
- **Docker**: [Install Docker Desktop](https://docs.docker.com/get-docker/) (includes Docker Compose).

## Running the Stack

### 1. Startup
From the root of the `IS-DevOps` repository, run:
```bash
docker-compose -f docker-compose/docker-compose.yml up --build -d
```
- `--build`: Force re-build of the images to incorporate any recent code changes.
- `-d`: Run in detached mode (in the background).

### 2. Service Access
| Service  | URL                                      | Description                              |
|----------|------------------------------------------|------------------------------------------|
| Frontend | [http://localhost:80](http://localhost:80)     | React application served via Nginx.     |
| Backend  | [http://localhost:8080](http://localhost:8080) | Spring Boot REST API.                    |
| Database | `localhost:5432`                         | PostgreSQL (use credentials from `.env`).|

### 3. Monitoring
To view the logs for all services:
```bash
docker-compose -f docker-compose/docker-compose.yml logs -f
```

### 4. Shutdown & Cleanup
To stop the services and remove the containers:
```bash
docker-compose -f docker-compose/docker-compose.yml down
```
To also remove volumes (warning: deletes local database data):
```bash
docker-compose -f docker-compose/docker-compose.yml down -v
```

## Environment Variables
The local development workflow uses a `.env` file located in the `IS-Backend` directory for database and JWT secrets. Ensure you've copied the `.env.example` to `.env` in that project before starting.
