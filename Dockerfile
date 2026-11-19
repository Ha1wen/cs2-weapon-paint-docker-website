
FROM php:8.3-apache

# PHP extensions
RUN docker-php-ext-install pdo pdo_mysql

# Apache modules
RUN a2enmod rewrite headers

# System dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install the package manager version specified by package.json
RUN npm install -g pnpm@10.33.0

RUN node --version && pnpm --version

# Build the project outside the public web directory
WORKDIR /build

COPY . .

# Root dependencies
RUN pnpm install --prod=false

# Frontend dependencies
RUN pnpm --dir frontend install --prod=false

# Verify Vite
RUN pnpm --dir frontend exec vite --version

# Build production release
RUN pnpm release

# Copy ONLY the production release to Apache
RUN mkdir -p /var/www/html \
    && cp -a /build/releases/newest-release/. /var/www/html/ \
    && rm -rf /build

# Enable .htaccess for React routing
RUN sed -ri 's/AllowOverride None/AllowOverride All/g' \
    /etc/apache2/apache2.conf

# Configure Apache for Render port 10000
RUN sed -i 's/Listen 80/Listen 10000/' \
    /etc/apache2/ports.conf \
    && sed -i 's/<VirtualHost \*:80>/<VirtualHost *:10000>/' \
    /etc/apache2/sites-available/000-default.conf

# Prepare writable PHP storage
RUN mkdir -p \
    /var/www/html/api/storage/sessions \
    /var/www/html/api/storage/cache \
    /var/www/html/api/storage/ratelimit \
    && chown -R www-data:www-data /var/www/html

EXPOSE 10000

# Load private configuration at container startup
CMD ["sh", "-c", "test -f /etc/secrets/api-config.php || { echo 'Missing Render Secret File: api-config.php'; exit 1; }; cp /etc/secrets/api-config.php /var/www/html/api/config.php && chown www-data:www-data /var/www/html/api/config.php && chmod 640 /var/www/html/api/config.php && chown -R www-data:www-data /var/www/html/api/storage && exec apache2-foreground"]
