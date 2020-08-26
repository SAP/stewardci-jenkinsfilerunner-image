#
# A jq 1.5+ filter script that generates the configuration of the
# Jenkins Elasticsearch Logs plug-in.
#
# It takes the following environment variables as input:
#
#    PIPELINE_LOG_FLUENTD_HOST
#    PIPELINE_LOG_FLUENTD_PORT
#    PIPELINE_LOG_FLUENTD_TAG
#    PIPELINE_LOG_ELASTICSEARCH_INDEX_URL
#    PIPELINE_LOG_ELASTICSEARCH_TRUSTEDCERTS_SECRET
#    PIPELINE_LOG_ELASTICSEARCH_AUTH_SECRET
#    PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON
#
# If PIPELINE_LOG_FLUENTD_HOST is set, it configures writing to
# Fluentd, else if PIPELINE_LOG_ELASTICSEARCH_INDEX_URL is set,
# it configures writing to Elasticsearch directly, else it
# does not create a configuration which disables the Elasticsearch
# Log plugin.
#

#
# Helpers
#

def null_if_empty:
  if length == 0 then null else . end
  ;

def existing_args_out_of($names):
  $names[] | select(in(env) and (env[.] | null_if_empty))
  ;

def optional_arg($name):
  env[$name] | null_if_empty
  ;

def _conv($name; $value; conv):
  if . != null then
    try
      conv
    catch
      error("parameter \($name): invalid value '\($value)': \(.)")
  else
    .
  end
  ;

def optional_arg($name; conv):
  optional_arg($name) | . as $value | _conv($name; $value; conv)
  ;

def mandatory_arg($name):
  optional_arg($name) |
    if not then
      error("parameter must be specified: \($name)")
    else
      .
    end
  ;

def mandatory_arg($name; conv):
  mandatory_arg($name) | . as $value | _conv($name; $value; conv)
  ;


#
# Main
#

first(existing_args_out_of([
    "PIPELINE_LOG_FLUENTD_HOST",
    "PIPELINE_LOG_ELASTICSEARCH_INDEX_URL"
])) as $leadingArg

|

if $leadingArg then

  # common configuration part
  {
    "unclassified": {
      "elasticSearchLogs": {
        "elasticSearch": {
          "runIdProvider": {
            "json": {
              "jsonSource": {
                "string": {
                  "jsonString": mandatory_arg("PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON"; fromjson | tojson),
                }
              }
            }
          },
          "saveAnnotations": false,
          "writeAnnotationsToLogFile": false
        }
      }
    }
  }

  *  # recursively merge with ...

  if $leadingArg == "PIPELINE_LOG_FLUENTD_HOST" then

    # write to Fluentd
    {
      "unclassified": {
        "elasticSearchLogs": {
          "elasticSearch": {
            "elasticsearchWriteAccess": {
              "fluentd": {
                "host": mandatory_arg("PIPELINE_LOG_FLUENTD_HOST"),
                "port": mandatory_arg("PIPELINE_LOG_FLUENTD_PORT"),
                "tag": mandatory_arg("PIPELINE_LOG_FLUENTD_TAG"),
                "bufferCapacity": 1098304,
                "bufferRetentionTimeMillis": 1000,
                "maxRetries": 30,
                "maxWaitSeconds": 30,
                "retryMillis": 1000,
                "timeoutMillis": 3000
              }
            }
          }
        }
      }
    }

  elif $leadingArg == "PIPELINE_LOG_ELASTICSEARCH_INDEX_URL" then

    # write to Elasticsearch directly
    {
      "unclassified": {
        "elasticSearchLogs": {
          "elasticSearch": {
            "elasticsearchWriteAccess": "esDirectWrite",
            "url": mandatory_arg("PIPELINE_LOG_ELASTICSEARCH_INDEX_URL"),
            "certificateId": optional_arg("PIPELINE_LOG_ELASTICSEARCH_TRUSTEDCERTS_SECRET"),
            "credentialsId": optional_arg("PIPELINE_LOG_ELASTICSEARCH_AUTH_SECRET")
          }
        }
      }
    }

  else
    error("internal error: unhandled leading arg: \($leadingArg)")
  end
else
  # no configuration -> logging to Elasticsearch is disabled
  {}
end
