# Build the attached image
## Build the container image

    docker build . --tag ghost:gcs

## Try the image locally
Run it locally, with the bucket name as an Environment Variable

    docker run -d --name local-ghost -e NODE_ENV=development -e storage__gcs__bucket=gcs.janx.nl -p 8080:2368 ghost:gcs

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

## Database and mail service
Set up the MySQL 8.0 database service, i.e. `www-leenders-info:europe-west4:leenders-shared`, with a database named `ghost`.

Create the DB password as a secret:

    DB_PASSWORD=<<database_password>>
    echo -n "${DB_PASSWORD}" | gcloud secrets create db-password --replication-policy="automatic" --data-file=-

Create Mailgun SMTP account (follow https://www.ajfriesen.com/self-hosting-ghost-with-docker-compose/)
and store password as a secret:

    MAILGUN_PASSWORD=<<mailgun_password>>
    echo -n "${MAILGUN_PASSWORD}" | gcloud secrets create mailgun-password --replication-policy="automatic" --data-file=-

## Set up the service Account
Create a new Service Account for the Ghost production service, and give it permissions.

1. Storage Object Admin on the storage bucket
    ```
    gcloud storage buckets add-iam-policy-binding gs://gcs.janx.nl --member=ghost-production@janx-spirit.iam.gserviceaccount.com --role=roles/storage.objectAdmin
    ```
1. Read access on the secrets
1. Cloud SQL Client

## Use the image in Cloud Run
Set up a new container registry in the project (once):

    gcloud artifacts repositories create ghost --repository-format=docker --location=europe-west4 --description="My Ghost repo"

Now, tag the image (built above) as the latest build and push it to the project's Containter Registry

    docker tag ghost:gcs europe-west4-docker.pkg.dev/janx-spirit/ghost/ghost-gcs:latest
    docker push europe-west4-docker.pkg.dev/janx-spirit/ghost/ghost-gcs:latest

Deploy the Cloud Run revision, running as the Service Account, with all the config and secrets in environment variables:
 ```
gcloud run deploy ghost \
--image=europe-west4-docker.pkg.dev/janx-spirit/ghost/ghost-gcs:latest \
--set-env-vars='url=https://janx.nl' \
--set-env-vars='admin__url=https://ghost.janx.nl' \
--set-env-vars=database__client=mysql \
--set-env-vars='database__connection__socketPath=/cloudsql/www-leenders-info:europe-west4:leenders-shared' \
--set-env-vars=database__connection__database=ghost \
--set-env-vars=database__connection__user=root \
--set-env-vars=storage__gcs__bucket=gcs.janx.nl \
--set-env-vars=mail__transport=SMTP \
--set-env-vars=mail__options__service=Mailgun \
--set-env-vars=mail__options__host=smtp.eu.mailgun.org \
--set-env-vars=mail__options__port=465 \
--set-env-vars=mail__options__auth__user=postmaster@mg.janx.nl \
--set-env-vars=mail__options__secure=true \
--set-cloudsql-instances=www-leenders-info:europe-west4:leenders-shared \
--set-secrets=database__connection__password=projects/693812269963/secrets/db-password:latest,mail__options__auth__pass=mailgun-password:latest \
--service-account=ghost-production@janx-spirit.iam.gserviceaccount.com \
--execution-environment=gen1 \
--region=europe-west4 \
--project=janx-spirit
```
It takes a few minutes before Ghosts comes out of the "Busy Updating" maintenance mode.


# To do: 
- local containers to connect docker to Cloud SQL
