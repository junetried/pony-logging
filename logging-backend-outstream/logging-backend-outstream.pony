"""
This package defines a LoggingBackend that prints to an OutStream - like stdout
or stderr from Env.
"""

use "../logging"

actor LoggingOutStream is LoggingBackend
	"""
	This simple Logging backend prints to an OutStream, such as stdout or
	stderr.
	"""
	let _outstream: OutStream tag
	var _levels: Array[LogLevel val] ref = []
	var _source_filter: LogSourceFilter ref
	var _formatter: LogFormatter val = LogBasicFormatter
	var _formatting_preference: Bool = false

	new create(outstream: OutStream tag) =>
		_outstream = outstream
		_source_filter = LogSourceFilter.create_with_mode(LogSourceFilterBlacklist)

	fun box _logging_levels(): Array[LogLevel val] box =>
		_levels

	fun ref _logging_set_levels(log_levels: Array[LogLevel val] ref) =>
		_levels = log_levels

	fun box _logging_source_filter(): LogSourceFilter box =>
		_source_filter

	fun ref _logging_set_source_filter(source_filter: LogSourceFilter box) =>
		_source_filter = source_filter.clone()

	be include_source(source: LogSource) =>
		_source_filter.include_source(source)

	be exclude_source(source: LogSource) =>
		_source_filter.exclude_source(source)

	be set_formatter(formatter: LogFormatter val) =>
		_formatter = formatter
	
	be set_formatting_preference(preference: Bool) =>
		_formatting_preference = preference

	be log(level: LogLevel val, message: String val, source: LogSource) =>
		if _levels.contains(level, {(l, r) => l == r}) and not _source_filter.is_filtered(source) then
			_outstream.print(_formatter.log_format(level, message, source, _formatting_preference))
		end
