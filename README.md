# IS-DevOps

This repository contains the Docker Compose setup for the ISTEAMX project.

## Docker Compose Setup

### Prerequisites
- Docker and Docker Compose installed on your system.
- You must have a `.env` file configured in the `IS-Backend` repository root. See the `IS-Backend/README.md` for instructions on how to set this up.

### Services
- **backend**: The Spring Boot backend application.
- **frontend**: The React frontend application.
- **database**: PostgreSQL database.

### Running Docker Compose

The `docker-compose.yml` file is located in the `docker-compose` directory.

#### Start the services:
From the `IS-DevOps` root directory, run:
```bash
docker-compose -f docker-compose/docker-compose.yml up -d --build
```

#### Stop the services:
```bash
docker-compose -f docker-compose/docker-compose.yml down
```

#### View logs:
```bash
docker-compose -f docker-compose/docker-compose.yml logs -f
```

#### View logs for a specific service:
```bash
docker-compose -f docker-compose/docker-compose.yml logs -f backend
```

### Accessing the applications
- **Backend**: [http://localhost:8080](http://localhost:8080)
- **Frontend**: [http://localhost:80](http://localhost:80)
