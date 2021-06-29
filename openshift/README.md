# Postgres deployment not working

After following the rule for the [gist I made]() Postgres is still not working. I also tried using openshift console but to my dismay I found that the template `oc process <same args as root dir README oc command>` command was rejecting my templat file saying It was missing an expected key.

The working openshift deployment file is incluse as `postgresql.yml.live.bak`.

The Deployment isolated from a template is passing `kubectl apply -f postgresql.yml --dry-run=client`.

Still a mystery.