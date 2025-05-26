# Base image with Python 3.10
FROM python:3.10-slim

LABEL maintainer="you@example.com" 
WORKDIR /opt/ail

# Install system dependencies (this layer is often cached if it doesn't change)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential libssl-dev libffi-dev \
      libxml2-dev libxslt1-dev zlib1g-dev \
      libfuzzy-dev libtesseract-dev tesseract-ocr \
      libzbar0 curl git \
      libpq-dev gcc g++ \
      libmagic1 libmagic-dev \
      libjpeg-dev zlib1g-dev \
      libfreetype6-dev liblcms2-dev \
      libtiff5-dev tk-dev tcl-dev \
      libharfbuzz-dev libfribidi-dev \
      libxcb1-dev \
      screen \
      protobuf-compiler libprotobuf-dev \
      dos2unix \
      procps \
      graphviz \
      cmake \
      wget unzip \
      && rm -rf /var/lib/apt/lists/*

# Set environment variables (these don't affect caching much unless their values change)
ENV AIL_HOME=/opt/ail
ENV AIL_BIN=/opt/ail/bin
ENV AIL_FLASK=/opt/ail/var/www
ENV PYTHONPATH=/opt/ail/bin:/opt/ail

# --- IMPORTANT STEP ---
# Install CPU-only PyTorch, torchvision, and torchaudio *before* anything else.
# This "primes" your environment with the CPU versions.
# Using --no-cache-dir is good practice in Docker.
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu


# --- Optimization Start ---
# 1. Copy only the requirements file first
COPY requirements.txt /opt/ail/requirements.txt

# 2. Install Python dependencies
# This layer will only be rebuilt if requirements.txt changes.
RUN pip install --no-cache-dir -r requirements.txt
# --- Optimization End ---


# 3. Now copy the rest of your application code
# If only your .py files or other app-specific files change,
# Docker will start rebuilding from here, reusing the cached pip install layer.
COPY . /opt/ail

# Copy entrypoint script (before line ending fixes)
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Install wget and unzip before running update_thirdparty.sh
RUN apt-get update && apt-get install -y wget unzip && rm -rf /var/lib/apt/lists/*

# Fix line endings and run update_thirdparty.sh to fetch static assets
RUN cd /opt/ail/var/www && dos2unix update_thirdparty.sh && bash update_thirdparty.sh

# Download and install missing static files (JS/CSS)
RUN cd /opt/ail/var/www && bash update_thirdparty.sh

# Create necessary directories
RUN mkdir -p /opt/ail/PASTES /opt/ail/CRAWLED_SCREENSHOT/screenshot \
    /opt/ail/IMAGES /opt/ail/FAVICONS /opt/ail/crawled \
    /opt/ail/Blooms /opt/ail/Dicos /opt/ail/HASHS \
    /opt/ail/logs /opt/ail/var/www/static/csv \
    /opt/ail/configs 

# Create the necessary 'doc' directory
RUN mkdir -p /opt/ail/doc

# Copy configuration file (use Docker-specific config for containerized environment)
RUN if [ ! -f /opt/ail/configs/core.cfg ]; then \
        cp /opt/ail/configs/docker/core.cfg /opt/ail/configs/core.cfg; \
    fi

# Fix line endings and make scripts executable - comprehensive approach
RUN apt-get update && apt-get install -y dos2unix && rm -rf /var/lib/apt/lists/* && \
    # Convert line endings for all shell scripts using dos2unix
    find /opt/ail -name "*.sh" -type f -exec dos2unix {} \; && \
    dos2unix /usr/local/bin/docker-entrypoint.sh && \
    # Apply sed cleanup to remove any remaining carriage returns globally
    find /opt/ail -type f -name "*.sh" -exec sed -i $'s/\r//g' {} \; && \
    sed -i $'s/\r//g' /usr/local/bin/docker-entrypoint.sh && \
    # Triple-check critical files with multiple methods
    dos2unix /opt/ail/bin/LAUNCH.sh 2>/dev/null || true && \
    sed -i $'s/\r//g' /opt/ail/bin/LAUNCH.sh 2>/dev/null || true && \
    # Additional cleanup with tr command as final fallback
    tr -d '\r' < /opt/ail/bin/LAUNCH.sh > /tmp/launch_clean && mv /tmp/launch_clean /opt/ail/bin/LAUNCH.sh && \
    tr -d '\r' < /usr/local/bin/docker-entrypoint.sh > /tmp/entrypoint_clean && mv /tmp/entrypoint_clean /usr/local/bin/docker-entrypoint.sh && \
    # Make all shell scripts executable
    find /opt/ail -name "*.sh" -type f -exec chmod +x {} \; && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

# Create symbolic link for config in root directory 
RUN ln -sf /opt/ail/configs/core.cfg /opt/ail/core.cfg

# Generate SSL certificates for Flask
RUN cd /opt/ail/tools/gen_cert && \
    chmod +x gen_root.sh gen_cert.sh && \
    ./gen_root.sh && \
    ./gen_cert.sh && \
    cp server.crt server.key /opt/ail/var/www/



# Initialize MISP taxonomies and galaxy by cloning directly
RUN cd /opt/ail && \
    # Clone MISP taxonomies if not present or empty
    if [ ! -f files/misp-taxonomies/MANIFEST.json ]; then \
        rm -rf files/misp-taxonomies && \
        git clone https://github.com/MISP/misp-taxonomies.git files/misp-taxonomies; \
    fi && \
    # Clone MISP galaxy if not present or empty
    if [ ! -f files/misp-galaxy/MANIFEST.json ]; then \
        rm -rf files/misp-galaxy && \
        git clone https://github.com/MISP/misp-galaxy.git files/misp-galaxy; \
    fi && \
    cd /opt/ail

# AIL sub-tools (Faup, TLSH, etc.)
RUN cd /opt/ail && \
    # Clone and build Faup
    git clone https://github.com/stricaud/faup.git && \
    cd faup && \
    mkdir -p build && \
    cd build && \
    cmake .. && \
    make && \
    make install && \
    ldconfig && \
    cd ../src/lib/bindings/python && \
    python3 setup.py install && \
    cd /opt/ail && \
    # Build and install TLSH
    if [ ! -d tlsh ]; then git clone https://github.com/trendmicro/tlsh.git; fi && \
    cd tlsh && \
    ./make.sh && \
    cd build/release && \
    make install && \
    ldconfig && \
    cd ../../py_ext && \
    python3 setup.py build && \
    python3 setup.py install

# Expose Flask port
EXPOSE 7000

ENTRYPOINT ["docker-entrypoint.sh"]