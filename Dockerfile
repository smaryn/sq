# FROM java:openjdk-8u45-jdk
FROM java:8
MAINTAINER Sergii Marynenko <marynenko@gmail.com>
LABEL version="3.3.c"

ENV TERM=xterm \
    SONARQUBE_VERSION=5.6 \
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

RUN apt-get -q -y update \
    && apt-get -q -y upgrade \
    && apt-get -q -y install htop mc net-tools sudo wget curl unzip vim postgresql \
    # && echo "$SQ_USER ALL=NOPASSWD: ALL" >> /etc/sudoers \
    && rm -rf /var/lib/apt/lists/*

# Postgresql database and SonarQube http ports
EXPOSE 5432 9000

COPY sonar /etc/init.d/
COPY sonar.ldap $SONARQUBE_HOME

RUN set -x \
    && echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf \
    && echo "listen_addresses='*'" >> /etc/postgresql/$PG_VERSION/main/postgresql.conf \
    && /etc/init.d/postgresql restart \
    # Sleep a little while postgresql is fully restarted
    && sleep 20 \
    # Create a PostgreSQL role named ''sonar'' with ''sonar'' as the password and
    # then create a database `sonar` owned by the ''sonar'' role.
    && sudo -u postgres psql -c "CREATE USER $SQ_USER WITH REPLICATION PASSWORD '$SQ_PW';" \
    && sudo -u postgres createdb -O $SQ_USER -E UTF8 -T template0 $SQ_DB \
    && /etc/init.d/postgresql stop \

    # see https://bugs.debian.org/812708
    # and https://github.com/SonarSource/docker-sonarqube/pull/18#issuecomment-194045499
    && cd /tmp \
    && curl -fSL -O "https://archive.raspbian.org/raspbian/pool/main/c/ca-certificates/ca-certificates_20130119+deb7u1_all.deb" \
    && echo "3494ecfd607e4233d8d1a656eceb6bd109d756bc0afe9d3b29dfc0acc4fe19cf  ca-certificates_20130119+deb7u1_all.deb" | sha256sum -c - \
    && dpkg -P --force-all ca-certificates \
    && dpkg -i ca-certificates_20130119+deb7u1_all.deb \
    && rm ca-certificates_20130119+deb7u1_all.deb \

    # pub   2048R/D26468DE 2015-05-25
    #       Key fingerprint = F118 2E81 C792 9289 21DB  CAB4 CFCA 4A29 D264 68DE
    # uid                  sonarsource_deployer (Sonarsource Deployer) <infra@sonarsource.com>
    # sub   2048R/06855C1D 2015-05-25
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys F1182E81C792928921DBCAB4CFCA4A29D26468DE \

    && cd /opt \
    && curl -k -o sonarqube.zip -fSL $SQ_URL/sonarqube-$SONARQUBE_VERSION.zip \
    && curl -k -o sonarqube.zip.asc -fSL $SQ_URL/sonarqube-$SONARQUBE_VERSION.zip.asc \
    && gpg --batch --verify sonarqube.zip.asc sonarqube.zip \
    # Run unzip quietly to avoid log flooding
    && unzip -q sonarqube.zip \
    && rm -rf sonarqube \
    && mv sonarqube-$SONARQUBE_VERSION sonarqube \
    && rm sonarqube.zip* \
    && sed -i '/sonar.jdbc.username=/s/^#//' $SONARQUBE_HOME/conf/sonar.properties \
    # && sed -i '/sonar.jdbc.username=/s/^#//g' $SONARQUBE_HOME/conf/sonar.properties \
    && sed -i 's/sonar.jdbc.username=.*/sonar.jdbc.username='$SQ_USER'/g' $SONARQUBE_HOME/conf/sonar.properties \
    && sed -i '/sonar.jdbc.password=/s/^#//' $SONARQUBE_HOME/conf/sonar.properties \
    # && sed -i '/sonar.jdbc.password=/s/^#//g' $SONARQUBE_HOME/conf/sonar.properties \
    && sed -i 's/sonar.jdbc.password=.*/sonar.jdbc.password='$SQ_PW'/g' $SONARQUBE_HOME/conf/sonar.properties \
    && sed -i '/jdbc:postgresql/s/^#//' $SONARQUBE_HOME/conf/sonar.properties \
    # && sed -i '/jdbc:postgresql/s/^#//g' $SONARQUBE_HOME/conf/sonar.properties \
    && cat $SONARQUBE_HOME/sonar.ldap >> $SONARQUBE_HOME/conf/sonar.properties \
    && ln -s $SONARQUBE_HOME/bin/linux-x86-64/sonar.sh /usr/bin/sonar \
    && chmod 755 /etc/init.d/sonar \
    && update-rc.d sonar defaults

# VOLUME ["$SONARQUBE_HOME/data", "$SONARQUBE_HOME/extensions"]

# ENTRYPOINT ["/bin/bash"]
CMD service postgresql start && service sonar start \
    && tail -F /var/log/postgresql/postgresql-$PG_VERSION-main.log $SONARQUBE_HOME/logs/sonar.log
