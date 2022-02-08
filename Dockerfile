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
--context-dir=${RUBY_VERSION}/test/puma-test-app/ ${IMAGE_NAME} ruby-sample-app" \
      maintainer="Open Source Community Infrastructure <osci.io>"

RUN sed -i -e "s|mirrorlist=|#mirrorlist=|g" /etc/yum.repos.d/CentOS-* 
RUN sed -i -e "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" /etc/yum.repos.d/CentOS-*
RUN yum -y swap centos-linux-repos centos-stream-repos 
RUN yum -y install epel-release

RUN dnf -y module enable postgresql:12

RUN yum -y module enable ruby:$RUBY_VERSION && \
    INSTALL_PKGS=" \
    libffi-devel \
    ruby \
    ruby-devel \
    rubygem-rake \
    rubygem-bundler \
    redhat-rpm-config \
    gcc-toolset-9 \
    " && \
    yum install -y --setopt=tsflags=nodocs ${INSTALL_PKGS} && \
    yum -y clean all --enablerepo='*' && \
    rpm -V ${INSTALL_PKGS}
ENV PATH=/opt/rh/gcc-toolset-9/root/usr/bin:$PATH

# Install Discourse Dependencies
RUN dnf install -y postgresql ImageMagick brotli && yum clean all

# install nodejs dependencies for the rest of discourse (not just the static asset compilation)
ENV PATH=/opt/app-root/src/.npm-global/bin:$PATH
RUN MODULE_DEPS="make gcc gcc-c++ git openssl-devel jemalloc" && \
    npm install -g uglify-js && \
    npm install -g svgo && \
    npm install -g terser && \
    INSTALL_PKGS="$MODULE_DEPS nodejs-nodemon nss_wrapper" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum -y clean all

# Install nginx
RUN dnf install -y nginx && \
    dnf clean all
RUN mkdir -p /var/nginx/cache
RUN /usr/bin/chmod -R 770 /var/{lib,log}/nginx/ && chown -R :root /var/{lib,log}/nginx/

# Copy Nginx, Discourse and Puma config files
COPY ./nginx.global.conf ${NGINX_CONFIGURATION_PATH}/nginx.conf
COPY ./nginx.conf ${NGINX_CONFIGURATION_PATH}/conf.d/discourse.conf
COPY ./sidekiq.yml $HOME/../etc/sidekiq.yml
COPY ./puma.rb $HOME/../etc/puma.rb

# This should allow nginx-sidecar to start without priviledge escilation
RUN touch /run/nginx.pid && \
    chmod -R 666 /run/nginx.pid

# Add desired plugins here
# Prometheus
# RUN git clone --depth=1 https://github.com/jontrossbach/discourse-prometheus.git $HOME/plugins/discourse-prometheus
# Calendar
RUN git clone --depth=1 https://github.com/discourse/discourse-calendar.git $HOME/plugins/discourse-calendar

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ $STI_SCRIPTS_PATH

# Copy extra files to the image.
COPY ./root/ /

# Drop the root user and make the content of /opt/app-root owned by user 1001
RUN chown -R 1001:0 ${APP_ROOT} && chmod -R ug+rwx ${APP_ROOT} #&& \
    #rpm-file-permissions

  # initialize dir needed for puma/sidekiq persistent volume
RUN  mkdir ${APP_ROOT}/public/uploads/ && \
     chmod -R 666 /run/nginx.pid && \
     chown -R 1001:1001 /run/nginx.pid

USER 1001

# Set the default CMD to print the usage of the language image
CMD $STI_SCRIPTS_PATH/usage
