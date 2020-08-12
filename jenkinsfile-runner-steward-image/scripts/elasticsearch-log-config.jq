env as {
  PIPELINE_LOG_ELASTICSEARCH_TRUSTEDCERTS_SECRET: $certificateId,
  PIPELINE_LOG_ELASTICSEARCH_AUTH_SECRET: $credentialsId,
  PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON: $runIdJSON,
  PIPELINE_LOG_ELASTICSEARCH_INDEX_URL: $indexURL
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
( $indexURL | mandatory_param("PIPELINE_LOG_ELASTICSEARCH_INDEX_URL") ),

{
  "unclassified": {
    "elasticSearchLogs": {
      "elasticSearch": {
        "certificateId": ( $certificateId | null_if_empty ),
        "credentialsId": ( $credentialsId | null_if_empty ),
        "elasticsearchWriteAccess": "esDirectWrite",
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
        "writeAnnotationsToLogFile": true,
        "url": $indexURL
      }
    }
  }
}
