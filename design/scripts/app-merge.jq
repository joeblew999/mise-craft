# Lineage: written by hand. An app's full description: design/family.json with the app's overrides
# laid over it (objects merge; arrays and values replace), then {id}, {name}, {version} and {port}
# filled in. Read by design/scripts/1-upstream-fetch, design/scripts/2-app-check and design/scripts/5-config-generate, so every
# stage sees the same app. Use with:
#   jq --slurpfile fam family.json -L scripts 'include "app-merge"; ...'

def full($fam):
  . as $a
  | (($fam | del(."//")) * ($a.overrides // {}))
  | walk(if type == "string"
      then gsub("\\{id\\}"; $a.id) | gsub("\\{name\\}"; $a.name) | gsub("\\{version\\}"; $a.version)
        | gsub("\\{port\\}"; ($a.port // "" | tostring))
      else . end)
  + {id: $a.id, name: $a.name, version: $a.version, port: $a.port, checked: ($a.checked != null)};
