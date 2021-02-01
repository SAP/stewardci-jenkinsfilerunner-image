# Developer documentation

### Build process

Our Jenkinsfile Runner Image is being built in two steps.

## jenkinsfile-runner-base-image

The `jenkinsfile-runner-base-image` folder contains all the configuration files which are used by the Jenkins [Custom WAR Packager] to build an intermediate Docker image containing:

- [Jenkins base image](jenkinsfile-runner-base-image/packager-config.yml#L21)
- [Jenkins.war](jenkinsfile-runner-base-image/packager-config.yml#L25)
- [Jenkins plugins](jenkinsfile-runner-base-image/packager-config.yml#L46)
- [Configuration as Code](jenkinsfile-runner-base-image/casc.yml)

## jenkinsfile-runner-steward-image

The `jenkinsfile-runner-steward-image` folder contains a Dockerfile which defines to [copy](jenkinsfile-runner-steward-image/Dockerfile#L19)
the required files from the intermediate image (from the previous step) to the finally used [adoptopenjdk base image](jenkinsfile-runner-steward-image/Dockerfile#L3).

## Development Process

To update the Jenkins version and the plugin versions simply call the [update.sh](update.sh) script, which will utilize the scripts from the [update/](update) folder.

The file [jenkinsfile-runner-base-image/plugins.txt](jenkinsfile-runner-base-image/plugins.txt) defines the plugins we require.
The [update/updatePlugins.sh](update/updatePlugins.sh) reads this plugins list and updates the [technical dependencies](jenkinsfile-runner-base-image/packager-config.yml#L61)
to those plugins, including all required transitive dependencies.


[Custom WAR Packager]: https://github.com/jenkinsci/custom-war-packager
[Jenkinsfile Runner]: https://github.com/jenkinsci/jenkinsfile-runner
[Jenkins]: https://github.com/jenkinsci/jenkins
