"""
This package provides a framework for generic message logging.

## Goals
I designed this library with the following goals in mind:

 - Flexible: it should cover a wide variety of use cases
 - Abstract usage: libraries that want to log shouldn't need to know or care
about implementation details
 - Actors: take advantage of actors, the message passing structure is perfect
for this!

The library makes heavy use of traits to allow for using custom formatting,
backends, and even log levels.

## Usage
Here is an example you can start with:

```pony
use "logging"
// The logging library itself doesn't provide any backends,
// so we have to add at least one to make it useful
use "logging-outstream"

actor Main
	new create(env: Env) =>
		// This is the logging actor itself.
		// It can control backends for you.
		// On creation though, there are no backends.
		let log = Logging

		// This backend logs to an OutStream,
		// which can be stdout or stderr.
		let log_outstream = LoggingOutStream(env.out)
		log.append_backend(log_outstream)

		// Enable log levels we care about.
		log.enable_levels([Error; Warn; Info])

		// That is all the setup needed to log something.
		log.info("Hello World!", NoSource)

		// You might want a different formatter though:
		log.set_formatter(LogPrettyANSIFormatter)
		log.set_formatting_preference(true)

		// Or to suppress a source from being logged:
		log.exclude_source(NoSource)
```
"""

trait LogLevel
	"""
	The log level for a log message.

	There are a number of log levels already defined in this library, and they
	should usually be enough. However, if you find that you need more
	granularity, implementing this trait allows you to easily define more log
	levels that can be used exactly like the ones already defined. In fact, if
	you want to define your own LogLevel, the source for the pre-defined
	LogLevels are a great place to look for an example.

	## Usage
	Here is an example of how to implement this trait:

	```pony
	primitive MyLevel is LogLevel
		fun tag log_level_name(): String => "My Level"
		fun box eq(that: box->LogLevel): Bool =>  that is MyLevel
	```
	"""
	fun val log_level_name(): String
	fun box eq(that: box->LogLevel): Bool
	fun box ne(that: box->LogLevel): Bool => not eq(that)

primitive Error is LogLevel
	"""
	This LogLevel indicates that an error occurred.

	By convention, an error is usually (though not always) fatal. An error may
	or may not be caused by user error (like an invalid input) or program error
	(like failing to open a TCP connection).
	"""
	fun tag log_level_name(): String => "Error"
	fun box eq(that: box->LogLevel): Bool => that is Error
primitive Warn is LogLevel
	"""
	This LogLevel indicates a warning that should be considered.

	By convention, a warning is not fatal, but may indicate issues that are
	known to cause error. A warning may be for the developer (like using
	deprecated functions) or for the user (like an unexpected input).
	"""
	fun tag log_level_name(): String => "Warn"
	fun box eq(that: box->LogLevel): Bool => that is Warn
primitive Info is LogLevel
	"""
	This LogLevel indicates info that may be useful.

	This level is often used for operation or runtime details. Info often isn't
	necessary to read, but may be helpful to understand code state later if
	something does go wrong.
	"""
	fun tag log_level_name(): String => "Info"
	fun box eq(that: box->LogLevel): Bool => that is Info
primitive Debug is LogLevel
	"""
	This LogLevel indicates debugging information.

	This level is usually reserved for information that is never useful unless
	debugging. For example, it might contain details about code paths or state
	information.
	"""
	fun tag log_level_name(): String => "Debug"
	fun box eq(that: box->LogLevel): Bool => that is Debug
primitive Trace is LogLevel
	"""
	This LogLevel indicates code tracing information.

	This level is used for the most verbose logging. It can be used for logging
	variable states or steps in a function. This level is almost never useful
	for anyone except developers.
	"""
	fun tag log_level_name(): String => "Trace"
	fun box eq(that: box->LogLevel): Bool => that is Trace

trait LoggingSource
	"""
	The source for a log message.

	The `logging_source` method takes a `val`, which enables you do do something
	like include the file name and line number this log message came from. In
	this case, `eq` should probably *not* check for structural equality, only
	that the type is equal. Otherwise, you would need to filter every possible
	version of the log source, which might not be desired.

	## Usage
	Here is an example of how to implement this trait:

	```pony
	primitive MySource is LoggingSource
		fun tag logging_source(): String => "My Source"
		fun box eq(that: box->LogSource): Bool => that is MySource
	```
	"""
	fun val logging_source(): String
	fun box eq(that: box->LogSource): Bool
	fun box ne(that: box->LogSource): Bool => not eq(that)

