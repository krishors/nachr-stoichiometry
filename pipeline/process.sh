#!/bin/bash

# ==============================================================================
# Script Name:  process.sh
# Description:  Processes output form AlphaFold-Multimer modelling
#
# Usage:             ./process.sh [-v] PDBDIR OUTDIR
#
# Where:
#   PDBDIR           is the directory with the PDB-files to be processed
#   OUTDIR           is the directory where the processed files should be stored
#
# Arguments:
#   -h, --help       Output help message on how the script is used
#   -v, --verbose    Verbose mode, prints more information while working
#                    (Can be invoked twice to see debug information)
#
# Dependencies: python3, pdb-tools, ZRANK, PRODIGY, GDockScore
# ==============================================================================

# Exit on error, undefined variables, and pipe failures
set -euo pipefail


#
# Globals
#########
export NAME='process.sh'
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PDBDIR_IS_MODELDIR=0


#
# Includes
##########

# General functionality
source "${SCRIPT_DIR}/include/helpers.sh"
source "${SCRIPT_DIR}/include/arguments.sh"

# Stoichiometry determination
source "${SCRIPT_DIR}/stoichiometry/stoichiometry.sh"

# Scoring functions
source "${SCRIPT_DIR}/scoring/scoring.sh"


#
# Processing
############


#######################################
# Process input models
# Globals:
#   VERBOSE
#   SCRIPT_DIR
# Arguments:
#   1: Input directory (directory with original models)
#   2: Output directory
#######################################
function process() {
	# Loop through all PDB-files in input directory
	find "$1" -name \*.pdb | while read -r pdbfile; do
		verbose "Processing ${pdbfile}"

		# Name and create output directory
		debug "Create output directory..."
		local model dir outdir
		model="$(basename "${pdbfile}")"
		dir="${model#*_*_}"
		outdir="$2/${dir%.*}"
		mkdir -p "${outdir}"

		# Copy model PDB-file to output dirctory
		debug "Copy pdbfile..."
		cp "${pdbfile}" "${outdir}/${model}"

		# Create dimers from pentamer
		debug "Create dimers..."
		pentamer_to_dimers "${pdbfile}" "${outdir}"

		# Determine stoichiometry of model
		debug "Determine stoichiometry..."
		determine_stoichiometry "${outdir}" > "${outdir}/stoichiometry.txt"

		# Run the scoring functions
		run_scoring_functions "${pdbfile}" "${outdir}" "$1"
	done

	# Collect output from all subfolders
	verbose "Assembling scores..."
	cat_all_tables "$2"

	# Process ranking_debug.json into AlphaFold2-scores
	python3 "${SCRIPT_DIR}/scoring/alphafold2.py" -i "$1/ranking_debug.json" "$2"
}


#######################################
# Main function
# Globals:
#   * (all)
# Arguments:
#   N/A (script arguments)
#######################################
function main() {
	# Parse command line arguments
	parse_arguments "$@"

	# Check if PDBDIR is the model directory or the parent directory
	if ls "${PDBDIR}"/*.pdb > /dev/null 2>&1; then
		debug "PDBDIR is a model directory"
		PDBDIR_IS_MODELDIR=1
	else
		debug "PDBDIR is a parent directory"

		# Check that PDBDIR is a valid parent directory
		if ls "${PDBDIR}"/*/*.pdb > /dev/null 2>&1; then
			:
		else
			error "PDBDIR is not a valid parent directory: No subdirectories contain pdb-files"
			print_usage
			exit 1
		fi
	fi

	# Ensure OUTDIR exists
	if [ ! -e "${OUTDIR}" ]; then
		debug "OUTDIR '$OUTDIR' does not exist, creating..."
		mkdir -p "$OUTDIR"
	fi

	# Initialize directory for temporary files
	init_tmpdir

	# Invoke the processing
	if [ $PDBDIR_IS_MODELDIR -gt 0 ]; then
		# Process single model directory
		process "${PDBDIR}" "${OUTDIR}"
	else
		# Process parent directory with one or more model directories
		debug "Processing all directories in ${PDBDIR}"
		find "${PDBDIR}" -maxdepth 1 -type d | while read -r modeldir; do
			# Skip top level path
			if [ "$(realpath "${PDBDIR}")" = "$(realpath "${modeldir}")" ]; then
				continue
			fi

			# Ensure output directory exists
			debug "Entering model directory '${modeldir}'..."
			modelout="$(basename "${modeldir}")"
			if [ ! -e "${OUTDIR}/${modelout}" ]; then
				debug "Output directory '${OUTDIR}/${modelout}' does not exist, creating..."
				mkdir "${OUTDIR}/${modelout}"
			fi

			# Process all models in subdirectory
			process "${modeldir}" "${OUTDIR}/${modelout}"
			debug "Finished processing model directory '$modeldir'..."
		done

		# Collect output from all subfolders
		verbose "Collecting all tables..."
		cat_all_tables "${OUTDIR}"
	fi
}

# Invoke main function
main "$@"
