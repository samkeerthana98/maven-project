# maven-project

A Java Multi-Module Maven project with a complete Jenkins + Docker CI/CD pipeline across three EC2 instances.

---

## Project Structure

```
maven-project/
├── pom.xml                    # Parent POM — defines modules, versions, dependencies
├── server/                    # server module → server.jar (Greeter.java + JUnit tests)
├── webapp/                    # webapp module → webapp.war (index.jsp, web.xml)
├── Dockerfile                 # Multi-stage: Maven builder → Tomcat runtime
├── Jenkinsfile                # Pipeline 1: Traditional WAR deployment
├── Jenkinsfile-docker         # Pipeline 2: Docker CI/CD pipeline
└── script.groovy              # Shared Groovy helper loaded by both pipelines
```

Build outputs: `server/target/server.jar`, `webapp/target/webapp.war`

Both modules are siblings in the Maven reactor. `server` is not a declared dependency of `webapp`.

---

## Technology Stack

| Component | Version |
|-----------|---------|
| Java | 21 (Eclipse Temurin) |
| Maven | 3.9.9 |
| Servlet API | 2.5 (`javax.servlet`) |
| JUnit / Mockito | 4.13.2 / 5.14.2 |
| Tomcat | 10.1 |
| Jenkins | LTS |
| Docker | Latest stable |
| OS (EC2) | Ubuntu |

---

## Infrastructure

| Instance | Role | Maven | Docker |
|----------|------|-------|--------|
| Jenkins Controller | UI, scheduling, credentials | No | No |
| DevServer (agent label: `DevServer`) | Build, test, docker build/push, deploy dev | Yes | Yes |
| ProdServer (agent label: `ProdServer`) | Pull image, deploy prod | No | Yes |

---

## Pipeline 1 — `Jenkinsfile` (Traditional WAR)

Parameter: `select_environment` → `dev` or `prod`

| Stage | Agent | What it does |
|-------|-------|--------------|
| Build | DevServer | Loads `script.groovy`; `mvn clean package -DskipTests=true`; stashes WAR |
| Test (TestA \| TestB) | DevServer | Each: echoes label + runs `mvn test` in parallel |
| Deploy Dev | DevServer | Unstash WAR → `sudo cp` → `/var/www/html/` → `sudo jar -xvf` |
| Deploy Prod | ProdServer | Unstash WAR → `sudo cp` → `/var/www/html/` → `sudo jar -xvf` |

No Docker. No manual approval. Requires passwordless `sudo` for the Jenkins user on each agent.

---

## Pipeline 2 — `Jenkinsfile-docker` (Docker CI/CD)

Parameter: `select_environment` → `dev` or `prod`

| Stage | Agent | What it does |
|-------|-------|--------------|
| Build | DevServer | Loads `script.groovy`; `mvn clean package -DskipTests=true` |
| Test (TestA \| TestB) | DevServer | TestA: `echo "Linux test successful"` / TestB: `echo "integration test successful"` |
| Docker Build | DevServer | `docker build -t samkeerthana/maven-project:latest .` |
| Docker Login | DevServer | `echo $DOCKER_CREDS_PSW \| docker login -u $DOCKER_CREDS_USR --password-stdin` |
| Docker Push | DevServer | Pushes `samkeerthana/maven-project:latest` (both `${IMAGE_TAG}` and `latest` tags) |
| Deploy Dev | DevServer | `docker pull` → `docker stop \|\| true` → `docker rm \|\| true` → `docker run -d -p 8080:8080` |
| Deploy Prod | ProdServer | Manual approval (5-day timeout) → `docker login` → `docker pull` → `docker stop \|\| true` → `docker rm \|\| true` → `docker run -d -p 8080:8080` |

Post (always): `docker logout || true`

The `|| true` on `docker stop` and `docker rm` prevents failure when no container exists yet (e.g. first run).
The `input` approval step runs **on the ProdServer agent** inside the `Deploy Prod` stage.

---

## Dockerfile

Two-stage build:

