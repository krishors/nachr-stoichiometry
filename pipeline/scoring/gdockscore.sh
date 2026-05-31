# ==============================================================================
# File Name:   gdockscore.sh
# Description: Score model using GDockScore
#
# Globals:
#   GDOCKSCORE_DIR:   Directory with GDockScore repository
#   And:
#   GDOCKSCORE_VENV:  Python venv with GDockScore and dependencies installed.
#   Or:
#   GDOCKSCORE_CONDA: Conda env with GDockScore and dependencies installed.
#
#
# Exposed Functions:
#   score_gdockscore: Output scoring values for GDockScore
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
		if [[ ! -v GDOCKSCORE_CONDA ]]; then
			gdockscore_shim_venv "${GDOCKSCORE_VENV}" "${GDOCKSCORE_DIR}" > "${shim}"
		else
			gdockscore_shim_conda "${GDOCKSCORE_CONDA}" "${GDOCKSCORE_DIR}" > "${shim}"
		fi
	fi

	# Run GDockScore
	for n in $(seq 1 5); do
		bash "${shim}" "$1/dimer${n}.pdb"
		if [ "${n}" -lt 5 ]; then
			echo -en "\t"
		fi
	done
	echo
}


#######################################
# Create shim for GDockscore using venv
# I/O:
#   stdout: shim
# Globals:
#   None
# Arguments:
#   1: GDockScore virtual environment path
#   2: GDockScore directory
#######################################
function gdockscore_shim_venv() {
	cat << EOF
# shim for gdockscore generated at $(date "+%Y-%m-%d %H:%M:%S")
source "$1/bin/activate"
cwd="\$(pwd)"
cd "$2" || exit 1
python3 "./scripts/run_gdockscore.py" --file "\$cwd/\$1" --chain_pair AB 2>&1 |
	grep -v "NNPACK.cpp:51" 1>&2
tail -n 1 "results.txt" | awk '{print \$2}' | xargs printf "%s"
deactivate
EOF
}


#######################################
# Create shim for GDockscore using Conda
# I/O:
#   stdout: shim
# Globals:
#   None
# Arguments:
#   1: Name of Conda environment
#   2: GDockScore directory
#######################################
function gdockscore_shim_conda() {
	cat << EOF
# shim for gdockscore generated at $(date "+%Y-%m-%d %H:%M:%S")
cwd="\$(pwd)"
cd "$2" || exit 1
rm -f "results.txt"
conda run -n "$1" python3 "./scripts/run_gdockscore.py" --file "\$cwd/\$1" --chain_pair AB 2>&1 |
	grep -v "NNPACK.cpp:51" 1>&2
tail -n 1 "results.txt" | awk '{print \$2}' | xargs printf "%s"
EOF
}
