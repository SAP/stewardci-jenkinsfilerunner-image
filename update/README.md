# Update Plugin List

To update the plugin versions use the `generate.groovy` script to generate an updated list of plugins with dependencies based on the latest Update Site.

Usage:
```groovy
Usage: groovy generate.groovy <pluginsListFile> <outputFormat> [--skip-optional]
    pluginsListFile         Path to a file with plugin names (new line separated) of wanted plugins
    outputFormat    -cwp    Custom War Packager packager-config.yml format (default)
                    -list   Simple list of plugin names
                    -tree   Print the dependency tree of each plugin
    --skip-optional         Do not include optional plugin dependencies
```

e.g. `groovy generate.groovy "../jenkinsfile-runner-base-image/plugins.txt" -cwp --skip-optional`

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

This can be copied/pasted into the `plugins` section of a [Custom War Packager] `packager-config.yml`. Or better run the `update.sh` in the project root folder.

To print the dependency tree run e.g.
```sh
groovy generate.groovy "../jenkinsfile-runner-base-image/plugins.txt" -tree --skip-optional`
```


[Custom War Packager]: https://github.com/jenkinsci/custom-war-packager