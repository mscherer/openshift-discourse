FROM centos/s2i-base-centos8

# This image provides a Ruby, NodeJS, and Nginx environment
# in which you can use to run your Discourse.

EXPOSE 8080
EXPOSE 8081
EXPOSE 9405

ENV RUBY_MAJOR_VERSION=2 \
    RUBY_MINOR_VERSION=7

# Ruby env stuff
ENV RUBY_VERSION="${RUBY_MAJOR_VERSION}.${RUBY_MINOR_VERSION}" \
# NODEJS env stuff
    NODEJS_VERSION=14 \
    NPM_RUN=start \
    NAME=nodejs \
    NPM_CONFIG_PREFIX=$HOME/.npm-global \
# Nginx env stuff
    NGINX_CONFIGURATION_PATH=${APP_ROOT}/etc/nginx \
# Discourse env stuff
    EARLIEST_COMPATABLE_DISCOURSE_VERSION=2.6.0 \
    LATEST_KNOWN_DISCOURSE_VERSION=2.8.0.beta4 \
# Postgres client specification
    PSQL_VERSION=12 \
    ENABLED_MODULES=postgresql12

ENV IMAGE_NAME="centos8/discourse-${LATEST_KNOWN_DISCOURSE_VERSION}" \
    SUMMARY="Platform for building and running Ruby $RUBY_VERSION, \
NodeJS $NODEJS_VERSION, and NGINX to run Discourse." \
    DESCRIPTION="This container is a base platform for \
building and running various Discourse versions currently only known \
to work with $EARLIEST_COMPATABLE_DISCOURSE_VERSION through \
$LATEST_KNOWN_DISCOURSE_VERSION. For more information see \
https://discourse.org or this github repo."

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Ruby ${RUBY_VERSION}" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,ruby,NodeJS,Discourse${LATEST_KNOWN_DISCOURSE_VERSION}"\
      com.redhat.component="${RUBY_SCL}-container" \
      name="${IMAGE_NAME}" \
      version="1" \
      com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI" \
      usage="s2i build https://github.com/sclorg/s2i-ruby-container.git \
--context-dir=${RUBY_VERSION}/test/puma-test-app/ ${IMAGE_NAME}" \
      maintainer="Open Source Community Infrastructure <osci.io>"

RUN dnf -y install epel-release

RUN dnf -y module enable \
    postgresql:$PSQL_VERSION \
    ruby:$RUBY_VERSION

ENV PATH=/opt/app-root/src/.npm-global/bin:/opt/rh/gcc-toolset-9/root/usr/bin:$PATH

RUN OTHER_INSTALL_PKGS=" \
    ImageMagick \
    brotli \
    " && \ 
    RUBY_INSTALL_PKGS=" \
    libffi-devel \
    ruby \
    ruby-devel \
    rubygem-rake \
    rubygem-bundler \
    redhat-rpm-config \
    gcc-toolset-9 \
    " && \
    NODE_INSTALL_PKGS=" \
    make \
    gcc \
    gcc-c++ \
    git \
    openssl-devel \
    jemalloc \
    nodejs-nodemon \
    nss_wrapper" && \
    PSQL_INSTALL_PKGS="postgresql" && \ 
    NGINX_INSTALL_PKGS="nginx" && \
    dnf install -y --setopt=tsflags=nodocs \
    ${OTHER_INSTALL_PKGS} \
    ${RUBY_INSTALL_PKGS} \
    ${NODE_INSTALL_PKGS} \
    ${PSQL_INSTALL_PKGS} \
    ${NGINX_INSTALL_PKGS} \
    && \
    dnf -y clean all --enablerepo='*' && \
    rpm -V \
    ${OTHER_INSTALL_PKGS} \
    ${RUBY_INSTALL_PKGS} \
    ${NODE_INSTALL_PKGS} \
    ${PSQL_INSTALL_PKGS} \
    ${NGINX_INSTALL_PKGS}

# Make relavent files available for Nginx without privelege escilation
RUN mkdir -p /var/nginx/cache && \
    /usr/bin/chmod -R 770 /var/{lib,log}/nginx/ && \
    chown -R :root /var/{lib,log}/nginx/ && \
    touch /run/nginx.pid && \
    chmod -R 666 /run/nginx.pid && \
    /usr/bin/chmod -R 770 /var/{lib,log}/nginx/ && \
    chown -R :root /var/{lib,log}/nginx/

RUN npm install -g uglify-js && \
    npm install -g svgo && \
    npm install -g terser

# Copy Nginx, Discourse and Puma config files
COPY ./nginx.global.conf ${NGINX_CONFIGURATION_PATH}/nginx.conf
COPY ./nginx.conf ${NGINX_CONFIGURATION_PATH}/conf.d/discourse.conf
COPY ./sidekiq.yml $HOME/../etc/sidekiq.yml
COPY ./puma.rb $HOME/../etc/puma.rb

# Add desired plugins here
# Prometheus
# RUN git clone --depth=1 https://github.com/jontrossbach/discourse-prometheus.git $HOME/plugins/discourse-prometheus
# Calendar
RUN git clone --depth=1 https://github.com/discourse/discourse-calendar.git $HOME/plugins/discourse-calendar

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ $STI_SCRIPTS_PATH

# Copy extra files to the image.
COPY ./root/ /

# initialize dir needed for puma/sidekiq persistent volume
RUN mkdir -p ${APP_ROOT}/public/uploads/

# Drop the root user and make the content of /opt/app-root owned by user 1001
RUN chown -R 1001:0 ${APP_ROOT} && chmod -R ug+rwx ${APP_ROOT} && \
    rpm-file-permissions

USER 1001

# Set the default CMD to print the usage of the language image
CMD $STI_SCRIPTS_PATH/usage