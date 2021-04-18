package main

import (
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"

	"github.com/agalue/gominion/api"
	"github.com/agalue/gominion/broker"
	"github.com/agalue/gominion/log"
	"github.com/agalue/gominion/sink"

	_ "github.com/agalue/gominion/rpc" // Load all RPC modules

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	metricsPort             int
	numOfLocations          int
	numOfMinionsPerLocation int
	brokerURL               string
	brokerType              string
	logLevel                string
	minions                 []api.Broker
)

func main() {
	flag.IntVar(&metricsPort, "p", 8080, "port to export prometheus metrics")
	flag.IntVar(&numOfLocations, "n", 10, "number of locations to emulate")
	flag.IntVar(&numOfMinionsPerLocation, "m", 1, "number of minions per location")
	flag.StringVar(&brokerURL, "u", "localhost:9092", "broker URL")
	flag.StringVar(&brokerType, "t", "kafka", "broker type: kafka, grpc")
	flag.StringVar(&logLevel, "l", "info", "Logging level: debug, info, warn, error")
	flag.Parse()
	log.InitProdLogger(logLevel)

	go func() {
		log.Warnf("Starting Prometheus Metrics server on port %d", metricsPort)
		http.Handle("/", promhttp.Handler())
		err := http.ListenAndServe(fmt.Sprintf(":%d", metricsPort), nil)
		if err != nil {
			log.Fatalf("Cannot start prometheus HTTP server: %v", err)
		}
	}()

	log.Warnf("Creating %d locations (with %d minions per location) using %s as broker via %s...", numOfLocations, numOfMinionsPerLocation, brokerType, brokerURL)
	minions = make([]api.Broker, numOfLocations*numOfMinionsPerLocation)
	metrics := api.NewMetrics()
	metrics.Register()
	for i := 0; i < numOfLocations; i++ {
		for j := 0; j < numOfMinionsPerLocation; j++ {
			location := fmt.Sprintf("location-%04d", i+1)
			id := fmt.Sprintf("minion-%04d-%02d", i+1, j+1)
			log.Warnf("Starting minion %s on location %s", id, location)
			minionConfig := &api.MinionConfig{
				BrokerURL:  brokerURL,
				BrokerType: brokerType,
				ID:         id,
				Location:   location,
			}
			registry := sink.CreateSinkRegistry()
			client := broker.GetBroker(minionConfig, registry, metrics)
			if err := client.Start(); err != nil {
				log.Fatalf("Cannot start minion: %v", err)
			}
			minions[i+j] = client
		}
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt)
	<-stop
	for i := 0; i < len(minions); i++ {
		minions[i].Stop()
	}
	log.Infof("Done!")
}
