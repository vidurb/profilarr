# Stage 1: Build Frontend
FROM node:18 AS frontend-build
WORKDIR /app
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ .
RUN npm run build

# Stage 2: Backend Base
FROM python:3.9-slim AS backend-base
WORKDIR /app
# Install system dependencies if needed (e.g. for some python packages)
# git is often needed for pip installing from git
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 3: Development
FROM backend-base AS development
ENV FLASK_ENV=development
ENV FLASK_DEBUG=1
# In dev, we mount the volume, so we don't necessarily need to copy the code, 
# but copying it serves as a default.
COPY backend/ .
EXPOSE 5000
CMD ["python", "-m", "app.main"]

# Stage 4: Production
FROM backend-base AS production
ENV FLASK_ENV=production

# Create config directory and set permissions
RUN mkdir -p /config /app/app/static \
    && chown -R nobody:nogroup /config /app

# Copy backend code
COPY backend/ .

# Copy built frontend assets to the static directory expected by Flask
# Assuming the Flask app serves static from 'app/static' or similar. 
# Based on existing root Dockerfile: COPY dist/static ./app/static
# And backend/app/main.py: app = Flask(__name__, static_folder='static')
# So we need to place them in /app/app/static
COPY --from=frontend-build /app/dist /app/app/static

# Set permissions for the application code
RUN chown -R nobody:nogroup /app

# Metadata
LABEL org.opencontainers.image.title="Profilarr"
LABEL org.opencontainers.image.description="Profilarr - Profile manager for *arr apps"
LABEL org.opencontainers.image.source="https://github.com/vidurb/profilarr"

RUN chown -R nobody:nogroup /config
# Switch to non-root user
USER nobody:nogroup


VOLUME ["/config"]
EXPOSE 6868

# Use gunicorn as in the original root Dockerfile
CMD ["gunicorn", "--bind", "0.0.0.0:6868", "--timeout", "600", "app.main:create_app()"]
