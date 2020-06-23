{
  "unclassified": {
    "elasticSearchLogs": {
      "elasticSearch": {
        "certificateId": env.PIPELINE_LOG_ELASTICSEARCH_TRUSTEDCERTS_SECRET,
        "credentialsId": env.PIPELINE_LOG_ELASTICSEARCH_AUTH_SECRET,
        "elasticsearchWriteAccess": "esDirectWrite",
        "runIdProvider": {
          "json": {
            "jsonSource": {
              "string": {
                "jsonString": env.PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON
              }
            }
          }
        },
        "saveAnnotations": false,
        "url": env.PIPELINE_LOG_ELASTICSEARCH_INDEX_URL
      }
    }
  }
}
