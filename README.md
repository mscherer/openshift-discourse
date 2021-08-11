# openshift-discourse
This is an automated setup of Discourse for OpenShift assuming you have an SMTP server you can use. The SMTP server is only optional insofar as you can have a proof of concept functioning without any of the email features of Discourse.

To get it working with the optional SMTP set up and Admin users:

`oc process -f openshift/discourse.yml -p PROJECT_NAME=<project-name> -p APPLICATION_DOMAIN=<yourdomain.com> -p SITE_ADMIN_EMAILS=<youradminsemails@example.com> -p SITE_ADMIN_EMAILS_KEY=<defaultadminpasswords> -p SMTP_USER=<userforsmtpserver> -p SMTP_PASSWORD=<smtpuserpassword> -p SMTP_ADDRESS=<smtp.example.com>` | oc create -f -

The postgresql extensions needed by Discourse need to be done manually until Misc's [PR:399](https://github.com/sclorg/postgresql-container/pull/399) on SCLORG's PSQL Container is merged:
e
`oc get pods | grep postgresql-1-`

`oc rsh pod/<postgresql-1-XXXXXX>`

```
$ psql
$ \c discourse
$ CREATE EXTENSION hstore;
$ CREATE EXTENSION pg_trgm;
$ \q
$ ctrl-D
```


Currently one must manually kick off the build for the custom S2I Dockerfile which should allow the deployment of Discourse to begin on its own in more than about 12 minutes. 

`$ oc new-build s2i-discourse-image`

If you are configuring something other than the default OpenShift DNS (i.e. your own domain) then go to the configuring TLS section now and come back here when you are done. When the deployment completes:

`$ oc get routes`

Use the Host/Port name with http:// in front of it to create an environment variable in the discourse pod:

`oc get pods | grep discourse`

`oc rsh pod/<discourse-#-######>`

`$ DISCOURSE_SITE_URL=http://<Host/Port>`

### Set up TLS for your domain on OpenShift 

These instructions assume you have a DNS already configured from a domain registrar.

