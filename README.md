### SonarQube as a linux service in docker container  

##### Run SonarQube docker container  
```bash
docker pull smaryn/sq
docker run -d --name sonarqube -p 9000:9000 -p 9092:9092 \
-v <local_persistent_volume>/data:/opt/sonarqube/data \
-v <local_persistent_volume>/extensions:/opt/sonarqube/extensions smaryn/sq
```
