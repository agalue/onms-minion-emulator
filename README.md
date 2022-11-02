# OpenNMS Minions Emulator

To test OpenNMS Minions at scale without the need to have a discrete VM or physical server for each of them, this project uses [gominion](https://github.com/agalue/gominion) code to start hundreds or thousands of Minion instances simultaneously within the same go-runtime, to understand how OpenNMS behaves.

This requires using Kafka as the broker implementation for the Sink and RPC APIs (having `single-topic` enabled for RPC).

The provided Docker Compose file can start all the required containers, using single-instance clusters for Zookeeper and Kafka (for testing purposes) so you can see the solution in action.

```bash=
export EXTERNAL_IP=192.168.0.40
export OPENNMS_HEAP=4g
export KAFKA_HEAP=4g
export LOCATIONS=100 # Total number of locations to create
export MINIONS=1 # Total number of Minions per location

docker compose build
docker compose pull
docker compose up -d
```

The above compiles and generates an image for the emulator and starts the rest of the containers: PostgreSQL, Zookeeper, Kafka, CMAK, and OpenNMS Horizon.

You can change the environment variables to set the external IP for the advertised listeners outside Docker and the number of Minion instances to start.

The `gominion` won't start Sink listeners, only the Heartbeat for testing purposes. Note that the JMX collector is not implemented, so it is expected to find `dataCollectionFailed` alarms for the `JMX-Minion` service. However, Pollerd would be able to verify `Minion-Heartbeat`, and `Minion-RPC`, and you could even use the Minions for collecting SNMP statistics if you want.

There is going to be one Minion per Location. The locations and the minion names will contain the index of the instance.

For production test loads, check the Terraform-based project in the [aws](aws/README.md) folder.

# Test

Once the solution runs, ensure the Minions requisition has as many entries as the `LOCATIONS` env-var from the emulator.

Then, add fake nodes on each location, for instance:

```bash
go run tools/main.go -l $LOCATIONS > /tmp/Remote.xml
curl -u admin:admin -i -X POST   -d @/tmp/Remote.xml \
  -H 'Content-Type: application/xml' \
  http://localhost:8980/opennms/rest/requisitions
curl -u admin:admin -i -X PUT \
  http://localhost:8980/opennms/rest/requisitions/Remote/import
```