primitive NoSource
	"""
	A special source value that indicates no particular source.

	This value may be treated by formatters as unknown, unavailable, or not
	applicable. Like other sources, this "source" can be filtered.
	"""
	fun box eq(that: box->LogSource): Bool =>
		match that
		|	let no_source: NoSource => true
		else false end
	
	fun box ne(that: box->LogSource): Bool => not eq(that)

type LogSource is (LoggingSource val | NoSource val)

primitive LogSourceFilterBlacklist
	"""
	Indicates that the filter is an array of sources to exclude or blacklist.
	"""

primitive LogSourceFilterWhitelist
	"""
	Indicates that the filter is an array of sources to include or whitelist.
	"""

class LogSourceFilter
	var filter: Array[LogSource] ref = []
		"""
		The filter array.
		"""

	var mode: (LogSourceFilterBlacklist | LogSourceFilterWhitelist)
		"""
		Indicates whether this filter is inclusive or exclusive.
		"""

	new create(log_filter: Array[LogSource] ref^, filter_mode: (LogSourceFilterBlacklist | LogSourceFilterWhitelist)) =>
		"""
		Return a LogSourceFilter from the given parts.
		"""
		filter = log_filter
		mode = filter_mode

	new create_with_mode(filter_mode: (LogSourceFilterBlacklist | LogSourceFilterWhitelist)) =>
		"""
		Return an empty LogSourceFilter with the given filter mode.
		"""
		mode = filter_mode

	fun box eq(that: box->LogSourceFilter): Bool =>
		let this_values = filter.values()
		let that_values = that.filter.values()
		var this_value = None
		var that_value = None

		while true do
			if this_values.has_next() != that_values.has_next() then
				return false
			end

			if not this_values.has_next() then break end

			try
				if this_values.next()? != that_values.next()? then return false end
			else
				// This should be unreachable.
				return false
			end
		end

		match mode
		|	let exclusive: LogSourceFilterBlacklist =>
			match that.mode
			|	let e: LogSourceFilterBlacklist => true
			|	let i: LogSourceFilterWhitelist => false
			end
		|	let inclusive: LogSourceFilterWhitelist =>
			match that.mode
			|	let e: LogSourceFilterBlacklist => false
			|	let i: LogSourceFilterWhitelist => true
			end
		end

	fun box clone(): LogSourceFilter ref^ =>
		create(filter.clone(), mode)

	fun ref include_source(source: LogSource) =>
		"""
		Include the given LogSource if it is not already included.

		If this LogSourceFilter is exclusive, this removes the source from the
		filter array if it is there. If it is inclusive, this adds it to the
		filter array if it is not there.

		Note that `None` counts as its own source and, if you want to include
		it, you need to add it to the filter explicitly like any other source.
		"""
		match mode 
		|	let exclusive: LogSourceFilterBlacklist =>
			if filter.contains(source, {(l, r) => l == r}) then
				let new_filter: Array[LogSource] ref = []
				var updated = false

				for filtered_source in filter.values() do
					if filtered_source != source then
						new_filter.push(filtered_source)
						updated = true
					end
				end

				if updated then filter = new_filter end
			end
		|	let inclusive: LogSourceFilterWhitelist =>
			if not filter.contains(source, {(l, r) => l == r}) then
				filter.push(source)
			end
		end

	fun ref exclude_source(source: LogSource) =>
		"""
		Exclude the given LogSource if it is not already excluded.

		If this LogSourceFilter is exclusive, this adds the source to the filter
		array if it is not there. If it is inclusive, this removes it from the
		filter array if it is there.

		Note that `None` counts as its own source and, if you want to exclude
		it, you need to add it to the filter explicitly like any other source.
		"""
		match mode 
		|	let exclusive: LogSourceFilterBlacklist =>
			if not filter.contains(source, {(l, r) => l == r}) then
				filter.push(source)
			end
		|	let inclusive: LogSourceFilterWhitelist =>
			if filter.contains(source, {(l, r) => l == r}) then
				let new_filter: Array[LogSource] ref = []
				var updated = false

				for filtered_source in filter.values() do
					if filtered_source != source then
						new_filter.push(filtered_source)
						updated = true
					end
				end

				if updated then filter = new_filter end
			end
		end

	fun box is_filtered(source: LogSource): Bool =>
		"""
		Check if the given LogSource is denied by this filter.
		"""
		match mode
		|	let exclusive: LogSourceFilterBlacklist =>
			filter.contains(source, {(l, r) => l == r})
		|	let inclusive: LogSourceFilterWhitelist =>
			not filter.contains(source, {(l, r) => l == r})
		end