**Stage 1 — Builder** (`maven:3.9.9-eclipse-temurin-21`)
- Copies POM files first → runs `mvn dependency:go-offline` (caches deps as a layer)
- Copies source → runs `mvn clean package -B` → produces `webapp/target/webapp.war`

**Stage 2 — Runtime** (`tomcat:10.1-jdk21-temurin`)
- Removes default Tomcat webapps
- Copies `webapp.war` as `ROOT.war` → served at `http://localhost:8080/`
- Final image: JDK 21 + Tomcat 10.1 + app only. No Maven, no source code.

---

## Jenkins Credentials

Stored in Jenkins Credentials Manager. Nothing hardcoded in pipeline files.

| ID | Used for |
|----|---------|
| `github-credentials` | Git checkout |
| `dockerhub-credentials` | `docker login`, `docker push`, `docker pull` |

`dockerhub-credentials` uses the `credentials()` binding → auto-creates `DOCKER_CREDS_USR` and `DOCKER_CREDS_PSW`.

---

## Prerequisites

**Jenkins Controller** — Jenkins LTS, credentials configured, Maven tool `mymaven` v3.9.9 configured, two agent nodes added, GitHub webhook enabled.

**DevServer** — Java, Maven 3.9.9, Docker, Jenkins inbound agent JAR connected to Controller.

**ProdServer** — Java, Docker, Jenkins inbound agent JAR connected to Controller. Maven not required.

---

## Jenkins Setup

**1. Add Credentials** — Jenkins → Manage Jenkins → Credentials → (global) → Add Credentials

| ID | Kind | Username | Password |
|----|------|----------|----------|
| `github-credentials` | Username with password | GitHub username | Personal access token |
| `dockerhub-credentials` | Username with password | Docker Hub username | Docker Hub password |

**2. Configure Maven** — Jenkins → Manage Jenkins → Tools → Maven installations → Add Maven
- Name: `mymaven` (must match Jenkinsfiles exactly) — Version: `3.9.9`

**3. Configure Agent Nodes** — Jenkins → Manage Jenkins → Nodes → New Node

| Field | DevServer | ProdServer |
|-------|-----------|-----------|
| Node name & label | `DevServer` | `ProdServer` |
| Launch method | Inbound agent (connect to controller) | Inbound agent (connect to controller) |

Run the agent JAR on each EC2:
```bash
java -jar agent.jar -url http://<JenkinsController-IP>:8080/ \
  -secret <agent-secret> -name <node-name> -workDir "/home/ubuntu/jenkins-agent"
```

**4. Create Pipeline Jobs** — Jenkins → New Item → Pipeline
- Traditional pipeline → script path: `Jenkinsfile`
- Docker pipeline → script path: `Jenkinsfile-docker`
- Enable: **GitHub hook trigger for GITScm polling**

**5. GitHub Webhook** — Repo → Settings → Webhooks → Add webhook
- Payload URL: `http://<JenkinsController-IP>:8080/github-webhook/`
- Content type: `application/json` — Event: **Just the push event**

---

## Local Build

```bash
mvn clean package            # build + run tests
mvn clean package -DskipTests=true   # build only
mvn test                     # tests only
```

```bash
docker build -t samkeerthana/maven-project:latest .
docker run -d --name maven-project -p 8080:8080 samkeerthana/maven-project:latest
# http://localhost:8080/
docker stop maven-project && docker rm maven-project
```

---

## Accessing the Application

| Environment | URL | Notes |
|-------------|-----|-------|
| Development | `http://<DevServer-IP>:8080` | Docker pipeline, param `dev` |
| Production | `http://<ProdServer-IP>:8080` | Docker pipeline, param `prod` — requires manual approval |

---

## Testing

Two JUnit 4 tests in `TestGreeter.java`:

| Test | Verifies |
|------|---------|
| `greetShouldIncludeTheOneBeingGreeted` | `greet()` output contains the name passed in |
| `greetShouldIncludeGreetingPhrase` | `greet()` output is longer than just the name |

Run locally: `mvn test`
