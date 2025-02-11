# My Custom Ghost Dockerfile

This file now does 3 things
1. Use the most current Ghost (alpine) image
2. Add the GCS storage adapter and some variables to the container
3. Load the Ghost theme Casper-i18n

The steps below explain how to use it with Google Cloud Run. A more visual explanation, in Dutch, can be found at my [weblog that is hosted on Cloud Run](https://janx.nl/ghost-in-the-cloud-shell/).

## 1. Build the container image, locally

    docker build . --tag ghost:gcs

## 2. Try the image locally
Run it locally, with the bucket name as an Environment Variable
    
    docker run -d --name local-ghost -e NODE_ENV=development -e storage__gcs__bucket=<<bucketname>> -p 8080:2368 ghost:gcs

Preview it in the local browser

    echo Open $(cloudshell get-web-preview-url -p 8080) to try ghost locally

To debug, enter the container via interactive shell (and enter `exit` to return to own shell):

    docker exec -it local-ghost sh
    docker logs local-ghost

Stop and remove the local container

    docker rm -f local-ghost

---

# 3. To the Cloud!
Following along the lines of https://parondeau.com/blog/self-hosting-ghost-gcp, using the image with Cloud SQL in production. But this time, with feeewing. (What was that? This is not a charade. Now try again.)

## 3.1 Service-account, Database and Mail service
First, create a service account, i.e. `ghost@<<project>>.iam.gserviceaccount.com`.

You probably already created a bucket. Don't forget set public read access, because it will contain your (public) images. And the service account will need to write into the bucket:
    
    gcloud storage buckets add-iam-policy-binding  gs://<<bucketname>> \
    --member=allUsers --role=roles/storage.objectViewer
    
    gcloud storage buckets add-iam-policy-binding gs://<<bucketname>> \
    --member=<<serviceaccount>> \
    --role=roles/storage.objectAdmin

Set up the MySQL 8.0 database service, i.e. `<<project>:<<location>>:<<sql-srv>>`, with a database named `ghost`.

Store the DB password as a managed secret:

    DB_PASSWORD=<database_password>
    echo -n "${DB_PASSWORD}" | gcloud secrets create db-password --replication-policy="automatic" --data-file=-

Create Mailgun SMTP account (follow https://www.ajfriesen.com/self-hosting-ghost-with-docker-compose/)
and store user & password as secrets:

    MAILGUN_USER=<<mailgun_user>>
    echo -n "${MAILGUN_USER}" | gcloud secrets create mailgun-user --replication-policy="automatic" --data-file=-

    MAILGUN_PASSWORD=<<mailgun_password>>
    echo -n "${MAILGUN_PASSWORD}" | gcloud secrets create mailgun-password --replication-policy="automatic" --data-file=-

## 3.2 Set up the service Account
Create a new Service Account for the Ghost production service, and give it permissions.

1. Storage Object Admin on the storage bucket
```
gcloud storage buckets add-iam-policy-binding gs://<<bucketname>> \
--member=ghost@<<project>>.iam.gserviceaccount.com --role=roles/storage.objectAdmin
```
1. Read access on the secrets (i.e. secret-id = `db-password`, `mailgun_user`, and `mailgun_password`)
```
gcloud secrets add-iam-policy-binding <<secret-id>> \
--member="ghost@<<project>>.iam.gserviceaccount.com" \
--role="roles/secretmanager.secretAccessor"
```
1. Cloud SQL Client
```
gcloud projects add-iam-policy-binding <<project>> \
--member="ghost@<<project>>.iam.gserviceaccount.com" \
--role=roles/cloudsql.instanceUser
```
## 3.3 Use the image in Cloud Run
Set up a new container registry in the project (once):

    gcloud artifacts repositories create ghost --repository-format=docker --location=europe-west4 --description="My Ghost repo"

Now, tag the image (built above) as the latest build and push it to the project's Containter Registry

    docker tag ghost:gcs europe-west4-docker.pkg.dev/<<project>>/ghost/ghost-gcs:latest
    docker push europe-west4-docker.pkg.dev/<<project>>/ghost/ghost-gcs:latest

Deploy the Cloud Run revision, running as the Service Account, with all the config and secrets in environment variables:
```
gcloud run deploy ghost \
--image=europe-west4-docker.pkg.dev/<<project>>/ghost/ghost-gcs:latest \
--set-env-vars='url=https://janx.nl' \
--set-env-vars='admin__url=https://ghost.janx.nl' \
--set-env-vars=database__client=mysql \
--set-env-vars='database__connection__socketPath=/cloudsql/<<project>:<<location>>:<<sql-srv>>' \
--set-env-vars=database__connection__database=ghost \
--set-env-vars=database__connection__user=root \
--set-env-vars=storage__gcs__bucket=<<bucketname>> \
--set-env-vars=mail__transport=SMTP \
--set-env-vars=mail__options__service=Mailgun \
--set-env-vars=mail__options__host=smtp.eu.mailgun.org \
--set-env-vars=mail__options__port=465 \
--set-env-vars=mail__options__secure=true \
--set-cloudsql-instances=<<project>:<<location>>:<<sql-srv>> \
--set-secrets=database__connection__password=projects/<<project-id>>/secrets/db-password:latest,mail__options__auth__user=mailgun_user,mail__options__auth__pass=mailgun-password:latest \
--service-account=ghost-production@<<project>>.iam.gserviceaccount.com \
--set-env-vars=database__connection__pool__min=1 \
--set-env-vars=database__connection__pool__max=20 \
--execution-environment=gen2 \
--region=europe-west4 \
--project=janx-spirit
--port=2368

gcloud run services update-traffic ghost --to-latest
```
It takes a few minutes before Ghosts comes out of the "Busy Updating" maintenance mode. The following startup probe appears to work as expected:
```
startupProbe:
      initialDelaySeconds: 180
      timeoutSeconds: 10
      periodSeconds: 30
      failureThreshold: 10
      httpGet:
        path: /favicon.ico
        port: 2368
```
