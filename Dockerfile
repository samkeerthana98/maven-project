# =============================================================================
# PROJECT ANALYSIS
# -----------------------------------------------------------------------------
# Type        : Multi-module Maven project
# Modules     : server (JAR), webapp (WAR)
# Java version: 21
# Maven version: 3.9.9
# Deployable artifact: webapp/target/webapp.war
# Runtime     : Tomcat 10.1 (Jakarta EE 10 / Servlet 6.0 compatible)
# Port        : 8080
# =============================================================================


# =============================================================================
# STAGE 1 — BUILD
# Base image  : maven:3.9.9-eclipse-temurin-21
#   - Official Maven image pinned to 3.9.9 (matches <prerequisites><maven>
#     declared in root pom.xml).
#   - Eclipse Temurin JDK 21 matches maven.compiler.source/target = 21.
#   - This stage produces the WAR artifact and runs all tests.
#   - It is NOT shipped in the final image — only the artifact is carried over.
# =============================================================================
FROM maven:3.9.9-eclipse-temurin-21 AS builder

# Set the working directory inside the container.
# All subsequent COPY / RUN instructions operate relative to this path.
WORKDIR /app

# -----------------------------------------------------------------------------
# LAYER CACHE OPTIMISATION — copy POM files before source code.
#
# Docker builds layers top-to-bottom and re-uses cached layers when the
# inputs to a layer haven't changed. By copying only the POM files first and
# running dependency resolution as a separate step, we ensure that the
# expensive "download the internet" step is only re-executed when a pom.xml
# actually changes — not every time a .java file is edited.
# -----------------------------------------------------------------------------

# Root (parent) POM — defines the reactor, pluginManagement, and versions.
COPY pom.xml ./pom.xml

# Module POMs — each submodule must be declared here so Maven can resolve
# the full reactor without the source tree.
COPY server/pom.xml  server/pom.xml
COPY webapp/pom.xml  webapp/pom.xml

# Resolve and cache all compile + test dependencies declared across all
# modules. The -B flag enables batch (non-interactive) mode — no progress
# bars, clean CI-friendly output.
RUN mvn dependency:go-offline -B

# -----------------------------------------------------------------------------
# Copy the actual source code.
# This is done AFTER dependency caching so a source change only invalidates
# the layers below this line, not the dependency download layer.
# -----------------------------------------------------------------------------

# server module — business logic (produces server.jar, used by webapp)
COPY server/src server/src

# webapp module — WAR artifact that will be deployed to Tomcat
COPY webapp/src webapp/src

# -----------------------------------------------------------------------------
# Build the full reactor.
#   clean   — wipe any leftover artifacts from a previous build
#   package — compile → test → package (runs JUnit tests in server module)
#   -B      — batch mode (no interactive prompts)
#
# The resulting deployable artifact is:
#   /app/webapp/target/webapp.war
#
# The finalName is set to "${project.artifactId}" in webapp/pom.xml,
# so the file is always named "webapp.war" regardless of the project version.
# -----------------------------------------------------------------------------
RUN mvn clean package -B


# =============================================================================
# STAGE 2 — RUNTIME
# Base image  : tomcat:10.1-jdk21-temurin
#   - Official Apache Tomcat 10.1 image.
#   - Tomcat 10.1 implements the Jakarta EE 10 Servlet 6.0 spec.
#   - The webapp uses the Servlet 2.5 API (javax.servlet), which Tomcat 10.1
#     serves via its backward-compatibility layer — no changes needed.
#   - Eclipse Temurin JDK 21 matches the compile target.
#   - Maven and all build tooling are NOT present in this image, keeping it
#     lean and reducing the attack surface.
# =============================================================================
FROM tomcat:10.1-jdk21-temurin AS runtime

# -----------------------------------------------------------------------------
# Remove the default Tomcat sample web applications that ship with the image.
# These include the ROOT app, examples, manager, host-manager, and docs.
# Removing them:
#   - Reduces the final image size.
#   - Eliminates well-known attack surfaces (e.g., the Tomcat Manager UI).
# -----------------------------------------------------------------------------
RUN rm -rf /usr/local/tomcat/webapps/*

# -----------------------------------------------------------------------------
# Copy the WAR produced in the builder stage into Tomcat's webapps directory.
#
# Naming it ROOT.war causes Tomcat to auto-deploy it as the root context,
# so the application is accessible at:
#   http://localhost:8080/          → index.jsp ("Hello, World! version 2")
#
# If named webapp.war instead, it would be at http://localhost:8080/webapp/
# -----------------------------------------------------------------------------
COPY --from=builder /app/webapp/target/webapp.war \
                    /usr/local/tomcat/webapps/ROOT.war

# -----------------------------------------------------------------------------
# Expose port 8080 — the default HTTP connector port for Tomcat.
# This is documentation for the caller; actual port binding is done at
# runtime with `docker run -p <host-port>:8080`.
# -----------------------------------------------------------------------------
EXPOSE 8080

# -----------------------------------------------------------------------------
# Start Tomcat in the foreground using the catalina.sh script.
# Using the "run" argument keeps the JVM as PID 1, which means:
#   - Docker stop/kill signals (SIGTERM) are forwarded correctly.
#   - The container exits cleanly when Tomcat shuts down.
# -----------------------------------------------------------------------------
CMD ["catalina.sh", "run"]
