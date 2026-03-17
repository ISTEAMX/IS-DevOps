# IS-Devops

## Docker Compose Setup

### Prerequisites
- Docker and Docker Compose installed on your system

### Services
- **PostgreSQL 15**: Database service configured and ready to use

### Running Docker Compose

#### Start the services:
```bash
docker-compose -f docker-compose/docker-compose.yml up -d
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
docker-compose -f docker-compose/docker-compose.yml logs -f postgres
```

### PostgreSQL Connection Details
- **Host**: localhost
- **Port**: 5432
- **Username**: postgres
- **Password**: postgres
- **Database**: app_db

### Connect to PostgreSQL

#### Using psql:
```bash
psql -h localhost -U postgres -d app_db
```

#### Using Docker:
```bash
docker exec -it postgres_container psql -U postgres -d app_db
```