We use this [OpenShift ACME](https://github.com/tnozicka/openshift-acme/tree/master/deploy#single-namespace).

Once you have those objects installed on your cluster, go to the route you configured when deploying Discourse and edit the annotations to reflect the following key value pair:
```
annotations:
  kubernetes.io/tls-acme: 'true'
```

Now take wonder at the marvel of the magic of the OpenShift operators ability to manage TLS for you. It is the kind of magic that — if featured in a Disney film — their would probably be two songs dedicated to its managing of TLS certs within the Kubernetes kingdom of isolation. 

## Upgrading Discourse while using this Template

I recommend trying the update from one version to another on at least a blank data-less version of Discourse BEFORE you try and redeploy on your live cluster, however when done properly you can upgrade from one minor release or patch to another by merely rebuilding the base image with the proper version of Discourse updated in the live BuildConfig object of your OpenShift instance and starting a new build.

If a rebuild and redeployment from your old version to your desired new version has been tested as stated above and you have backed up your data somewhere from the admin console, then the `openshift/discourse.yml` template is designed such that all you should need to do is change your git `ref: v2.X.X` in the live BuildConfig and start a new build. If the build succeeds the redeployment will happen automatically but if the deployment fails reverting has not been automated yet and you will have to do that manually.

### WARNING: These are some things that can go wrong during an upgrade
 * Improper MaxMind Key if your not using this that shouldn't need worrying about, I think
 * Using the wrong version of Bundler. Their seems to be a permissions clash with what Bundler does when it sees itself in the `Gemfile.lock` and what OpenShift will allow it to do so the best thing we could come up with was to always use the latest Red Hat supported version of Bundler and remove that section from the `Gemfile.lock`. For more context see: https://github.com/sclorg/s2i-ruby-container/pull/332
 * Not reviewing the commit history of [discourse/discourse_docker](https://github.com/discourse/discourse_docker) before trying to upgrade so that you can see if any dependencies were added or removed, etc.
 * Leaving too many dependencies in the S2I image for convenience or backwards compatibility
 * Forgetting to double check what branches from which you are pulling

#### Things that can MESS UP YOUR DATABASE
At all cost you should want to avoid messing up your database such that you don't have a back up from which you can reinstall. The database and the uploads directory are the only features with persistence in all of Discourse.

 * Running out of available PostgresQL persistent memory storage space (Alerts can be configured in OpenShift to prevent this situation)
 * An update that somehow completed the build process improperly and then subsequently corrupts your database when it tries to deploy

Just a reminder: make sure you back up regularly.

##Re-instantiating your Database and Uploads

**TODO**: however, CERN, Gnome, and Bitnami have documented ways to re-instantiate a back up Kubernetes Discourse instance and our steps shouldn't be much different from those. Comparatively I think my setup is both more open and well documented in other areas though, in case you are wondering.

## To run this locally on an OpenShift CRC Virtual Machine:

[Install OpenShift CRC](https://developers.redhat.com/products/codeready-containers/overview).

Once installed after running `$ crc setup`,

give your local CRC instance 16GB of RAM: `$ crc config set memory 16000`.

**TODO:** Give your CRC X Gb of hard-disk space.

Now you should restart your cluster if it is running or just start your CRC cluster: `$ crc stop` and `$ crc start`.

Once started, run the `$ oc new-app` command from above and follow the same steps.

## Contribute
If you would like to contribute here are some areas I am already aware could use some improvement:

 * We believe we have over allocated space for Redis to run on small instances, if you are running this yourself please report back your maximum Redis usage statistics so we can add reasonable suggestions to this documentation.
 * We do not recommend running this without an Nginx reverse proxy in front of it unless you are sure you know what you are doing but if you do we would like to document those steps , too. Last I knew it was unsafe to run Puma (our Ruby server) without a reverse proxy in front of it. And quick performance tests showed our Nginx configuration to be more permanent than standalone Puma on OpenShift anyway

### Easy Fixes
 * Make a PR that has nice documentation for this README.md detailing how to easily re-instantiate a backup
 * The `$ rake --tasks` aren't very well documented for Discourse. I think both us and the Discourse project would appreciate if someone documented the rake tasks of Discourse because they seem to have had to override some [standard Rails 6 patterns](https://meta.discourse.org/t/the-rake-db-commands-and-initializing-a-discourse-instance/198938/3).
 * Operationalize the `helm-conversion` Branch and document how to use it. The [template2helm converter](https://github.com/redhat-cop/template2helm) was designed for this purpose
    * [extra] document how to use the helm branch from Ansible
    * [extra] Maintain your own Helm fork if you like
 * Set up a Ceph cluster behind the shared persistent volume such that Discourse can use it to scale reliably and without the anti-pattern of two containers sharing a persistent volume
 * Create a Kubernetes CronJob to get backups off the cluster automatically
 * Performance testing comparing with and without Nginx because technically OpenShift has it's own reverse proxy already
 * Put frequently changing things in a ConfigMap
 * Figure out how to build without talking to the live PostgresQL instance

### Not-so-easy Fixes
 * Someone could take the build images out of the Discourse template and set them up such that they are pulling from quay.io instead of building on the cluster every time. This would decrease deployment time by a lot but may be more complicated than it sounds because Discourse seems to be doing `$ rake db:create` and initializing Redis during the build process.
    * With the above done we could reliably deploy to vanilla Kubernetes by [swaping DeploymentConfigs with Kubernetes Deployments](https://gist.github.com/jontrossbach/64a65a453f277a6cdc9c40c2c04d2ec5)
 * Document how to run the Discourse smoke tests on a remote URL
 * Get OpenShift monitoring stack working to monitor `openshift-discourse`. [This is the best explanation I've seen of how to get it working with Service Monitor](https://www.youtube.com/watch?v=TRSy6G3y9aY&t=2367s) and I tried to make a [fork of the discourse-prometheus plugin](https://github.com/jontrossbach/discourse-prometheus) from Discourse to get it to work but I was without success... I think... it was only recent changes that seemed to have broke `discourse-prometheus` after a [localhost call was hard-coded in the plugin](https://meta.discourse.org/t/discourse-prometheus-plugin-throws-error-with-bitnami-discourse-2-6-7/197100)
