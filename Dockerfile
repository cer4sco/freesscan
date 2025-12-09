# freesscan - Python Scanner Container
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        postgresql-client \
        git \
    && rm -rf /var/lib/apt/lists/*

# Copy scanner code
COPY scanner/ /app/scanner/
COPY scripts/ /app/scripts/

# Install Python dependencies
RUN pip install --no-cache-dir \
    psycopg2-binary

# Make scripts executable
RUN chmod +x /app/scanner/main.py /app/scripts/*.sh

# Create non-root user (UID 1001 avoids conflicts with host user on Mac/Podman)
RUN useradd -m -u 1001 scanner && \
    chown -R scanner:scanner /app

USER scanner

ENTRYPOINT ["python3", "/app/scanner/main.py"]
