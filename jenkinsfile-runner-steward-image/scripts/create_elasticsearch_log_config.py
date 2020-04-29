#
# Creates the configuration file for the Pipeline ElasticSearch Plug-in.
#
from base64 import b64encode
import json
import os
import sys
from sys import stdout


def die(msg):
    sys.exit(msg)

url = os.environ.get("PIPELINE_LOG_ELASTICSEARCH_INDEX_URL")
credentialsId = os.environ.get("PIPELINE_LOG_ELASTICSEARCH_AUTH_SECRET")
certificateId = os.environ.get("PIPELINE_LOG_ELASTICSEARCH_TRUSTEDCERTS_SECRET")
run_id_json = os.environ.get("PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON")

config = {}

if url:
    if not run_id_json:
        die("error: parameter PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON is not specified")

    config = {
        "unclassified": {
            "elasticSearchLogs": {
                "elasticSearch": {
                    "certificateId": certificateId if certificateId else None,
                    "credentialsId": credentialsId if credentialsId else None,
                    "elasticsearchWriteAccess": "esDirectWrite",
                    "runIdProvider": {
                        "json": {
                            "jsonSource": {
                                "string": {
                                    "jsonString": run_id_json
                                }
                            }
                        }
                    },
                    "saveAnnotations": False,
                    "url": url,
                }
            }
        }
    }

json.dump(config, sys.stdout, indent=2, sort_keys=True)
