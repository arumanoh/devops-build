# DevOps Build: React Application Deployment

A production-style deployment of a React application using Docker, Jenkins CI/CD, Docker Hub, AWS EC2 and Uptime Kuma monitoring.

## Submission Details

| Item | Value |
|---|---|
| GitHub repository | https://github.com/arumanoh/devops-build |
| Deployed site | http://13.60.13.150 |
| Docker image (dev, public) | `arumanoh/dev` |
| Docker image (prod, private) | `arumanoh/prod` |
| Source application | https://github.com/sriram-R-krishnan/devops-build |
| Documentation with screenshots | [Project_3_App_Deployment_13th_Oct_2026.docx](./Project_3_App_Deployment_13th_Oct_2026.docx) |

## Architecture

```
Developer ──push──> GitHub (dev / master)
                        │ webhook
                        ▼
                 Jenkins (t3.small)
          build image → push to Docker Hub → deploy over SSH
                        │
          ┌─────────────┴─────────────┐
          ▼                           ▼
   arumanoh/dev (public)      arumanoh/prod (private)
                        │
                        ▼
              App server (t3.micro)
          Docker Compose, nginx on port 80
                        ▲
                        │ health check every 60 s
              Uptime Kuma (on the Jenkins server)
                        │
                  Gmail alert on state change
```

## Repository Contents

| File | Purpose |
|---|---|
| `build/` | Pre-built React application (static files) |
| `Dockerfile` | nginx:alpine image that serves `build/` on port 80 |
| `nginx.conf` | nginx config with a single-page-app fallback to `index.html` |
| `docker-compose.yml` | Runs the image; image name and tag come from `IMAGE_NAME` and `IMAGE_TAG` |
| `build.sh` | Builds the Docker image for `dev` or `prod` |
| `deploy.sh` | Pulls the image from Docker Hub and starts it with Compose |
| `Jenkinsfile` | CI/CD pipeline: select repo, build, push, deploy |
| `.dockerignore` / `.gitignore` | Keep unneeded and sensitive files out of the image and the repo |
| `Project_3_App_Deployment_13th_Oct_2026.docx` | Documentation with all screenshots and steps |

## 1. Application and Docker

The application is a pre-built React app, so no Node build stage is needed. The image copies the static files into nginx.

```dockerfile
FROM nginx:alpine
RUN rm -rf /usr/share/nginx/html/*
COPY build/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Run locally:

```bash
docker compose up -d --build
curl -I http://localhost
```

## 2. Bash Scripts

```bash
./build.sh dev          # builds arumanoh/dev:latest
./build.sh prod         # builds arumanoh/prod:latest
./deploy.sh dev         # pulls arumanoh/dev:latest and starts it on port 80
./deploy.sh prod 1      # pulls arumanoh/prod:1 and starts it on port 80
```

Both scripts accept an optional tag as the second argument (default `latest`).

## 3. Version Control

- All git operations were done from the command line.
- Work is committed to the `dev` branch and merged into `master` for production.
- `.gitignore` and `.dockerignore` are included.

## 4. Docker Hub

| Repository | Visibility | Receives images from |
|---|---|---|
| `arumanoh/dev` | Public | Pushes to the `dev` branch |
| `arumanoh/prod` | Private | Merges into the `master` branch |

Images are tagged with the Jenkins build number and `latest`.

## 5. Jenkins CI/CD

Jenkins runs a **Multibranch Pipeline** (`devops-build`) that reads the `Jenkinsfile` from each branch. A GitHub webhook (`/github-webhook/`) starts a build on every push, with a 1-minute repository scan as a backup.

| Stage | What it does |
|---|---|
| Checkout SCM | Fetches the branch from GitHub |
| Select repo | `master` selects `arumanoh/prod`; any other branch selects `arumanoh/dev` |
| Build | `docker build` with the build number tag and `latest` |
| Push | Logs in to Docker Hub with the `dockerhub-creds` credential and pushes both tags |
| Deploy | Over SSH (`app-server-ssh` credential): copies `docker-compose.yml` to the app server, pulls the image and restarts the container |

Behaviour:

- Push to `dev` builds the image and pushes it to **`arumanoh/dev`**.
- Merge `dev` into `master` builds the image and pushes it to **`arumanoh/prod`**.
- Pull request builds are disabled, so only branch builds can use the Docker Hub credentials.

Credentials are stored in Jenkins, and none are kept in this repository.

## 6. AWS Infrastructure

| Server | Type | Role |
|---|---|---|
| `devops-build-prod` | t3.micro (free-tier type used in place of t2.micro) | Runs the application container on port 80 |
| Jenkins server | t3.small, 20 GB disk, 2 GB swap | Jenkins and Uptime Kuma |

**Security group for the app server (`prod-app-sg`)**

| Type | Port | Source | Reason |
|---|---|---|---|
| HTTP | 80 | Anywhere (0.0.0.0/0) | Anyone with the IP can open the application |
| SSH | 22 | My IP | Server login only from my own IP |
| SSH | 22 | Jenkins server security group | Lets Jenkins deploy |

**Security group for the Jenkins server (`devops-build-sg`)**

| Type | Port | Source |
|---|---|---|
| SSH | 22 | My IP |
| Custom TCP | 8080 | Anywhere (needed for the GitHub webhook; protected by a Jenkins login) |
| Custom TCP | 3001 | My IP (Uptime Kuma dashboard) |

## 7. Monitoring

Uptime Kuma (open source) runs in Docker on the Jenkins server, so it keeps working if the app server fails.

- Monitor: HTTP(s) check of `http://13.60.13.150` every 60 seconds, with 2 retries
- Notification: email through Gmail SMTP (`smtp.gmail.com`, port 587, app password)
- Alerts fire on a state change: a **DOWN** email when the app stops, and a recovery email when it is back

**Tested:** stopping the container (`docker stop devops-build-app`) produced `ECONNREFUSED` in Kuma and a DOWN email within minutes. After `docker start devops-build-app` the monitor recovered and sent a recovery email.

## 8. Screenshots

All screenshots, with the steps, are in [Project_3_App_Deployment_13th_Oct_2026.docx](./Project_3_App_Deployment_13th_Oct_2026.docx).

| Area | Evidence |
|---|---|
| Jenkins | Login page, configuration settings, build commands in the console, green stage views for `dev` and `master` |
| AWS | EC2 console, security group configuration |
| Docker Hub | `dev` and `prod` repositories with image tags |
| Deployed site | Application running at http://13.60.13.150 |
| Monitoring | Uptime Kuma health status, the DOWN event and the alert emails |

## Notes

- Public IP addresses change when an EC2 instance is stopped and started, unless an Elastic IP is attached. The URLs above are valid while the instances are running.
- The app server is shared by both branches, so the most recent build (the last push to `dev` or `master`) is what is currently deployed.
