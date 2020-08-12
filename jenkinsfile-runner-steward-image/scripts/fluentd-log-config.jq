env as {
  PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON: $runIdJSON,
  PIPELINE_LOG_FLUENTD_HOST: $fluentdHost,
  PIPELINE_LOG_FLUENTD_PORT: $fluentdPort,
  PIPELINE_LOG_FLUENTD_TAG: $fluentdTag
}

|

def null_if_empty:
  if (. | length) == 0 then null else . end;

def mandatory_param(name):
  if (. | length) <= 0 then
    error("parameter \(name) is not specified")
  else
    empty
  end;

( $runIdJSON | mandatory_param("PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON") ),
( $fluentdHost | mandatory_param("PIPELINE_LOG_FLUENTD_HOST") ),
( $fluentdPort | mandatory_param("PIPELINE_LOG_FLUENTD_PORT") ),
( $fluentdTag | mandatory_param("PIPELINE_LOG_FLUENTD_TAG") ),

{
  "unclassified": {
    "elasticSearchLogs": {
      "elasticSearch": {
        "elasticsearchWriteAccess": {
          "fluentd": {
            "bufferCapacity": 1098304,
            "host": $fluentdHost,
            "maxRetries": 30,
            "maxWaitSeconds": 30,
            "retryMillis": 1000
            "port": $fluentdPort,
            "tag": $fluentdTag,
            "timeoutMillis": 3000,
            "bufferRetentionTimeMillis": 1000
          },
        }
        "runIdProvider": {
          "json": {
            "jsonSource": {
              "string": {
                "jsonString": $runIdJSON
              }
            }
          }
        },
        "saveAnnotations": false,
        "writeAnnotationsToLogFile": true
      }
    }
  }
}
