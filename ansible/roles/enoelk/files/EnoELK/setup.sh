#!/bin/sh
set -e
cd "$(dirname "$0")"

apt-get update && apt-get install -y --no-install-recommends curl

while ! curl -sq http://elasticsearch:9200; do
    echo "Waiting for elasticsearch to start...";
    sleep 3;
done
while ! curl -sq --fail http://kibana:5601/api/status; do
    echo "Waiting for kibana to start..."
    sleep 3;
done

echo -e "\nCreating ILM policy 'eno-3-day-delete-policy'...";
curl -sq -X PUT http://elasticsearch:9200/_ilm/policy/eno-3-day-delete-policy -H 'Content-Type: application/json' -d '
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_age": "1d"
          }
        }
      },
      "delete": {
        "min_age": "3d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
'

echo -e "\nCreating enologmessage index template...";
curl -sq -X PUT http://elasticsearch:9200/_index_template/enologmessage_template -H 'Content-Type: application/json' -d '
{
  "index_patterns": [
    "enologmessage-*"
  ],
  "template": {
    "settings": {
      "index.lifecycle.name": "eno-3-day-delete-policy",
      "index.lifecycle.rollover_alias": "enologmessage"
    },
    "mappings": {
      "dynamic": false,
      "properties": {
        "@timestamp": {
          "type": "date_nanos"
        },
        "@version": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "agent": {
          "properties": {
            "ephemeral_id": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "hostname": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "id": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "type": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "version": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            }
          }
        },
        "ecs": {
          "properties": {
            "version": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            }
          }
        },
        "enologs": {
          "properties": {
            "currentRoundId": {
              "type": "long"
            },
            "flag": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "function": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "message": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "method": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "module": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "relatedRoundId": {
              "type": "long"
            },
            "serviceName": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "severity": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "severityLevel": {
              "type": "long"
            },
            "taskChainId": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "taskId": {
              "type": "long"
            },
            "teamId": {
              "type": "long"
            },
            "teamName": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "timestamp": {
              "type": "date_nanos"
            },
            "tool": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "type": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "variantId": {
              "type": "long"
            }
          }
        },
        "log": {
          "properties": {
            "file": {
              "properties": {
                "path": {
                  "type": "text",
                  "fields": {
                    "keyword": {
                      "type": "keyword",
                      "ignore_above": 256
                    }
                  }
                }
              }
            },
            "offset": {
              "type": "long"
            }
          }
        },
        "tags": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        }
      }
    }
  }
}
'

echo -e "\nBootstrapping initial enologmessage index...";
curl -sq -X PUT http://elasticsearch:9200/enologmessage-000001 -H 'Content-Type: application/json' -d '
{
  "aliases": {
    "enologmessage": {
      "is_write_index": true
    }
  }
}
'

echo -e "\nCreating enologmessage data view...";
curl -sq -X POST http://kibana:5601/api/data_views/data_view -H 'Content-Type: application/json' -H 'kbn-xsrf: reporting' -d '
{
  "data_view": {
    "title": "enologmessage-*",
    "name": "enologmessage-*",
    "timeFieldName": "enologs.timestamp"
  }
}
'

echo -e "\nCreating enostatisticsmessage data view...";
curl -sq -X POST http://kibana:5601/api/data_views/data_view -H 'Content-Type: application/json' -H 'kbn-xsrf: reporting' -d '
{
  "data_view": {
    "title": "enostatisticsmessage",
    "name": "enostatisticsmessage",
    "timeFieldName": "enostatistics.timestamp"
  }
}
'

echo -e "\nCreating visualizations";
curl -vvv -X POST -F "file=@./visualizations/saved-obj.ndjson" -H 'kbn-xsrf: true' http://kibana:5601/api/saved_objects/_import?overwrite=True

#echo -e "\nRunning metricbeat setup...";
#/usr/bin/metricbeat setup -e \
#    -E output.logstash.enabled=false \
#    -E output.elasticsearch.hosts=['elasticsearch:9200'] \
#    -E setup.kibana.host=kibana:5601

echo "done!"
