# ==============================================================================
# File Name:   scoring.sh
# Description: Shared functionality for the scoring functions
#
# Includes:
#   Includes all supported scoring functions
#
# Globals:
#   SCRIPT_DIR
#
# Exposed Functions:
#   run_scoring_functions: Run all the scoring functions
#   cat_all_tables:        Concatenates all scoring function tables in subdirectory
#   cat_table:             Concatenate tables
#   dimer_add_sum:         Sum dimer scores
#   dimer_add_header:      Add header to dimer file
#   pentamer_add_header:   Add header to pentamer file
#   add_rowstub:           Add the rowstub to complete the table
# ==============================================================================


#
# Includes
##########
source "${SCRIPT_DIR}/scoring/prodigy.sh"
source "${SCRIPT_DIR}/scoring/zrank.sh"
source "${SCRIPT_DIR}/scoring/gdockscore.sh"


#######################################
# Run all scoring functions
# Globals:
#   VERBOSE
#   TMPDIR
# Arguments:
#   1: PDB model file
#   2: Dimer and output directory
#   3: Original model directory
#######################################
function run_scoring_functions() {
	# Create the table row stub which will be with output from all other variables
	rowstub="${TMPDIR}/rowstub.tsv"
	printf "%s\t%s\t%s\n" \
		"Input" \
		"Model" \
		"Stochiometry" \
		> "${rowstub}"
	printf "%s\t%s\t%s\n" \
		"$(basename "$3")" \
		"$(basename "$2")" \
		"$(cat "$2/stoichiometry.txt")" \
		>> "${rowstub}"

	# Score dimers with PRODIGY
	debug "Run PRODIGY (dimer)..."
	score_prodigy_dimer "$2" |
		dimer_add_sum |
		dimer_add_header "PRODIGY" |
		add_rowstub "${rowstub}" \
			> "$2/prodigy-dimer.tsv"

	# Score pentamers with PRODIGY
	debug "Run PRODIGY (pentamer)..."
	score_prodigy_pentamer "$1" |
		pentamer_add_header "PRODIGY" |
		add_rowstub "${rowstub}" \
			> "$2/prodigy-pentamer.tsv"

	debug "Run GDockScore..."
	score_gdockscore "$2" |
		dimer_add_sum |
		dimer_add_header "GDockScore" |
		add_rowstub "${rowstub}" \
			> "$2/gdockscore.tsv"

	debug "Run ZRANK..."
	score_zrank "$2" |
		dimer_add_sum |
		dimer_add_header "ZRANK" |
		add_rowstub "${rowstub}" \
			> "$2/zrank.tsv"

	# Delete temporary file
	rm -f "${rowstub}"
}


#######################################
# Concatenate all tables from subdirectories
# Globals:
#   None
# Arguments:
#   1: Working directory
#######################################
function cat_all_tables() {
	# Define all table names
	local tables=(
		"alphafold2.tsv"
		"prodigy-dimer.tsv"
		"prodigy-pentamer.tsv"
		"gdockscore.tsv"
		"zrank.tsv"
	)

	# Create all tables
	for table in "${tables[@]}"; do
		if ! cat_table "$1" "${table}" > "$1/${table}"; then
			rm -f "$1/${table}"
		fi
	done
}


#######################################
# Concatenate table from subdirectories
# I/O:
#   stdout: Concatenated table
# Globals:
#   VERBOSE
#   TMPDIR
# Arguments:
#   1: Working directory
#   2: table file name
#######################################
function cat_table() {
	# Find the first file
	local first_table
	first_table="$(find "$1" -mindepth 2 -maxdepth 2 -type f -name "$2" | head -n 1)"

	# Return error if no files found
	if [ -z "$first_table" ]; then
		return 1
	fi

	# Print first file with header
	cat "${first_table}"

	# Print remaining tables excluding the header
	find "$1" -mindepth 2 -maxdepth 2 -type f -name "$2" | tail -n +2 | while read -r table; do
		tail -n +2 "${table}"
	done
}


#######################################
# Add sum for dimer scores
# I/O:
#   stdin:  tab separated dimer scores
#   stdout: tab separated dimer scores and sum
# Globals:
#   None
# Arguments:
#   None
#######################################
function dimer_add_sum() {
	awk -v OFS="\t" -v CONVFMT="%.15g" '{ $6 = $1 + $2 + $3 + $4 + $5 } 1'
}


#######################################
# Add header for dimers and sum
# I/O:
#   stdin:  tab separated dimer scores
#   stdout: tab separated file with header
# Globals:
#   None
# Arguments:
#   1: Name of scoring function
#######################################
function dimer_add_header() {
	echo -e "1st dimer\t2nd dimer\t3rd dimer\t4th dimer\t5th dimer\tΣ${1}"
	cat
}


#######################################
# Add header for pentamer
# I/O:
#   stdin:  tab separated dimer scores
#   stdout: tab separated file with header
# Globals:
#   None
# Arguments:
#   1: Name of scoring function
#######################################
function pentamer_add_header() {
	echo -e "$1"
	cat
}


#######################################
# Add table row stub
# I/O:
#   stdin:  table
#   stdout: table with table row stub
# Globals:
#   None
# Arguments:
#   1: Directory with rowstub
#######################################
function add_rowstub() {
	paste "$1" <(cat)
}
