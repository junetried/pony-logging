"""
This package contains multiple definitions for LogFormatters that use the `time`
package to display system time.

Note that all instances of the phrase "system time" in this package refer to the
system clock time *at the time of this formatter being called.* Because the
logging library uses actors, and because actors are threaded, this may not
necessarily be the same time that a `log()` was called. How far apart these
times actually are depends on a lot of factors, like how busy the Pony scheduler
is and how busy the operating system is.

None of these formatters are monotonic - if the system time changes, these
formatters will reflect the change and display a time that might be confusing
or less useful.
"""

use "../logging"
use "time"

class TimeFormatter
	"""
	A formatter that shows the wall clock time in seconds.

	Formatter output looks like this:

	```text
	[678345.012] [Log Level] Log Source: Your message here
	[678345.012] [Log Level] Message without a source
	```

	Note that this formatter is *not* monotonic. If the system time changes,
	this formatter will display a time that reflects the change. This can result
	in the time logged appearing to jump backwards or forwards.
	"""
	let hundredths: Bool

	new create(display_hundredths: Bool) =>
		hundredths = display_hundredths

	fun box log_format(level: LogLevel val, message: String val, source: LogSource, formatting: Bool): String =>
		recover
			let out = String
			out.append("[")
			let now = Time.now()
			out.append(now._1.string())
			if hundredths then
				out.append(".")
				let nanos_f = (now._2 / 1_000_000).string()
				var nanos_len = nanos_f.size()
				while nanos_len < 3 do
					out.append("0")
					nanos_len = nanos_len + 1
				end
				out.append(consume nanos_f)
			end
			out.append("] [")
			out.append(level.log_level_name())
			out.append("] ")
			match source
			|	let s: LoggingSource val =>
				out.append(s.logging_source())
				out.append(": ")
			end
			out.append(message)
			out
		end

class RelativeTimeFormatter
	"""
	A formatter that shows the difference in seconds between the current system
	time and the system time at time of its creation.

	Formatter output looks like this:

	```text
	[12.345] [Log Level] Log Source: Your message here
	[12.345] [Log Level] Message without a source
	```

	Note that this formatter is *not* monotonic. If the system time changes,
	this formatter will display a time that reflects the change. This can result
	in the time logged appearing to jump backwards or forwards. If the system
	time is changed to before this RelativeTimeFormatter was created, the
	relative time will appear negative.
	"""
	let _creation_secs: I64
	let _creation_nanos: I64
	let hundredths: Bool

	new create(display_hundredths: Bool) =>
		let now = Time.now()
		_creation_secs = now._1
		_creation_nanos = now._2
		hundredths = display_hundredths

	fun box log_format(level: LogLevel val, message: String val, source: LogSource, formatting: Bool): String =>
		recover
			let out = String
			out.append("[")
			let now = Time.now()
			let diff = difference(now._1, now._2)
			out.append(diff._1.string())
			if hundredths then
				out.append(".")
				let nanos_f = (diff._2 / 1_000_000).string()
				var nanos_len = nanos_f.size()
				while nanos_len < 3 do
					out.append("0")
					nanos_len = nanos_len + 1
				end
				out.append(consume nanos_f)
			end
			out.append("] [")
			out.append(level.log_level_name())
			out.append("] ")
			match source
			|	let s: LoggingSource val =>
				out.append(s.logging_source())
				out.append(": ")
			end
			out.append(message)
			out
		end

	fun box difference(secs: I64, nanos: I64): (I64, I64) =>
		"""
		Returns the difference between the given time and this
		RelativeTimeFormatter's recorded time.
		"""
		// I am *not* very good at math.
		// It *looks* right though.
		// Let's hope I did it right.
		var s = secs - _creation_secs
		var ns = nanos - _creation_nanos
		while nanos < 0 do
			ns = ns + 1_000_000_000
			s = s - 1
		end
		(s, ns)

class StrFTimeFormatter
	"""
	A formatter that shows a strftime formatted system time.

	Formatter output looks like this:

	```text
	[strftime] [Log Level] Log Source: Your message here
	[strftime] [Log Level] Message without a source
	```

	See
	[the strftime manual](https://man7.org/linux/man-pages/man3/strftime.3.html)
	for a list of character sequences you can use.

	Note that this formatter is *not* monotonic. If the system time changes,
	this formatter will display a time that reflects the change. This can result
	in the time logged appearing to jump backwards or forwards.
	"""
	let str: String

	new create(string: String) =>
		str = string

	fun box log_format(level: LogLevel val, message: String val, source: LogSource, formatting: Bool): String =>
		recover
			let out = String
			out.append("[")
			let now = Time.now()
			let date = PosixDate(now._1, now._2)
			try
				out.append(date.format(str)?)
			else
				out.append("FORMATTING ERROR")
			end
			out.append("] [")
			out.append(level.log_level_name())
			out.append("] ")
			match source
			|	let s: LoggingSource val =>
				out.append(s.logging_source())
				out.append(": ")
			end
			out.append(message)
			out
		end
