# A jq 1.5+ filter script that generates the configuration of the
# Jenkins Elasticsearch Logs plug-in.
#
# If PIPELINE_LOG_ELASTICSEARCH_INDEX_URL is not set then no output
# is created, i.e. the log plug-in configuration is omitted and it
# should be inactive then.
#
# It takes the following environment variables as input:
#
#   PIPELINE_LOG_FLUENTD_HOST
#       The host name of Fluentd service to forward logs to.
#       If specified, forwarding to Fluentd will be configured.
#
#   PIPELINE_LOG_FLUENTD_PORT
#       The Fluentd service port.
#       Mandatory if forwarding to Fluentd is to be configured.
#
#   PIPELINE_LOG_FLUENTD_TAG
#       The event tag for Fluentd forwarding.
#       Mandatory if forwarding to Fluentd is to be configured.
#
#   PIPELINE_LOG_ELASTICSEARCH_INDEX_URL
#       The Elasticsearch index URL. If specified, forwarding to
#       Elasticsearch will be configured, except if forwarding
#       to Fluentd is enabled via PIPELINE_LOG_FLUENTD_HOST.
#
#   PIPELINE_LOG_ELASTICSEARCH_TRUSTEDCERTS_SECRET
#       The ID of the Jenkins credential containing the trusted
#       certificates.
#       Optional.
#
#   PIPELINE_LOG_ELASTICSEARCH_AUTH_SECRET
#       The ID of the Jenkins credential containing the credential
#       to authenticate at Elasticsearch. Used only if forwarding
#       to Elasticsearch is to be configured.
#       Optional.
#
#   PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON
#       The run ID to be set for all log events, in JSON format.
#       Mandatory.
#

####################
# Helpers
####################

def null_if_empty:
  if length == 0 then null else . end
  ;

def existing_params_out_of($names):
  $names[] | select(in(env) and (env[.] | null_if_empty))
  ;

def _prefix_error_with_param_name($name; filter):
  . as $value |
  try
    filter
  catch
    error("env var \($name): invalid value '\($value)': \(.)")
  ;

def optional_param($name):
  env[$name] | null_if_empty
  ;

def optional_param($name; conv):
  optional_param($name) | _prefix_error_with_param_name($name; conv)
  ;

def mandatory_param($name):
  optional_param($name) |
    if not then
      error("env var \($name) must be specified")
    else
      .
    end
  ;

def mandatory_param($name; conv):
  mandatory_param($name) | _prefix_error_with_param_name($name; conv)
  ;


####################
# Main
####################

if optional_param("PIPELINE_LOG_ELASTICSEARCH_INDEX_URL") | not then

  # no log destination -> do not configure log plug-in
  empty

else

  # common configuration part
  {
    "unclassified": {
      "elasticSearchLogs": {
        "elasticSearch": {
          "runIdProvider": {
            "json": {
              "jsonSource": {
                "string": {
                  "jsonString": mandatory_param("PIPELINE_LOG_ELASTICSEARCH_RUN_ID_JSON"; fromjson | tojson),
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

  if optional_param("PIPELINE_LOG_FLUENTD_HOST") then
    # write to Fluentd
    {
      "unclassified": {
        "elasticSearchLogs": {
          "elasticSearch": {
            "elasticsearchWriteAccess": {
              "fluentd": {
                "host": mandatory_param("PIPELINE_LOG_FLUENTD_HOST"),
                "port": mandatory_param("PIPELINE_LOG_FLUENTD_PORT"),
                "tag": mandatory_param("PIPELINE_LOG_FLUENTD_TAG"),
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
  else
    # write to Elasticsearch directly
    {
      "unclassified": {
        "elasticSearchLogs": {
          "elasticSearch": {
            "elasticsearchWriteAccess": "esDirectWrite",
            "url": mandatory_param("PIPELINE_LOG_ELASTICSEARCH_INDEX_URL"),
            "certificateId": optional_param("PIPELINE_LOG_ELASTICSEARCH_TRUSTEDCERTS_SECRET"),
            "credentialsId": optional_param("PIPELINE_LOG_ELASTICSEARCH_AUTH_SECRET")
          }
        }
      }
    }
  end

end
