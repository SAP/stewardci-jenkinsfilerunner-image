## Build

Build the image using the `./build.sh`

## Plugin versions

The [packager-config.yml](packager-config.yml) also contains the list of plugins to install. Creating the list manually, with groupId, artifactId, version of any plugin and the transitive dependencies, is very cumbersome.

Below you find ways to generate this list.

### Plugins from existing Jenkins

From the `script console` of a running Jenkins execute the following script to get the list of all installed plugins, preformatted for the `packager-config.yml`.

```groovy
def JENKINS_HOME = System.getenv('JENKINS_HOME')

Jenkins.instance.pluginManager.plugins.toSorted {
  a, b -> a.shortName <=> b.shortName
}
.each {
  plugin ->
  def groupId
  def manifestFile = new File(JENKINS_HOME, "plugins/${plugin.shortName}/META-INF/MANIFEST.MF")
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
true
```