actor Logging
	var _backends: Array[LoggingBackend tag] ref = []

	be append_backend(backend: LoggingBackend tag) =>
		"""
		Append a single backend to the list of backends to use.
		"""
		_backends.push(backend)

	be set_backends(backends: Array[LoggingBackend tag] val) =>
		"""
		Set a new array of backends to use.
		"""
		_backends = backends.clone()

	be set_levels(levels: Array[LogLevel val] val) =>
		"""
		Set the enabled logging levels recursively for all backends.
		"""
		for backend in _backends.values() do
			backend.set_levels(levels)
		end

	be enable_levels(levels: Array[LogLevel val] val) =>
		"""
		Enable the given logging levels recursively for all backends, if they
		were not already enabled.
		"""
		for backend in _backends.values() do
			backend.enable_levels(levels)
		end

	be disable_levels(levels: Array[LogLevel val] val) =>
		"""
		Disable the given logging levels recursively for all backends, if they
		were enabled.
		"""
		for backend in _backends.values() do
			backend.disable_levels(levels)
		end

	be set_source_filter(filter: LogSourceFilter val) =>
		"""
		Set the source filters in use recursively for all backends.
		"""
		for backend in _backends.values() do
			backend.set_source_filter(filter)
		end

	be include_source(source: LogSource val) =>
		"""
		Include the given LogSource recursively for all backends if they did not
		already include it.

		Filtered sources will not be logged. Note that `NoSource` counts as its
		own source and, if you want to include it, you need to do this
		explicitly like any other source.
		"""
		for backend in _backends.values() do
			backend.include_source(source)
		end

	be exclude_source(source: LogSource val) =>
		"""
		Exclude the given LogSource recursively for all backends if they did not
		already exclude it.

		Filtered sources will not be logged. Note that `NoSource` counts as its
		own source and, if you want to exclude it, you need to do this
		explicitly like any other source.
		"""
		for backend in _backends.values() do
			backend.exclude_source(source)
		end

	be set_formatter(formatter: LogFormatter val) =>
		"""
		Set the logging formatter recursively for all backends.
		"""
		for backend in _backends.values() do
			backend.set_formatter(formatter)
		end
	
	be set_formatting_preference(preference: Bool) =>
		"""
		Set the formatting preference recursively for all backends.

		This is a hint for whether special formatting can be used. How this is
		implemented is up to the formatter.
		
		Setting a formatting preference doesn't guarantee formatting is used. If
		a backend does not support formatting, the formatter will be instructed
		not to use formatting regardless of any preference indicated by this
		function.
		"""
		for backend in _backends.values() do
			backend.set_formatting_preference(preference)
		end

	be err(message: String val, source: LogSource) =>
		"""
		Log a message with the Error level.
		"""
		for backend in _backends.values() do
			backend.log(Error, message, source)
		end

	be warn(message: String val, source: LogSource) =>
		"""
		Log a message with the Warn level.
		"""
		for backend in _backends.values() do
			backend.log(Warn, message, source)
		end

	be info(message: String val, source: LogSource) =>
		"""
		Log a message with the Info level.
		"""
		for backend in _backends.values() do
			backend.log(Info, message, source)
		end

	be debug(message: String val, source: LogSource) =>
		"""
		Log a message with the Debug level.
		"""
		for backend in _backends.values() do
			backend.log(Debug, message, source)
		end

	be trace(message: String val, source: LogSource) =>
		"""
		Log a message with the Trace level.
		"""
		for backend in _backends.values() do
			backend.log(Trace, message, source)
		end

	be log(level: LogLevel val, message: String val, source: LogSource) =>
		"""
		Log a message with the given level.
		"""
		for backend in _backends.values() do
			backend.log(level, message, source)
		end

