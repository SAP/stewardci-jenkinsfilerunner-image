## Build

Build the image using the `./build.sh`

## Plugin versions

The [packager-config.yml](packager-config.yml) also contains the list of plugins to install. Creating the list manually, with groupId, artifactId, version of any plugin and the transitive dependencies, is very cumbersome.

Below you find ways to generate this list.

### Plugins from existing Jenkins

From the Script Console of a running Jenkins execute the following script to get the list of all installed plugins, preformatted for the `packager-config.yml`.

```groovy
import com.cloudbees.groovy.cps.NonCPS

printPlugins(Jenkins.instance.pluginManager.plugins)
true

@NonCPS
def printPlugins(plugins) {
    def JENKINS_HOME = System.getenv('JENKINS_HOME')

    def pluginsDir

    if (new File("${JENKINS_HOME}/plugins").exists()) {
        pluginsDir = "${JENKINS_HOME}/plugins"
    } else if (new File("/usr/share/jenkins/ref/plugins").exists()) {
        pluginsDir = "/usr/share/jenkins/ref/plugins"
    } else {
        throw new RuntimeException("Could not determine plugins directory.")
    }

    plugins.toSorted {
        a, b -> a.shortName <=> b.shortName
    }.each {
        plugin ->
            def groupId
            def manifestFile = new File("${pluginsDir}/${plugin.shortName}/META-INF/MANIFEST.MF")
            manifestFile.withInputStream { mfStream ->
                def manifest = new java.util.jar.Manifest(mfStream)
                groupId = manifest.mainAttributes.getValue("Group-Id")
            }
            println("""\
  - groupId: "${groupId}"
    artifactId: "${plugin.shortName}"
    source:
      version: "${plugin.version}\"""")
    }
}
```
