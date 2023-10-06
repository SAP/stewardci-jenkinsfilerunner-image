import java.util.logging.Level
import java.util.logging.Logger

// Allow undefined parameters in pipeline
System.setProperty("hudson.model.ParametersAction.keepUndefinedParameters", "true")

// Silence org.komamitsu.fluency.Fluency because it logs an error if the buffer is full,
// which happens very often in our scenario.
Logger.getLogger("org.komamitsu.fluency.Fluency").setLevel(Level.OFF)