trait LoggingBackend
	"""
	This is the main interface you'll want to implement to use a custom
	backend.

	## Usage
	For an example of how to implement this trait, see the
	logging-backend-outstream package.

	Backends are normally intended to be used via the Logging actor, but
	backends themselves have a very similar interface. This can be used to give
	backends different configurations (different enabled levels, filters,
	formatters) or to manually log to a backend without logging to all backends.

	See the public behaviors on this trait for information on what each one
	does.
	"""

	fun box _logging_levels(): Array[LogLevel val] box
		"""
		Get the enabled LogLevels for this LoggingBackend.
		"""

	fun ref _logging_set_levels(log_levels: Array[LogLevel val] ref^)
		"""
		Set the enabled LogLevels for this LoggingBackend.
		"""

	fun box _logging_source_filter(): LogSourceFilter box
		"""
		Get the LogSourceFilter for this LoggingBackend.
		"""

	fun ref _logging_set_source_filter(log_source_filter: LogSourceFilter box)
		"""
		Set the LogSourceFilter for this LoggingBackend.
		"""
	be set_levels(log_levels: Array[LogLevel val] val) =>
		"""
		Set the LogLevels that will be logged for this LoggingBackend.
		
		This does *not* set the maximum log level - if you want
		to include log levels down to Info, you need to set the levels to
		`[Info, Warn, Error]`.
		"""
		_logging_set_levels(log_levels.clone())

	be enable_levels(log_levels: Array[LogLevel val] val) =>
		"""
		Enables the LogLevels in the given array if they are not already
		enabled.
		
		This does *not* change the maximum log level - if you want
		to include log levels down to Info, you need to enable the levels
		`[Info, Warn, Error]`.
		"""
		let existing_log_levels: Array[LogLevel val] box = _logging_levels()
		let new_log_levels: Array[LogLevel val] ref = existing_log_levels.clone()
		var updated = false

		for level in log_levels.values() do
			if not existing_log_levels.contains(level, {(l, r) => l == r}) then
				new_log_levels.push(level)
				updated = true
			end
		end

		if updated then _logging_set_levels(new_log_levels) end

	be disable_levels(log_levels: Array[LogLevel val] val) =>
		"""
		Disables the LogLevels in the given array if they are enabled.
		"""
		let existing_log_levels: Array[LogLevel val] box = _logging_levels()
		let new_log_levels: Array[LogLevel val] ref = []
		var updated = false

		for level in existing_log_levels.values() do
			if not log_levels.contains(level, {(l, r) => l == r}) then
				new_log_levels.push(level)
				updated = true
			end
		end

		if updated then _logging_set_levels(new_log_levels) end

	be set_source_filter(source_filter: LogSourceFilter val) =>
		"""
		Set the LogSourceFilter in use for this LoggingBackend.

		Filtered sources will not be logged. Note that `None` counts as its own
		source and, if you want to include (or exclude) it, you need to
		explicitly add it to this array.
		"""
		_logging_set_source_filter(source_filter)

	be include_source(source: LogSource)
		"""
		Include the given LogSource if it is not already included.

		If the LogSourceFilter is Exclude, this removes it from the Exclude list
		if it is there. If it is Include, this adds it to the Include list if it
		is not there.

		Filtered sources will not be logged. Note that `NoSource` counts as its
		own source and, if you want to include it, you need to do this
		explicitly like any other source.
		"""

	be exclude_source(source: LogSource)
		"""
		Exclude the given LogSource if it is not already excluded.

		If the LogSourceFilter is Exclude, this adds it to the Exclude list if
		it is not there. If it is Include, this removes it from the Include list
		if it is there.

		Filtered sources will not be logged. Note that `NoSource` counts as its
		own source and, if you want to exclude it, you need to do this
		explicitly like any other source.
		"""

	be set_formatter(formatter: LogFormatter val)
		"""
		Set the LogFormatter for this LoggingBackend.
		
		The LoggingBackend might not actually use the LogFormatter. See the
		LoggingBackend's documentation for more detail.
		"""
	
	be set_formatting_preference(preference: Bool)
		"""
		Set the formatting preference for this LoggingBackend.

		This is a hint for whether special formatting can be used. How this is
		implemented is up to the formatter.
		
		Setting a formatting preference doesn't guarantee formatting is used. If
		this backend does not support formatting, the formatter will be
		instructed not to use formatting regardless of any preference indicated
		by this function.
		"""

	be log(level: LogLevel val, message: String val, source: LogSource)
		"""
		Log a message from the given LogSource at the given LogLevel with this
		LoggingBackend.
		"""

