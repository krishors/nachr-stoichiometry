# ==============================================================================
# File Name:   helpers.sh
# Description: Define useful helper functions
#
# Globals:
#   VERBOSE
#
# Exposed Functions:
#   init_tmpdir: Initialize directory to store temporary files
#                ensures the directory is deleted again on script exit
#   fatal_error: Prints error message and exists
#   error:       Prints error messages
#   warn:        Prints warning messages
#   verbose:     Prints verbose information, respecing user verbosity setting
#   debug:       Prints debug information, respecing user verbosity setting
#   print:       Prints a message
#   ensure_success: Ensures previous command completed successfully (otherwise exit)
# ==============================================================================


#######################################
# Create directory for temporary files
# and ensure it's deleted on exit
# Globals:
#   TMPDIR
# Arguments:
#   None
#######################################
function init_tmpdir {
	TMPDIR="$(mktemp -d)"
	export TMPDIR
	trap 'rm -rf "$TMPDIR"' EXIT
}


#######################################
# Print error message to stderr
# Globals:
#   None
# Arguments:
#   *: Arguments making up the message
#######################################
function error() {
	printf "Error: %s\n" "$*" 1>&2
}


#######################################
# Print error message to stderr and exits
# Globals:
#   None
# Arguments:
#   *: Arguments making up the message
#######################################
function fatal_error() {
	error "$@"
	exit 1
}


#######################################
# Print warning message to stderr
# Globals:
#   None
# Arguments:
#   *: Arguments making up the message
#######################################
function warn() {
	printf "Warning: %s\n" "$*" 1>&2
}


#######################################
# Print verbose information to stdout
# Globals:
#   VERBOSE
# Arguments:
#   *: Arguments making up the message
#######################################
function verbose() {
	if [ "${VERBOSE}" -gt 0 ]; then
		printf "%s\n" "$*"
	fi
}


#######################################
# Print debug information to stdout
# Globals:
#   VERBOSE
# Arguments:
#   *: Arguments making up the message
#######################################
function debug() {
	if [ "${VERBOSE}" -gt 1 ]; then
		printf "Debug: %s\n" "$*"
	fi
}


#######################################
# Print message to stdout
# Globals:
#   None
# Arguments:
#   *: Arguments making up the message
#######################################
function print() {
	printf "%s\n" "$*"
}


#######################################
# Quit if previous command unsuccessfull
# Globals:
#   (builtins)
# Arguments:
#   None
#######################################
function ensure_success() {
	# Detect if previous command failed
	if [ $? -ne 0 ]; then
		# Output error message and stack trace
		error "Previous command returned error condition!"
		printf "\nStack trace:\n" 1>&2
		for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
			printf "  function %s (file %s line %s)\n" \
				"${FUNCNAME[$i]}" \
				"${BASH_SOURCE[$i]}" \
				"${BASH_LINENO[$i - 1]}"
		done

		# Quit
		exit 1
	fi
}
