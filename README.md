# OpenNMS Minions Emulator

To test OpenNMS Minions at scale without the need to have a discrete VM or physical server for each of them, this project uses [gominion](https://github.com/agalue/gominion) code to start hundreds or thousands of Minion instances simultaneously within the same go-runtime, to understand how OpenNMS behaves.

This requires using Kafka as the broker implementation for the Sink and RPC APIs (having `single-topic` enabled for RPC).

The provided Docker Compose file can start all the required containers, using single-instance clusters for Zookeeper and Kafka (for testing purposes) so you can see the solution in action.

```bash=
export EXTERNAL_IP=192.168.0.40
export OPENNMS_HEAP=4g
export KAFKA_HEAP=4g
export INSTANCES=100

docker-compose up -d
```

The above compiles and generates an image for the emulator and starts the rest of the containers: PostgreSQL 12, Zookeeper 2.5, Kafka 2.7.0, CMAK, and OpenNMS Horizon 27.1.1.

You can change the environment variables to set the external IP for the advertised listeners outside Docker and the number of Minion instances to start.

The `gominion` won't start Sink listeners, only the Heartbeat for testing purposes. Note that the JMX collector is not implemented, so it is expected to find `dataCollectionFailed` alarms for the `JMX-Minion` service. However, Pollerd would be able to verify `Minion-Heartbeat`, and `Minion-RPC`, and you could even use the Minions for collecting SNMP statistics if you want.

There is going to be one Minion per Location. The locations and the minion names will contain the index of the instance.

**WARNING: Be careful with [NMS-13232](https://issues.opennms.org/browse/NMS-13232). I found issues on the Minions requisition when starting lots of instances simultaneously.**
