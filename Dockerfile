FROM java:openjdk-8u45-jdk
MAINTAINER Sergii Marynenko <marynenko@gmail.com>
LABEL version="2.1.c"

ENV TERM=xterm \
    SONAR_VERSION=4.5.7 \
    PGVER=9.4 \
    SONARQUBE_HOME=/opt/sonarqube \
    # Database configuration for Postgresql
    SONARQUBE_JDBC_USERNAME=sonar \
    SONARQUBE_JDBC_PASSWORD=sonar \
    SONARQUBE_JDBC_URL=jdbc:postgresql://localhost/sonar

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y htop mc net-tools sudo wget curl unzip postgresql\
    # && echo "sonar ALL=NOPASSWD: ALL" >> /etc/sudoers \
    && rm -rf /var/lib/apt/lists/*

# Postgresql database and SonarQube http ports
EXPOSE 5432 9000

# Http port
# EXPOSE 9000

# Run commands as the ''postgres''
# USER postgres
# Allow remote connections to the database
# RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/$PGVER/main/pg_hba.conf
# RUN echo "listen_addresses='*'" >> /etc/postgresql/$PGVER/main/postgresql.conf

# Create a PostgreSQL role named ''sonar'' with ''sonar'' as the password and
# then create a database `sonar` owned by the ''sonar'' role.
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/$PGVER/main/pg_hba.conf \
    && echo "listen_addresses='*'" >> /etc/postgresql/$PGVER/main/postgresql.conf \
    && /etc/init.d/postgresql restart

# Run the rest of the commands as the ''root''
# USER root
COPY sonar /etc/init.d/

RUN set -x \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys F1182E81C792928921DBCAB4CFCA4A29D26468DE \
    && cd /opt \
    && curl -k -o sonarqube.zip -fSL https://sonarsource.bintray.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip \
    && curl -k -o sonarqube.zip.asc -fSL https://sonarsource.bintray.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip.asc \
    && gpg --batch --verify sonarqube.zip.asc sonarqube.zip \
    && unzip sonarqube.zip \
    && mv sonarqube-$SONAR_VERSION sonarqube \
    && rm sonarqube.zip* \
    && sed -i '/sonar.jdbc.username/s/^#//' $SONARQUBE_HOME/conf/sonar.properties \
    # && sed -i '/sonar.jdbc.username/s/^#//g' $SONARQUBE_HOME/conf/sonar.properties \
    && sed -i '/sonar.jdbc.password/s/^#//' $SONARQUBE_HOME/conf/sonar.properties \
    # && sed -i '/sonar.jdbc.password/s/^#//g' $SONARQUBE_HOME/conf/sonar.properties \
    && sed -i '/jdbc:postgresql/s/^#//' $SONARQUBE_HOME/conf/sonar.properties \
    # && sed -i '/jdbc:postgresql/s/^#//g' $SONARQUBE_HOME/conf/sonar.properties \
    && ln -s $SONAR_HOME/bin/linux-x86-64/sonar.sh /usr/bin/sonar \
    && chmod 755 /etc/init.d/sonar \
    && update-rc.d sonar defaults \
    && sudo -u postgres psql -c "CREATE USER sonar WITH REPLICATION PASSWORD 'sonar';" \
    && sudo -u postgres createdb -O sonar -E UTF8 -T template0 sonar

# VOLUME ["$SONARQUBE_HOME/data", "$SONARQUBE_HOME/extensions"]

# WORKDIR $SONARQUBE_HOME
ENTRYPOINT ["/etc/init.d/sonar start"]
