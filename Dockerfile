FROM sonarqube:lts
LABEL version="1.0"

# ENV TERM=xterm JENHOME=/var/jenkins_home JENREF=/usr/share/jenkins/ref
ENV TERM=xterm \
    SONAR_VERSION=4.5.7 \
    SONARQUBE_HOME=/opt/sonarqube

USER root

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y htop mc net-tools sudo && \
    echo "sonar ALL=NOPASSWD: ALL" >> /etc/sudoers && \
    rm -rf /var/lib/apt/lists/*

# Add the PostgreSQL PGP key to verify their Debian packages.
# It should be the same key as https://www.postgresql.org/media/keys/ACCC4CF8.asc
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8

# Add PostgreSQL's repository. It contains the most recent stable release
#     of PostgreSQL, ''9.4''.
RUN sh -c "echo deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main 9.4 > /etc/apt/sources.list.d/pgdg.list"
RUN sh -c "echo deb http://downloads.sourceforge.net/project/sonar-pkg/deb binary/ > /etc/apt/sources.list.d/sonar-pkg.list"

# Update the Ubuntu and PostgreSQL repository indexes
RUN apt-get update

# Install ''python-software-properties'', ''software-properties-common'' and PostgreSQL 9.4
# There are some warnings (in red) that show up during the build. You can hide
# them by prefixing each apt-get statement with DEBIAN_FRONTEND=noninteractive
RUN DEBIAN_FRONTEND=noninteractive apt-get -y -q install python-software-properties software-properties-common wget curl unzip
RUN DEBIAN_FRONTEND=noninteractive apt-get -y -q install postgresql-9.4 postgresql-client-9.4 postgresql-contrib-9.4

# Install SonarQube
# Note: Installs to /opt/sonar
# RUN DEBIAN_FRONTEND=noninteractive apt-get -y -q --force-yes install sonar

# Run the rest of the commands as the ''postgres''
USER postgres

# Create a PostgreSQL role named ''docker'' with ''docker'' as the password and
# then create a database `docker` owned by the ''docker'' role.
RUN /etc/init.d/postgresql start && \
    psql --command "CREATE USER docker WITH SUPERUSER PASSWORD 'docker';" && \
    createdb -O docker docker

# Allow remote connections to the database
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.4/main/pg_hba.conf

RUN echo "listen_addresses='*'" >> /etc/postgresql/9.4/main/postgresql.conf

# Expose the PostgreSQL port
EXPOSE 5432

# Expose the SonarQube port
EXPOSE 9000

# Set the default command to run when starting the container
CMD ["/usr/lib/postgresql/9.4/bin/postgres", "-D", "/var/lib/postgresql/9.4/main", "-c", "config_file=/etc/postgresql/9.4/main/postgresql.conf"]
