package main

import (
	"flag"
	"fmt"
	"time"
)

var (
	numOfLocations   int
	nodesPerLocation int
	requisition      string
)

func main() {
	flag.StringVar(&requisition, "r", "Remote", "requisition name")
	flag.IntVar(&numOfLocations, "l", 10, "number of existing locations")
	flag.IntVar(&nodesPerLocation, "n", 1, "number of nodes per location")
	flag.Parse()

	stamp := time.Now().Format("2006-01-02T15:04:05.000-07:00")
	fmt.Printf(`<model-import xmlns="http://xmlns.opennms.org/xsd/config/model-import" date-stamp="%s" foreign-source="%s">`+"\n", stamp, requisition)
	for i := 0; i < numOfLocations; i++ {
		location := fmt.Sprintf("location-%04d", i+1)
		for j := 0; j < nodesPerLocation; j++ {
			id := fmt.Sprintf("fake-node-%04d-%02d", i+1, j+1)
			fmt.Printf(`  <node location="%s" foreign-id="%s" node-label="%s">`+"\n", location, id, id)
			fmt.Printf(`    <interface ip-addr="127.0.11.%d" snmp-primary="P"/>`+"\n", j+1)
			fmt.Println("  </node>")
		}
	}

	fmt.Println("</model-import>")
}
