# openshift-discourse
This is an automated deploment of discourse for OpenShift

To get it working (with the optional SMTP set up and Admin users):

`oc new-app -f openshift/discourse.yml -p PROJECT_NAME=<project-name> -p APPLICATION_DOMAIN=<yourdomain.com> -p DISCOURSE_ADMIN_EMAILS=<youradminsemails@example.com> -p DISCOURSE_ADMIN_EMAILS_KEY=<defaultadminpasswords> -p SMTP_USER=<userforsmtpserver> -p SMTP_PASSWORD=<smtpuserpassword> -p SMTP_ADDRESS=<smtp.example.com>`

The postgresql extensions needed by discourse need to be done manually:

`oc get pods | grep postgresql-1-`

`oc rsh pod/<postgresql-1-XXXXXX>`

`$ psql`
`$ \c discourse`
`$ CREATE EXTENSION hstore;`
`$ CREATE EXTENSION pg_trgm;`
`$ \q`
`$ ctrl-D`


Currently one must manually kick off the build for the custom s2i Dockerfile which should allow the deployment of discourse to begin on its own in more than about 12 minutes. 

When the deployment completes:

`oc get routes`

Use the Host/Port name with http:// in front of it to create and environment variable in the discourse pod:

`oc get pods | grep discourse`

`oc rsh pod/<discourse-#-######>`

`$ DISCOURSE_SITE_URL=http://<Host/Port>`

## To run this locally on an OpenShift CRC Virtual Machine:

{Install OpenShift CRC}(https://developers.redhat.com/products/codeready-containers/overview).

Once installed, run the `$ oc new-app` command from above and follow the same steps.

