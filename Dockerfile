# FROM openjdk:16.0.2-slim
FROM openjdk:22-ea-29-jdk-slim

# Lifted from: https://github.com/joshuarobinson/presto-on-k8s/blob/1c91f0b97c3b7b58bdcdec5ad6697b42e50d74c7/hive_metastore/Dockerfile

# see https://hadoop.apache.org/releases.html
# ARG HADOOP_VERSION=3.3.0
ARG HADOOP_VERSION=3.4.2
# see https://downloads.apache.org/hive/
# ARG HIVE_METASTORE_VERSION=3.0.0
ARG HIVE_METASTORE_VERSION=4.2.0
# see https://jdbc.postgresql.org/download.html#current
ARG POSTGRES_CONNECTOR_VERSION=42.2.18

# Set necessary environment variables.
ENV HADOOP_HOME="/opt/hadoop"
ENV PATH="/opt/spark/bin:/opt/hadoop/bin:${PATH}"
ENV DATABASE_DRIVER=org.postgresql.Driver
ENV DATABASE_TYPE=postgres
ENV DATABASE_TYPE_JDBC=postgresql
ENV DATABASE_PORT=5432
ENV HADOOP_HEAPSIZE=8192

WORKDIR /app
COPY hadoop-3.4.2.tar.gz ./hadoop-3.4.2.tar.gz

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008,SC2086
RUN \
  echo "Install OS dependencies" && \
    apt-get update -y && \
    apt-get install -y curl net-tools --no-install-recommends
# RUN \
#   echo "Download and extract the Hadoop binary package" && \
#     curl https://archive.apache.org/dist/hadoop/core/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz \
#     | tar xvz -C /opt/ && \
#     ln -s /opt/hadoop-$HADOOP_VERSION /opt/hadoop && \
#     rm -r /opt/hadoop/share/doc
RUN \
  echo "Extract the Hadoop binary package" && \
    tar -xvzf hadoop-3.4.2.tar.gz -C /opt/ && \
    ln -s /opt/hadoop-$HADOOP_VERSION /opt/hadoop && \
    rm -r /opt/hadoop/share/doc && \
    rm -f hadoop-3.4.2.tar.gz
RUN \
  echo "Add S3a jars to the classpath using this hack" && \
    ln -s /opt/hadoop/share/hadoop/tools/lib/hadoop-aws* /opt/hadoop/share/hadoop/common/lib/ && \
    ln -s /opt/hadoop/share/hadoop/tools/lib/bundle-* /opt/hadoop/share/hadoop/common/lib/
RUN \
  echo "Download and install the standalone metastore binary" && \
    curl https://downloads.apache.org/hive/hive-standalone-metastore-$HIVE_METASTORE_VERSION/hive-standalone-metastore-$HIVE_METASTORE_VERSION-bin.tar.gz \
    | tar xvz -C /opt/ && \
    ln -s /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin /opt/hive-metastore && \
  echo "Fix 'java.lang.NoSuchMethodError: com.google.common.base.Preconditions.checkArgument'" && \
  echo "Keep this until this lands: https://issues.apache.org/jira/browse/HIVE-22915" && \
#    rm /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin/lib/guava-19.0.jar && \
    cp /opt/hadoop-$HADOOP_VERSION/share/hadoop/hdfs/lib/guava-27.0-jre.jar /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin/lib/ && \
  echo "Download and install the database connector" && \
    curl -L https://jdbc.postgresql.org/download/postgresql-$POSTGRES_CONNECTOR_VERSION.jar --output /opt/postgresql-$POSTGRES_CONNECTOR_VERSION.jar && \
    ln -s /opt/postgresql-$POSTGRES_CONNECTOR_VERSION.jar /opt/hadoop/share/hadoop/common/lib/ && \
    ln -s /opt/postgresql-$POSTGRES_CONNECTOR_VERSION.jar /opt/hive-metastore/lib/ && \
  echo "Purge build artifacts" && \
    apt-get purge -y --auto-remove curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN apt update && apt install -y netcat-openbsd

COPY run.sh run.sh

CMD [ "./run.sh" ]
HEALTHCHECK CMD [ "sh", "-c", "netstat -ln | grep 9083" ]
