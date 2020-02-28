# Update Plugin List

To update the plugin versions use the `generate.groovy` script to generate an updated list of plugins with dependencies based on the latest Update Site.

Usage:
```groovy
groovy generate.groovy <pluginsListFile> [outputFormat]
    outputFormat  -cwp    Custom War Packager packager-config.yml format (default)
                  -list   Simple list of plugin names
```

e.g. `groovy generate.groovy "../jenkinsfile-runner-base-image/plugins.txt" -cwp`

will produce:
```yaml
# AnsiColor (Jenkins-Version: 2.145)
  - groupId: "org.jenkins-ci.plugins"
    artifactId: "ansicolor"
    source:
      version: "0.6.2"
# Pipeline: API (Jenkins-Version: 2.138.4)
  - groupId: "org.jenkins-ci.plugins.workflow"
    artifactId: "workflow-api"
    source:
      version: "2.34"
# Pipeline: Step API (Jenkins-Version: 2.121.1)
  - groupId: "org.jenkins-ci.plugins.workflow"
    artifactId: "workflow-step-api"
    source:
      version: "2.19"
# Structs (Jenkins-Version: 2.60.3)
  - groupId: "org.jenkins-ci.plugins"
    artifactId: "structs"
    source:
      version: "1.19"
[...]
```

This can be copied/pasted into the `plugins` section of a [Custom War Packager] `packager-config.yml`.


[Custom War Packager]: https://github.com/jenkinsci/custom-war-packager