# ==============================================================================
# File Name:   arguments.sh
# Description: Interpret command line arguments
#
# Globals:
#   PCBDIR
#   OUTDIR
#   VERBOSE
#
# Exposed Functions:
#   print_usage: Prints a short message detailing how the application is run
#   print_help:  Prints the full help message
#   verbose:     Prints verbose information, respecing user verbosity setting
#   debug:       Prints debug information, respecing user verbosity setting
# ==============================================================================

# Global options
PDBDIR=""
OUTDIR=""
VERBOSE=0


#######################################
# Prints a short message detailing application usage
# Globals:
#   NAME
# Arguments:
#   None
#######################################
function print_usage() {
	printf "usage: %s [-v] PDBDIR OUTDIR [--help for more information]\n" "${NAME}"
}


#######################################
# Prints the full help message
# Globals:
#   NAME
# Arguments:
#   None
#######################################
function print_help() {
	cat << EOF
usage: ${NAME} [options] PDBDIR OUTDIR

Where
PDBDIR is the directory with the PDB-files to be processed
       may either itself contain all the PDB-files, or
       may be a parent directory with the models from in subdirectories
OUTDIR is the directory where the processed files should be stored
       if PDBDIR is a parent directory, matching subdirectories will be created

OPTIONS            DESCRIPTION
-h, --help         Prints this help message
-v, --verbose      Verbose mode, prints more information while working
                   Can be invoked twice to see debug information
EOF
}


#######################################
# Parse command line arguments
# Globals:
#   PCBDIR
#   OUTDIR
#   VERBOSE
#
# Arguments:
#   (application)
#######################################
function parse_arguments() {
	error=""

	# Check that enough arguments were given
	if [ "$#" -lt 2 ]; then
		error="Too few arguments given"
	fi

	# Read command line options
	while [ "$#" -gt 0 ]; do
		case "$1" in
			-h | --help)
				print_help
				exit 0
				;;
			-v | --verbose)
				VERBOSE=$((VERBOSE + 1))
				;;
			--nop)
				warn "NOP command line option processed"
				;;
			# Detect unknown long arguments
			--*)
				error "Unknown command line option '$1'"
				print_usage
				exit 1
				;;
			# Parse combined short arguments into individual short arguments
			-*)
				opt="${1:1:1}"
				rest="${1:2}"
				if [ -n "${rest}" ]; then
					set -- "--nop" "-${opt}" "-${rest}" "${@:2}"
				else
					error "Unknown command line option '-${opt}'"
					print_usage
					exit 1
				fi
				;;
			*)
				if [ -z "${PDBDIR}" ]; then
					PDBDIR="$(dirname "$1")/$(basename "$1")"
				else
					if [ -n "${OUTDIR}" ]; then
						error "Too many positional arguments"
						print_usage
						exit 1
					fi
					OUTDIR="$(dirname "$1")/$(basename "$1")"
				fi
				;;
		esac
		shift
	done

	# Detect if there were errors parsing command line options
	if [ -n "${error}" ]; then
		error "${error}"
		print_usage
		exit 1
	fi

	# Check that PDBDIR and OUTDIR are spesified and valid
	if [ -z "${PDBDIR}" ] || [ -z "${OUTDIR}" ]; then
		error "PDBDIR or OUTDIR not spesified"
		print_usage
		exit 1
	fi
	if [ ! -e "${PDBDIR}" ]; then
		error "PDBDIR '${PDBDIR}': Directory does not exist"
		print_usage
		exit 1
	fi
}
