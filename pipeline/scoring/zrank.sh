# ==============================================================================
# File Name:   zrank.sh
# Description: Score model using ZRANK
#
# Globals:
#   None
#
# Exposed Functions:
#   zrank:           Output scoring values for ZRANK
# ==============================================================================


#
# Globals
#########
if [[ ! -v ZRANK ]]; then
	ZRANK="zrank"
fi


#######################################
# Score dimers using ZRANK
# I/O:
#   stdout: tab separated scoring values
# Globals:
#   ZRANK
#   TMPDIR
# Arguments:
#   1: Directory containing the dimers
#######################################
function score_zrank() {
	# Create temporary filelist of dimers
	local filelist="${TMPDIR}/zrank-filelist.txt"
	: > "${filelist}"
	for n in $(seq 1 5); do
		echo "$1/dimer${n}.pdb" >> "${filelist}"
	done

	# Run zrank
	"${ZRANK}" "${filelist}"

	# Output scores
	awk '{print $2}' "${filelist}.zr.out" | xargs printf "%s\t%s\t%s\t%s\t%s\n"

	# Delete temporary files
	rm -f "${filelist}" "${filelist}".zr.out
}
