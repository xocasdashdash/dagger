package engine

import (
	"list"
)

// Upload a container image to a remote repository
#Push: {
	$dagger: task: _name: "Push"

	// Target repository address
	dest: #Ref

	// Filesystem contents to push
	input: #FS

	// Container image config
	config: #ImageConfig

	// Authentication
	auth?: {
		username: string
		secret:   #Secret
	}

	// Complete ref of the pushed image, including digest
	result: #Ref
}

// A ref is an address for a remote container image
//
// Examples:
//   - "index.docker.io/dagger"
//   - "dagger"
//   - "index.docker.io/dagger:latest"
//   - "index.docker.io/dagger:latest@sha256:a89cb097693dd354de598d279c304a1c73ee550fbfff6d9ee515568e0c749cfe"
#Ref: string

// Container image config. See [OCI](https://www.opencontainers.org/).
#ImageConfig: {
	user?: string
	expose?: [string]: {}
	env?: [string]: string
	entrypoint?: [...string]
	cmd?: [...string]
	volume?: [string]: {}
	workdir?: string
	label?: [string]: string
	stopsignal?:  string
	healthcheck?: #HealthCheck
	argsescaped?: bool
	onbuild?: [...string]
	stoptimeout?: int
	shell?: [...string]
}

#HealthCheck: {
	test?: [...string]
	interval?:    int
	timeout?:     int
	startPeriod?: int
	retries?:     int
}

// Download a container image from a remote repository
#Pull: {
	$dagger: task: _name: "Pull"

	// Repository source ref
	source: #Ref

	// Authentication
	auth?: {
		username: string
		secret:   #Secret
	}

	// Root filesystem of downloaded image
	output: #FS

	// Image digest
	digest: string

	// Downloaded container image config
	config: #ImageConfig
}

// Build a container image using a Dockerfile
#Dockerfile: {
	$dagger: task: _name: "Dockerfile"

	// Source directory to build
	source: #FS

	dockerfile: *{
		path: string | *"Dockerfile"
	} | {
		contents: string
	}

	// Authentication
	auth: [registry=string]: {
		username: string
		secret:   #Secret
	}

	platforms?: [...string]
	target?: string
	buildArg?: [string]: string
	label?: [string]:    string
	hosts?: [string]:    string

	// Root filesystem produced
	output: #FS

	// Container image config produced
	config: #ImageConfig
}

// Change image config
#Set: {
	// The source image config
	input: #ImageConfig

	// The config to merge
	config: #ImageConfig

	// Resulting config
	output: #ImageConfig & {
		let structs = ["env", "label", "volume", "expose"]
		let lists = ["onbuild"]

		// doesn't exist in config, copy away
		for field, value in input if config[field] == _|_ {
			"\(field)": value
		}

		// only exists in config, just copy as is
		for field, value in config if input[field] == _|_ {
			"\(field)": value
		}

		// these should exist in both places
		for field, value in config if input[field] != _|_ {
			"\(field)": {
				// handle structs that need merging
				if list.Contains(structs, field) {
					_#mergeStructs & {
						#a: input[field]
						#b: config[field]
					}
				}

				// handle lists that need concatenation
				if list.Contains(lists, field) {
					list.Concat([
						input[field],
						config[field],
					])
				}

				// replace anything else
				if !list.Contains(structs+lists, field) {
					value
				}
			}
		}
	}
}

// Merge two structs by overwriting or adding values
_#mergeStructs: {
	// Struct with defaults
	#a: [string]: _

	// Struct with overrides
	#b: [string]: _
	{
		// FIXME: we need exists() in if because this matches any kind of error (cue-lang/cue#943)
		// add anything not in b
		for field, value in #a if #b[field] == _|_ {
			"\(field)": value
		}

		// safely add all of b
		for field, value in #b {
			"\(field)": value
		}
	}
}
