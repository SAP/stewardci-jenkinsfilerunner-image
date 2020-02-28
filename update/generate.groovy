import groovy.json.JsonSlurper
import groovy.json.JsonOutput

resultingPlugins = [:]
updateCenter = null
debug = false

if(args.length == 1) {
    process(args[0], "-cwp")
} else if(args.length == 2) {
    if(args[1] == "-cwp" || args[1] == "-list") {
        process(args[0], args[1])
    } else {
        println("Unknown argument " + args[1])
    }
} else {
    println "Usage: groovy generate.groovy <pluginsListFile> [outputFormat]"
    println "    outputFormat  -cwp    Custom War Packager packager-config.yml format (default)"
    println "                  -list   Simple list of plugin names"
    println ""
    println "e.g. groovy generate.groovy plugins.txt -cwp"
}

def process(wantedPluginsFile, outFormat) {
    def wantedPlugins = []
    String fileContents = new File(wantedPluginsFile).getText('UTF-8').eachLine { line ->
        wantedPlugins << line
    }

    def url = "https://updates.jenkins.io/update-center.json".toURL()
    def updateCenterJson = url.text
    updateCenterJson = updateCenterJson.substring(0, updateCenterJson.length()-2)
    updateCenterJson = updateCenterJson.replace("updateCenter.post(", "")
    updateCenterJson = updateCenterJson.trim()

    def jsonSlurper = new JsonSlurper()
    updateCenter = jsonSlurper.parseText(updateCenterJson)

    for(wanted in wantedPlugins){
        def wantedPlugin = updateCenter.plugins[wanted]
        resultingPlugins[wantedPlugin.name] = wantedPlugin
        if(debug) println "Added: " + wantedPlugin.name
        addDependencies(wantedPlugin)
    }

    if(outFormat == "-list") {
        for(plugin in resultingPlugins.values()){
            println plugin.name
        }
    }

    if(outFormat == "-cwp") {
        for(plugin in resultingPlugins.values()){
            def gav = plugin.gav
            def matcher = gav =~ /([^:]*):([^:]*):([^:]*)/
            if (!matcher) throw new RuntimeException("Wrong gav: " + gav)
            def groupId = matcher.group(1)
            def artifactId = matcher.group(2)
            def version = matcher.group(3)
            println "# " + plugin.title + " (Jenkins-Version: " + plugin.requiredCore + ")"
            println "  - groupId: \"" + groupId + "\""
            println "    artifactId: \"" + artifactId + "\""
            println "    source:"
            println "      version: \"" + version + "\""
        }
    }
}

def addDependencies(plugin) {
    //println "addDependencies(" + plugin + ")"
    for(dependency in plugin.dependencies){
        def dependencyPlugin = updateCenter.plugins[dependency.name]
        if(dependencyPlugin) {
            resultingPlugins[dependency.name] = dependencyPlugin
            if(debug) println "Added dependency (of " + plugin.name + "): " + dependencyPlugin.name
            addDependencies(dependencyPlugin)
        } else {
            if(dependency.optional) {
                println "ERROR: Could not find dependency " + dependency
            } else {
                throw new RuntimeException("Could not find dependency " + dependency)
            }
        }
    }
}
