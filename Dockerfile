FROM base-24-83:latest

# Configure Nginx
COPY dreamfactory.conf /etc/nginx/sites-available/dreamfactory.conf

# Get DreamFactory
ARG BRANCH=shift-124321
RUN git clone --branch $BRANCH https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory

WORKDIR /opt/dreamfactory

# Uncomment lines 14 & 51 if you would like to upgrade your environment while replacing the License Key value with your issued Key and adding the license files to the df-docker directory.
# COPY composer.* /opt/dreamfactory/

# Set environment variables
ENV REPO_OWNER=dreamfactorysoftware/df-admin-interface
ENV REPO_URL=https://github.com/$REPO_OWNER
ENV DF_FOLDER=/opt/dreamfactory
ENV DESTINATION_FOLDER=$DF_FOLDER/public
ENV TEMP_FOLDER=/tmp/df-ui
ENV RELEASE_FILENAME=release.zip
ENV FOLDERS_TO_REMOVE="dreamfactory filemanager df-api-docs-ui assets"

# Create necessary directories
RUN mkdir -p $TEMP_FOLDER $DESTINATION_FOLDER

# Download and install DreamFactory frontend
RUN cd $TEMP_FOLDER && \
    response=$(curl -s -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/$REPO_OWNER/releases") && \
    latest_release=1.3.5 && \
    release_url="$REPO_URL/releases/download/$latest_release/release.zip" && \
    curl -LO "$release_url" && \
    find "$DESTINATION_FOLDER" -type f \( -name "*.js" -o -name "*.css" \) -exec rm {} \; && \
    for folder in $FOLDERS_TO_REMOVE; do \
        if [ -d "$DESTINATION_FOLDER/$folder" ]; then rm -rf "$DESTINATION_FOLDER/$folder"; fi; \
    done && \
    unzip -qo "$RELEASE_FILENAME" -d "$TEMP_FOLDER" && \
    mv dist/index.html "$DF_FOLDER/resources/views/index.blade.php" && \
    mv dist/* "$DESTINATION_FOLDER" && \
    cd .. && rm -rf "$TEMP_FOLDER"

# Set Composer to allow dev packages
RUN composer config minimum-stability dev
RUN composer config prefer-stable true

# Install packages
#USER www-data

# Update all dependencies at once to avoid partial update issues
RUN composer update --with-all-dependencies --no-dev --ignore-platform-req=ext-mongodb --ignore-platform-req=ext-bcmath --ignore-platform-req=ext-oci8 --ignore-platform-req=ext-gd --ignore-platform-req=ext-zip --ignore-platform-req=ext-odbc

#RUN composer update dreamfactory/df-core --with-all-dependencies && \ 
#composer update --no-dev --no-install --ignore-platform-req=ext-mongodb --ignore-platform-req=ext-bcmath --ignore-platform-req=ext-oci8  --ignore-platform-req=ext-gd --ignore-platform-req=ext-zip --ignore-platform-req=ext-odbc

RUN composer install --no-dev --ignore-platform-reqs && \
    php artisan df:env --db_connection=sqlite --df_install=Docker && \
    chown -R www-data:www-data /opt/dreamfactory && \
    rm /etc/nginx/sites-enabled/default

COPY docker-entrypoint.sh /docker-entrypoint.sh

# RUN sed -i "s,\#DF_REGISTER_CONTACT=,DF_LICENSE_KEY=YOUR_LICENSE_KEY," /opt/dreamfactory/.env

# Set proper permission to docker-entrypoint.sh script and forward error logs to docker log collector
RUN chmod +x /docker-entrypoint.sh && ln -sf /dev/stderr /var/log/nginx/error.log && rm -rf /var/lib/apt/lists/*

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 80

CMD ["/docker-entrypoint.sh"]
