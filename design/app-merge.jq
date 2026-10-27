# Lineage: written by hand. An app's full description: design/family.json with the app's overrides
# laid over it (objects merge; arrays and values replace), then {id}, {name}, {version} and {port}
# filled in. Read by design/upstream-fetch, design/app-check and design/config-generate, so every
# stage sees the same app. Use with:
#   jq --slurpfile fam family.json -L . 'include "app-merge"; ...'

def full($fam):
  . as $a
  | (($fam | del(."//")) * ($a.overrides // {}))
  | walk(if type == "string"
      then gsub("\\{id\\}"; $a.id) | gsub("\\{name\\}"; $a.name) | gsub("\\{version\\}"; $a.version)
        | gsub("\\{port\\}"; ($a.port // "" | tostring))
      else . end)
  + {id: $a.id, name: $a.name, version: $a.version, port: $a.port, checked: ($a.checked != null)};
