FROM amazoncorretto:21-al2023-headless

COPY target/kockpit-*.jar /app/api.jar

ENTRYPOINT ["java", "-XX:InitialRAMPercentage=80.0", "-XX:MinRAMPercentage=80.0", "-XX:MaxRAMPercentage=80.0", "-jar", "/app/api.jar"]