interface LogFormatter
	"""
	This is the main interface you'll want to implement for custom formatting.
	
	The `formatting` Bool hints at whether special formatting can be used by the
	formatter. How this is implemented is up to the formatter.

	## Usage
	Here is a basic example of how to implement this interface:

	```pony
	primitive ExampleFormatter
		fun val log_format(level: LogLevel val, message: String val, source: LogSource, formatting: Bool): String =>
			// This will return a string in the format:
			// `Log Source, Log Level: Your message here`
			// `Log Level: Message without a source`
			recover
				let out = String
				match source
				|	let s: LoggingSource val =>
					out.append(s.logging_source())
					out.append(", ")
				end
				out.append(level.log_level_name())
				out.append(": ")
				out.append(message)
				out
			end
	```

	There are more interesting examples in this package - see LogBasicFormatter
	and LogPrettyANSIFormatter.

	Using a LogFormatter can be done like this:

	```pony
	// Will log the message "Hello World!"
	// at the Info level
	// from the NoSource source
	// with special formatting enabled
	my_formatter.log_format(Info, "Hello World!", NoSource, true)
	```

	Though, usually you won't be using formatters directly.
	"""
	fun val log_format(level: LogLevel val, message: String val, source: LogSource, formatting: Bool): String val

primitive LogBasicFormatter
	"""
	A basic formatter.

	Formatter output looks like this:
	
	```text
	[Log Source] Log Level: Your message here
	Log Level: Message without a source
	```
	"""
	fun tag log_format(level: LogLevel val, message: String val, source: LogSource, formatting: Bool): String val =>
		recover
			let out = String
			match source
			|	let s: LoggingSource val =>
				out.append("[")
				out.append(s.logging_source(), 0)
				out.append("] ", 0)
			end
			out.append(level.log_level_name(), 0)
			out.append(": ", 0)
			out.append(message, 0)
			out
		end

primitive LogPrettyANSIFormatter
	"""
	A formatter with more, well, formatting!

	Formatter output looks like this:

	```text
	[Log Level] Log Source: Your message here
	[Log Level] Message without a source
	```

	This formats using ANSI codes. In particular, if formatting is enabled:

	 - The Trace level will be bright cyan
	 - The Debug level will be bright blue
	 - The Info level will be bright green
	 - The Warn level will be yellow
	 - The Error level will be bright red
	 - All other levels will be bright yellow
	 - The source, if it is not `NoSource`, will be bold
	"""
	fun tag log_format(level: LogLevel val, message: String val, source: LogSource, formatting: Bool): String val =>
		recover
			let out = String
			out.append("[", 0)
			if formatting then
				match level
				|	let trace: Trace =>
					out.append("\x1B[96m", 0) // Bright cyan
				|	let debug: Debug =>
					out.append("\x1B[94m", 0) // Bright blue
				|	let info: Info =>
					out.append("\x1B[92m", 0) // Bright green
				|	let warn: Warn =>
					out.append("\x1B[33m", 0) // Yellow
				|	let err: Error =>
					out.append("\x1B[91m", 0) // Bright red
				else
					out.append("\x1B[93m", 0) // Bright yellow
				end
			end
			out.append(level.log_level_name(), 0)
			if formatting then out.append("\x1B[0m", 0) end // Reset formatting
			out.append("] ", 0)
			match source
			|	let s: LoggingSource val =>
				if formatting then out.append("\x1B[1m", 0) end // Bold
				out.append(s.logging_source(), 0)
				if formatting then out.append("\x1B[22m", 0) end // Disable bold
				out.append(": ", 0)
			end
			out.append(message, 0)
			out
		end
