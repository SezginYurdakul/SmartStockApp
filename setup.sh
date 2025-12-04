#!/bin/bash

# Smart Stock Management - Setup Script
# This script sets up both Laravel backend and React frontend

set -e

echo "========================================="
echo "Smart Stock Management - Setup"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

echo -e "${BLUE}Step 1: Creating Laravel Backend...${NC}"

if [ ! -d "backend" ]; then
    echo "  - Creating Laravel 12 project..."
    docker run --rm -v "$(pwd)":/app -w /app composer:latest create-project laravel/laravel backend
    echo -e "${GREEN}  ✓ Backend project created${NC}"
else
    echo -e "${YELLOW}  ! Backend directory already exists${NC}"
fi

# Fix permissions on backend directory
if [ -d "backend" ]; then
    echo "  - Fixing backend directory permissions..."
    chmod -R 755 backend 2>/dev/null || true
    chmod -R 777 backend/storage backend/bootstrap/cache 2>/dev/null || true

    # Configure .env file for PostgreSQL
    if [ -f "backend/.env" ]; then
        echo "  - Configuring backend .env for PostgreSQL..."
        docker run --rm -v "$(pwd)/backend":/app -w /app alpine:latest sh -c "
            sed -i 's/DB_CONNECTION=sqlite/DB_CONNECTION=pgsql/' .env && \
            sed -i 's/# DB_HOST=127.0.0.1/DB_HOST=postgres/' .env && \
            sed -i 's/DB_HOST=127.0.0.1/DB_HOST=postgres/' .env && \
            sed -i 's/# DB_PORT=3306/DB_PORT=5432/' .env && \
            sed -i 's/DB_PORT=3306/DB_PORT=5432/' .env && \
            sed -i 's/# DB_DATABASE=laravel/DB_DATABASE=laravel/' .env && \
            sed -i 's/# DB_USERNAME=root/DB_USERNAME=laravel/' .env && \
            sed -i 's/DB_USERNAME=root/DB_USERNAME=laravel/' .env && \
            sed -i 's/# DB_PASSWORD=/DB_PASSWORD=secret/' .env && \
            sed -i 's/REDIS_HOST=127.0.0.1/REDIS_HOST=redis/' .env && \
            sed -i 's/APP_NAME=Laravel/APP_NAME=\"Smart Stock Management\"/' .env && \
            echo '' >> .env && \
            echo '# Elasticsearch Configuration' >> .env && \
            echo 'ELASTICSEARCH_HOST=elasticsearch' >> .env && \
            echo 'ELASTICSEARCH_PORT=9200' >> .env && \
            echo 'SCOUT_DRIVER=elasticsearch' >> .env
        "
    fi

    echo -e "${GREEN}  ✓ Backend configuration completed${NC}"
fi

echo ""
echo -e "${BLUE}Step 2: Creating React Frontend...${NC}"

if [ ! -d "frontend" ]; then
    echo "  - Creating Vite React project..."
    docker run --rm -v "$(pwd)":/app -w /app node:20-alpine sh -c "npm create vite@latest frontend -- --template react"
    echo -e "${GREEN}  ✓ Frontend project created${NC}"
else
    echo -e "${YELLOW}  ! Frontend directory already exists${NC}"
fi

echo ""
echo -e "${BLUE}Step 3: Installing Frontend Dependencies...${NC}"

if [ -d "frontend" ]; then
    echo "  - Installing npm packages..."
    docker run --rm -v "$(pwd)/frontend":/app -w /app node:20-alpine sh -c "
        npm install && \
        npm install -D tailwindcss@^3 postcss autoprefixer && \
        npm install react-router-dom axios @tanstack/react-query
    "

    echo "  - Initializing Tailwind CSS..."
    docker run --rm -v "$(pwd)/frontend":/app -w /app node:20-alpine sh -c "npx tailwindcss init -p"

    echo -e "${GREEN}  ✓ Frontend dependencies installed${NC}"
else
    echo -e "${YELLOW}  ! Frontend directory not found${NC}"
fi

echo ""
echo -e "${BLUE}Step 4: Configuring Frontend...${NC}"

# Create frontend .env and update config files via Docker
docker run --rm -v "$(pwd)/frontend":/app -w /app alpine:latest sh -c "
  echo 'VITE_API_URL=http://localhost:8888/api/v1' > .env
"

docker run --rm -v "$(pwd)/frontend":/app -w /app alpine:latest sh -c "cat > tailwind.config.js << 'EOFCONFIG'
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    \"./index.html\",
    \"./src/**/*.{js,ts,jsx,tsx}\",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
        },
      },
    },
  },
  plugins: [],
}
EOFCONFIG
"

docker run --rm -v "$(pwd)/frontend":/app -w /app alpine:latest sh -c "cat > src/index.css << 'EOFCSS'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOFCSS
"

echo -e "${GREEN}  ✓ Frontend configuration completed${NC}"

echo ""
echo -e "${BLUE}Step 5: Building Docker Images...${NC}"
docker compose build

echo ""
echo -e "${BLUE}Step 6: Starting Docker Containers...${NC}"
docker compose up -d

echo ""
echo -e "${BLUE}Step 7: Waiting for services to be ready...${NC}"
sleep 10

echo ""
echo -e "${BLUE}Step 8: Running Database Migrations...${NC}"
docker compose exec -T php php artisan migrate --force

echo ""
echo "========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "========================================="
echo ""
echo "Services:"
echo "  - Backend API:      http://localhost:8888/api"
echo "  - Frontend (Dev):   http://localhost:5173"
echo "  - pgAdmin:          http://localhost:5050"
echo "  - Kibana:           http://localhost:5601"
echo "  - PostgreSQL:       localhost:5432"
echo "  - Elasticsearch:    http://localhost:9200"
echo "  - Redis:            localhost:6379"
echo ""
echo "Default Credentials:"
echo "  - Database:         laravel / secret"
echo "  - pgAdmin:          admin@admin.com / admin"
echo ""
echo "Useful Commands:"
echo "  - View logs:        docker compose logs -f"
echo "  - Stop services:    docker compose down"
echo "  - Enter PHP:        docker compose exec php sh"
echo "  - Enter Node:       docker compose exec node sh"
echo ""
echo -e "${YELLOW}Note: Frontend will be available at http://localhost:5173 once Node container starts${NC}"
echo ""
