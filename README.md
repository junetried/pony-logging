# pony-logging
This repository contains the `logging`, `logging-backend-outstream`, and
`logging-formatter-time` packages.

## Using
To use this library:

- [Install corral](https://github.com/ponylang/corral/blob/main/README.md#installation)
(This may be easiest to do with [ponyup](https://github.com/ponylang/ponyup))
- [Set up your project](https://github.com/ponylang/corral/blob/main/README.md#getting-started-using-corral)
using corral
- Add this project to your corral bundle as a dependency:
`corral add https://github.com/junetried/pony-logging.git --version 0.1.0`
- Fetch the dependency:
`corral fetch`
- `use` it in your project by adding the following line:
`use "logging"`
- Finally, build your project using corral:
`corral run -- ponyc`

# logging
A logging library for Pony.

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

See [the documentation](https://strangejune.xyz/archive/pony/logging--index/)
and source code for more details.
