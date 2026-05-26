# ==============================================================================
# File Name:   stoichiometry.sh
# Description: Determine the stoichiometry of pentamer
#
# Globals:
#   TMPDIR
#   SCRIPT_DIR
#
# Exposed Functions:
#   pentamer_to_dimers:      Splits pentamer into adjacent dimers
#   determine_stoichiometry: Determines stoichiometry from dimers
# ==============================================================================


#######################################
# Split the pentamer to adjacent dimers
# Globals:
#   TMPDIR
#   SCRIPT_DIR
# Arguments:
#   1: Path to pentamer (PDB)
#   2: Path to output directory
#######################################
function pentamer_to_dimers() {
	# Temporary file to hold distances
	tf_distance="${TMPDIR}/dimer-distance.txt"
	> "${tf_distance}"

	# Extract every dimer combinations and calculate distance
	DIMERS=(AB AC AD AE BC BD BE CD CE DE)
	for dimer in "${DIMERS[@]}"; do
		pdb="${TMPDIR}/a_${dimer}.pdb"
		chains="${dimer:0:1},${dimer:1:1}"

		# Split pentamers into dimers (reordering the chains)
		python3 "${SCRIPT_DIR}/stoichiometry/pdb_selchain.py" "-${chains}" "$1" |
			python3 "${SCRIPT_DIR}/stoichiometry/pdb_chainbows.py" > "${pdb}"

		# Write table with dimer name and distance between cys-loops
		printf "%s\t%s\n" \
			"${pdb}" \
			"$(python3 "${SCRIPT_DIR}/stoichiometry/distance.py" --between cys-cys "${pdb}")" \
			>> "${tf_distance}"
	done

	# Delete non-adjacent dimers
	for file in $(awk '{if (($2 >= "28" && $2 <= "33")) next; else print $1}' "${tf_distance}"); do
		rm -f "${file}"
	done

	# Delete temporary file
	rm -f "${tf_distance}"

	# Rename dimer files to dimer1.pdb, dimer2.pdb, ...
	ls -v "${TMPDIR}"/a_*.pdb | cat -n | while read n file; do
		mv -n "${file}" "$2/dimer${n}.pdb"
	done
}


#######################################
# Determine stoichiometry from dimers
# I/O:
#   stdout: Determined stoichiometry
# Globals:
#   TMPDIR
#   SCRIPT_DIR
# Arguments:
#   1: Directory containing the dimers
#######################################
function determine_stoichiometry() {
	# Temporary file to hold distances
	tf_distance="${TMPDIR}/dimer-distance.txt"
	> "${tf_distance}"

	# Loop through dimers, calculate distance and indentify subunits
	find "$1" -name dimer\*.pdb | while read dimer; do
		printf "%s\t%s\t%s\t%s\n" \
			"$(python3 ${SCRIPT_DIR}/stoichiometry/distance.py --chains AB --between n-cys "${dimer}")" \
			"$(python3 ${SCRIPT_DIR}/stoichiometry/distance.py --chains AB --between cys-n "${dimer}")" \
			"$(python3 ${SCRIPT_DIR}/stoichiometry/subunit.py --chain A "${dimer}")" \
			"$(python3 ${SCRIPT_DIR}/stoichiometry/subunit.py --chain B "${dimer}")" \
			>> "${tf_distance}"
	done

	# Temporary file to hold dimers
	tf_dimers="${TMPDIR}/dimers.txt"
	> "${tf_dimers}"

	# Arrange subunits in the correct order
	awk '{if (($1 > $2)) print $3, $4; else print $4, $3}' "${tf_distance}" > "${tf_dimers}"

	# Remove first temporary file
	rm -f "${tf_distance}"

	# Determine stoichiometry from dimers
	# I/O:
	#   stdout: Determined stoichiometry
	# Arguments:
	#   1: sorted dimers.txt
	function determine_stoichiometry_from_dimers() {
		# Create temporary files
		stoichiometry="${TMPDIR}/stoichiometry.txt"
		file="${TMPDIR}/scratch-file.txt"
		cat "$1" > "${file}"
		# Process subunits
		next_subunit="$(head -n 1 "${file}" | awk '{print $1}')"
		while [ $(wc -w "${file}" | awk '{print $1}') -gt 0 ]; do
			# Copy first line starting with next_subunit
			grep -m1 "^${next_subunit}" "${file}" >> "${stoichiometry}"
			# Break look if no match
			if [ "$?" = 1 ]; then
				break
			fi
			# Delete copied line
			sed -i "0,/^${next_subunit}/{/^${next_subunit}/d}" "${file}"
			# Identify next subunit
			next_subunit="$(tail -n 1 "${stoichiometry}" | awk '{print $2}')"
		done
		# Output stoichiometry
		awk '{print $1}' "${stoichiometry}" | xargs printf "%s_%s_%s_%s_%s\n"
		# Delete temporary files
		rm -f "${stoichiometry}"
		rm -f "${file}"
	}

	# Determine both possible stoichiometries
	stoichiometry1="$(determine_stoichiometry_from_dimers <(sort -k1,1 -k2 "${tf_dimers}"))"
	stoichiometry2="$(determine_stoichiometry_from_dimers <(sort -k1,1 -k2r "${tf_dimers}"))"

	# Remove second temporary file
	rm -f "${tf_dimers}"

	# Select correct stoichiometry
	if [ ${#stoichiometry1} -ge ${#stoichiometry2} ]; then
		echo ${stoichiometry1}
	else
		echo ${stoichiometry2}
	fi
}
