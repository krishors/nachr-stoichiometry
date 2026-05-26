# ==============================================================================
# File Name:   gdockscore.sh
# Description: Score model using GDockScore
#
# Globals:
#   GDOCKSCORE_VENV: Python virtual environment with GDockScore and dependencies
#                    installed.
#   GDOCKSCORE_DIR:  Directory where GDockScore repository is downloaded to
#
# Exposed Functions:
#   score_gdockscore:     Output scoring values for GDockScore
# ==============================================================================


#
# Globals
#########
if [[ ! -v GDOCKSCORE_VENV ]]; then
	GDOCKSCORE_VENV="${HOME}/gdock"
fi
if [[ ! -v GDOCKSCORE_DIR ]]; then
	GDOCKSCORE_DIR="${HOME}/gdockscore"
fi


#######################################
# Score dimers using GDockScore
# I/O:
#   stdout: tab separated scoring values
# Globals:
#   GDOCKSCORE
# Arguments:
#   1: Directory containing the dimers
#######################################
function score_gdockscore() {
	# Ensure shim is available
	local shim="${TMPDIR}/gdockscore-shim.sh"
	if [ ! -e "${shim}" ]; then
		gdockscore_shim "${GDOCKSCORE_VENV}" "${GDOCKSCORE_DIR}" > "${shim}"
	fi

	# Run GDockScore
	for n in $(seq 1 5); do
		bash "${shim}" "$1/dimer${n}.pdb"
		awk '{print $2}' "${TMPDIR}/results.txt" | xargs printf "%s"
		if [ "${n}" -lt 5 ]; then
			echo -en "\t"
		fi
	done
	echo
}


#######################################
# Create shim for GDockscore
# I/O:
#   stdout: shim
# Globals:
#   None
# Arguments:
#   1: GDockScore virtual environment path
#   2: GDockScore directory
#######################################
function gdockscore_shim() {
	cat << EOF
# shim for gdockscore generated at $(date "+%Y-%m-%d %H:%M:%S")
source "$1/bin/activate"
cwd="\$(pwd)"
cd "$2" || exit 1
python3 "./scripts/run_gdockscore.py" --file "\$cwd/\$1" --chain_pair AB 2>&1 |
	grep -v "NNPACK.cpp:51" 1>&2
mv results.txt "${TMPDIR}/"
deactivate
EOF
}
