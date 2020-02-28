import groovy.json.JsonSlurper
import groovy.json.JsonOutput

wantedPlugins = [:]
resultingPlugins = [:]
updateCenter = null
debug = false

if(args.length == 1) {
    process(args[0], "-cwp")
} else if(args.length >= 2) {
    if(args[1] == "-cwp" || args[1] == "-list" || args[1] == "-tree") {
        skipOptional = (args.length == 3 && args[2] == "--skip-optional")
        process(args[0], args[1], skipOptional)
    } else {
        println("Unknown argument " + args[1])
    }
} else {
    println "Usage: groovy generate.groovy <pluginsListFile> <outputFormat> [--skip-optional]"
    println "    pluginsListFile         Path to a file with plugin names (new line separated) of wanted plugins"
    println "    outputFormat    -cwp    Custom War Packager packager-config.yml format (default)"
    println "                    -list   Simple list of plugin names"
    println "                    -tree   Print the dependency tree of each plugin"
    println "    --skip-optional         Do not include optional plugin dependencies"
    println ""
    println "e.g. groovy generate.groovy plugins.txt -cwp"
}

def process(wantedPluginsFile, outFormat, skipOptional) {
    def wantedPluginNames = []
    String fileContents = new File(wantedPluginsFile).getText('UTF-8').eachLine { line ->
        wantedPluginNames << line
    }

    def url = "https://updates.jenkins.io/update-center.json".toURL()
    def updateCenterJson = url.text
    updateCenterJson = updateCenterJson.substring(0, updateCenterJson.length()-2)
    updateCenterJson = updateCenterJson.replace("updateCenter.post(", "")
    updateCenterJson = updateCenterJson.trim()

    def jsonSlurper = new JsonSlurper()
    updateCenter = jsonSlurper.parseText(updateCenterJson)

    for(wanted in wantedPluginNames){
        def wantedPlugin = updateCenter.plugins[wanted]
        wantedPlugins[wantedPlugin.name] = wantedPlugin
        resultingPlugins[wantedPlugin.name] = wantedPlugin
        if(debug) println "Added: " + wantedPlugin.name
        addDependencies(wantedPlugin, skipOptional)
    }

    if(outFormat == "-list") {
        for(plugin in resultingPlugins.values()){
            println plugin.name
        }
    }

    if(outFormat == "-cwp") {
        for(pluginKey in resultingPlugins.sort()*.key){
            plugin = resultingPlugins[pluginKey]
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

    if(outFormat == "-tree") {
        for(pluginKey in wantedPlugins.sort()*.key){
            plugin = wantedPlugins[pluginKey]
            printDependencyTree(plugin, 0, "wanted")
        }
        println("--- Statistics -------------------------")
        println("Wanted plugins:    " + wantedPlugins.size())
        println("Resulting plugins: " + resultingPlugins.size())
    }

}

def addDependencies(plugin, skipOptional) {
    //println "addDependencies(" + plugin + ")"
    for(dependency in plugin.dependencies){
        if(skipOptional && dependency.optional) {
            continue;
        }
        def dependencyPlugin = updateCenter.plugins[dependency.name]
        if(dependencyPlugin) {
            resultingPlugins[dependency.name] = dependencyPlugin
            if(debug) println "Added dependency (of " + plugin.name + "): " + dependencyPlugin.name
            addDependencies(dependencyPlugin, skipOptional)
        } else {
            if(dependency.optional) {
                println "ERROR: Could not find (optional) dependency " + dependency
            } else {
                throw new RuntimeException("Could not find (required) dependency " + dependency)
            }
        }
    }
}

def printDependencyTree(plugin, indent, type) {
    if(indent == 0) {
        print "- "
    } else {
        for(i = 0; i < indent; i++) {
            print "  "
        }
    }
    println plugin.name + ":" + plugin.version + " (" + type + ")"
    for(dependency in plugin.dependencies){
        dependencyPlugin = resultingPlugins[dependency.name]
        if(dependencyPlugin == null) {
            if(!dependency.optional) throw new RuntimeException(dependency.name + " (required) not contained in resultingPlugins")
        } else {
            printDependencyTree(dependencyPlugin, indent+1, dependency.optional ? "optional" : "required")
        }
    }
}
