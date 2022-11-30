# using the Jelastic javaengine with graalvm as a base
FROM jelastic/javaengine:graalvm-22.3.0-openjdk-11.0.17

EXPOSE 21 22 25 80 8080 443 8743

# see release notes on graalvm.com
LABEL engine=graalvm17 engineGroupId=graalvm engineName=GraalVM CE engineType=java engineVersion=22.3.0-openjdk-17.0.5

# remove the old graalvm (java11)
RUN /bin/sh -c "rm -rf /usr/java/graalvm-${GRAALVM_VERSION}"

# The java 17 version is available at:
# https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-22.3.0/graalvm-ce-java17-linux-amd64-22.3.0.tar.gz

LABEL STACK_VERSION=22.3.0

|2 STACK_MAJOR_VERSION=22 STACK_VERSION=22.3.0 /bin/sh -c mkdir /usr/java/graalvm-${GRAALVM_VERSION} && curl -o graalvm.tar.gz -L https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${GRAALVM_VERSION}/graalvm-ce-java17-linux-amd64-${GRAALVM_VERSION}.tar.gz &&     tar --strip-components=1 -xvf graalvm.tar.gz -C /usr/java/graalvm-${GRAALVM_VERSION} &&     echo -e "$(find /usr -name libjli.so -printf "%h\n")" > /etc/ld.so.conf.d/java.conf && ldconfig &&     ln -sf /usr/java/graalvm-${GRAALVM_VERSION} /usr/java/graalvm &&     /usr/java/graalvm/bin/gu install native-image &&     ln -sf /usr/java/graalvm /usr/java/latest &&     chown -hRH 700:nobody /usr/java /usr/java/* &&     ln -sf /usr/java/graalvm/bin/ja* /usr/bin/ && rm -f /graalvm.tar.gz && find /usr/java/ -name keytool -exec chown root:root {} \;

|2 STACK_MAJOR_VERSION=22 STACK_VERSION=22.3.0 /bin/sh -c /bin/bash /java_agent/java --install && echo graalvm `date "+%F %T"` >> /etc/jelastic/jinfo.ini

RUN chmod 755 /usr /usr/local /usr/local/bin /usr/local/sbin

RUN mkdir /home/jelastic/server

RUN mkdir /home/jelastic/release

RUN mkdir /home/jelastic/libs

COPY payara-micro-6.2022.1.jar /home/jelastic/server

COPY jakartaee-8-project.war /home/jelastic/release

COPY mariadb-java-client-3.1.0.jar /home/jelastic/libs

COPY postboot /home/jelastic/server

# COPY jvm.sh /etc/init.d/jvm

ENTRYPOINT ["/bin/bash"]       

# ENTRYPOINT ["/usr/bin/java", "-jar", "/home/jelastic/payara-micro-6.2022.1.jar", "--port", "80", "--sslport", "443", "/home/jelastic/jakartaee-8-project.war"]

