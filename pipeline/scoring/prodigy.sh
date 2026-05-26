# ==============================================================================
# File Name:   prodigy.sh
# Description: Score model using PRODIGY
#
# Globals:
#   None
#
# Exposed Functions:
#   score_prodigy_dimer:     Output scoring values for PRODIGY (dimer)
#   score_prodigy_pentamer:  Output scoring value for PRODIGY (pentamer)
# ==============================================================================


#
# Globals
#########
if [[ ! -v PRODIGY ]]; then
	PRODIGY="prodigy"
fi


#######################################
# Score dimers using PRODIGY
# I/O:
#   stdout: tab separated scoring values
# Globals:
#   PRODIGY
# Arguments:
#   1: Directory containing the dimers
#######################################
function score_prodigy_dimer() {
	# Run prodigy on each dimer
	for n in $(seq 1 5); do
		printf "%s" "$("${PRODIGY}" -q "$1/dimer${n}.pdb" | awk '{ print $2 }')"
		if [ "${n}" -lt 5 ]; then
			echo -en "\t"
		fi
	done
	echo
}


#######################################
# Score pentamer using PRODIGY
# I/O:
#   stdout: tab separated scoring values
# Globals:
#   None
# Arguments:
#   1: Path to pentamer
#######################################
function score_prodigy_pentamer() {
	printf "%s\n" "$("${PRODIGY}" -q "$1" | awk '{print $2}')"
}
