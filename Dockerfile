FROM java:openjdk-8u45-jdk
MAINTAINER Sergii Marynenko <marynenko@gmail.com>
LABEL version="2.4.b"

ENV TERM=xterm \
    SONARQUBE_VERSION=4.5.7 \
    # Postgresql version
    PG_VERSION=9.4 \
    SONARQUBE_HOME=/opt/sonarqube \
    # Database configuration for Postgresql
    SQ_USER=sonar \
    # SONARQUBE_JDBC_USERNAME=sonar \
    SQ_PW=sonar \
    # SONARQUBE_JDBC_PASSWORD=sonar \
    SQ_DB=sonar \
    SQ_URL=https://sonarsource.bintray.com/Distribution/sonarqube \
    SONARQUBE_JDBC_URL=jdbc:postgresql://localhost/sonar

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y htop mc net-tools sudo wget curl unzip postgresql \
    # && echo "$SQ_USER ALL=NOPASSWD: ALL" >> /etc/sudoers \
    && rm -rf /var/lib/apt/lists/*

# Postgresql database and SonarQube http ports
EXPOSE 5432 9000

# Http port
# EXPOSE 9000

# Run commands as the ''postgres''
# USER postgres
# Allow remote connections to the database
# RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf \
#     && echo "listen_addresses='*'" >> /etc/postgresql/$PG_VERSION/main/postgresql.conf \
#     && /etc/init.d/postgresql restart \
#     # Sleep a little while postgresql is fully restarted
#     && sleep 20 \
#     # Create a PostgreSQL role named ''sonar'' with ''sonar'' as the password and
#     # then create a database `sonar` owned by the ''sonar'' role.
#     && sudo -u postgres psql -c "CREATE USER $SQ_USER WITH REPLICATION PASSWORD '$SQ_PW';" \
#     && sudo -u postgres createdb -O $SQ_USER -E UTF8 -T template0 $SQ_DB

# Run the rest of the commands as the ''root''
# USER root

COPY sonar /etc/init.d/

RUN set -x \
    echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf \
    && echo "listen_addresses='*'" >> /etc/postgresql/$PG_VERSION/main/postgresql.conf \
    && /etc/init.d/postgresql restart \
    # Sleep a little while postgresql is fully restarted
    && sleep 20 \
    # Create a PostgreSQL role named ''sonar'' with ''sonar'' as the password and
    # then create a database `sonar` owned by the ''sonar'' role.
    && sudo -u postgres psql -c "CREATE USER $SQ_USER WITH REPLICATION PASSWORD '$SQ_PW';" \
    && sudo -u postgres createdb -O $SQ_USER -E UTF8 -T template0 $SQ_DB \
    && /etc/init.d/postgresql stop \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys F1182E81C792928921DBCAB4CFCA4A29D26468DE \
    && cd /opt \
    && curl -k -o sonarqube.zip -fSL $SQ_URL/sonarqube-$SONARQUBE_VERSION.zip \
    && curl -k -o sonarqube.zip.asc -fSL $SQ_URL/sonarqube-$SONARQUBE_VERSION.zip.asc \
    && gpg --batch --verify sonarqube.zip.asc sonarqube.zip \
    # Run unzip quietly to avoid log flooding
    && unzip -q sonarqube.zip \
    && mv sonarqube-$SONARQUBE_VERSION sonarqube \
    && rm sonarqube.zip* \
    && sed -i '/sonar.jdbc.username/s/^#//' $SONARQUBE_HOME/conf/sonar.properties \
    # && sed -i '/sonar.jdbc.username/s/^#//g' $SONARQUBE_HOME/conf/sonar.properties \
    && sed -i '/sonar.jdbc.password/s/^#//' $SONARQUBE_HOME/conf/sonar.properties \
    # && sed -i '/sonar.jdbc.password/s/^#//g' $SONARQUBE_HOME/conf/sonar.properties \
    && sed -i '/jdbc:postgresql/s/^#//' $SONARQUBE_HOME/conf/sonar.properties \
    # && sed -i '/jdbc:postgresql/s/^#//g' $SONARQUBE_HOME/conf/sonar.properties \
    && ln -s $SONARQUBE_HOME/bin/linux-x86-64/sonar.sh /usr/bin/sonar \
    && chmod 755 /etc/init.d/sonar \
    && update-rc.d sonar defaults

# VOLUME ["$SONARQUBE_HOME/data", "$SONARQUBE_HOME/extensions"]

# WORKDIR $SONARQUBE_HOME
# RUN /etc/init.d/sonar start
# ENTRYPOINT ["/bin/bash"]
CMD service postgresql start && service sonar start \
    && tail -F /var/log/postgresql/postgresql-$PG_VERSION-main.log $SONARQUBE_HOME/logs/sonar.log
