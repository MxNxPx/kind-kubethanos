package main

import (
	"context"
	"fmt"
	"io/ioutil"
	"kubethanos/kubethanos"
	"kubethanos/thanos"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/alecthomas/kingpin"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/client-go/kubernetes"
	_ "k8s.io/client-go/plugin/pkg/client/auth"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/klog"

	log "github.com/sirupsen/logrus"
)

var (
	namespaces       string
	includedPodNames string
	includedNodeNames string
	excludedPodNames string
	master           string
	healthCheckAddr  string
	kubeconfig       string
	interval         time.Duration
	ratioToKill      float64
	dryRun           bool
	debug            bool
)

func init() {
	klog.SetOutput(ioutil.Discard)

	kingpin.Flag("namespaces", "A namespace or a set of namespaces to restrict thanoskube").StringVar(&namespaces)
	kingpin.Flag("included-pod-names", "A string to select which pods to kill").StringVar(&includedPodNames)
	kingpin.Flag("node-names", "A string to select nodes, pods within the selected nodes will be killed").StringVar(&includedNodeNames)
	kingpin.Flag("excluded-pod-names", "A string to exclude pods to kill").StringVar(&excludedPodNames)
	kingpin.Flag("master", "The address of the Kubernetes cluster to target, if none looks under $HOME/.kube").StringVar(&master)
	kingpin.Flag("healthcheck", "Listens this endpoint for healtcheck").Default(":8080").StringVar(&healthCheckAddr)
	kingpin.Flag("kubeconfig", "Path to a kubeconfig file").StringVar(&kubeconfig)
	kingpin.Flag("interval", "Interval between killing pods").Default("10m").DurationVar(&interval)
	kingpin.Flag("ratio", "Ratio of pods to kill").Default("0.5").FloatVar(&ratioToKill)
	kingpin.Flag("dry-run", "If true, print out the pod names without actually killing them.").Default("false").BoolVar(&dryRun)
	kingpin.Flag("debug", "Enable debug logging.").BoolVar(&debug)
}

func main() {
	kingpin.Parse()

	if debug {
		log.SetLevel(log.DebugLevel)
	}

	log.WithFields(log.Fields{
		"namespaces":       namespaces,
		"includedPodNames": includedPodNames,
		"nodeNames": includedNodeNames,
		"excludedPodNames": excludedPodNames,
		"master":           master,
		"kubeconfig":       kubeconfig,
		"interval":         interval,
		"ratioToKill": ratioToKill,
		"dryRun":           dryRun,
		"debug":            debug,
	}).Info("started reading config")

	client, err := newClient()
	if err != nil {
		log.WithField("err", err).Fatal("failed to connect to cluster.. exiting")
	}

	var namespaces = parseNamespaces(namespaces)

	log.WithFields(log.Fields{
		"namespaces":       namespaces,
		"includedPodNames": includedPodNames,
		"nodeNames": includedNodeNames,
		"excludedPodNames": excludedPodNames,
	}).Info("setting pod filter")

	kubeThanos := kubethanos.New(
		client,
		namespaces,
		includedPodNames,
		includedNodeNames,
		excludedPodNames,
		ratioToKill,
		dryRun,
		thanos.NewThanos(client, log.StandardLogger()),
	)

	go startHealthCheck(healthCheckAddr)

	done := make(chan os.Signal, 1)
	signal.Notify(done, syscall.SIGINT, syscall.SIGTERM)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go func() {
		<-done
		cancel()
	}()

	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	kubeThanos.Run(ctx, ticker.C)
}

func newClient() (*kubernetes.Clientset, error) {
	// look for kubeconfig in home if not set
	if kubeconfig == "" {
		if _, err := os.Stat(clientcmd.RecommendedHomeFile); err == nil {
			kubeconfig = clientcmd.RecommendedHomeFile
		}
	}

	log.WithFields(log.Fields{
		"kubeconfig": kubeconfig,
		"master":     master,
	}).Info("found config with parameters: ")

	config, err := clientcmd.BuildConfigFromFlags(master, kubeconfig)
	if err != nil {
		return nil, err
	}

	client, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, err
	}

	serverVersion, err := client.Discovery().ServerVersion()
	if err != nil {
		return nil, err
	}

	log.WithFields(log.Fields{
		"master":        config.Host,
		"serverVersion": serverVersion,
	}).Info("connected to cluster")

	return client, nil
}

func parseNamespaces(str string) labels.Selector {
	selector, err := labels.Parse(str)
	if err != nil {
		log.WithFields(log.Fields{
			"selector": str,
			"err":      err,
		}).Fatal("failed to parse namespaces")
	}
	return selector
}

func startHealthCheck(healthCheckAddress string) {
	http.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintln(w, "OK")
	})

	if err := http.ListenAndServe(healthCheckAddress, nil); err != nil {
		log.WithField("err", err).Fatal("failed to start health check endpoint")
	}
}
