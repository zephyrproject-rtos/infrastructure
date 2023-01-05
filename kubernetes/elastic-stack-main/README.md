# elastic-stack-main

The elastic-stack-main component provides the Elastic stack deployment
configurations, that consist of ElasticSearch and Kibana, for production use.

Note that this component is not automatically deployed through Terraform and
must be manually deployed in the following order:

1. `elasticsearch.yaml`
2. `kibana.yaml`
3. `ingress.yaml`
