#!/usr/bin/env python3


import argparse
import logging
import os
import re
import sys


# Global variables
NAME = "distance.py"
logger = None


def parse_commandline_options():
	# Define argument parser
	parser = argparse.ArgumentParser(
		description="Calculate distance between dimers with reference to cys-loop"
	)
	parser.add_argument("file", help="PDB-file to operate on.")
	parser.add_argument(
		"--chains", help="Chains to operate on (Default: operate on first two chains)"
	)
	parser.add_argument(
		"--between",
		default="cys-cys",
		choices=["cys-cys", "n-cys", "cys-n"],
		help="Select whether calculating distance from CYS to CYS (cys-cys) or CYS to N-terminus (n-cys or cys-n) (Default: %(default)s)",
	)
	parser.add_argument(
		"-v",
		"--verbose",
		action="count",
		default=0,
		help="Increase verbosity (prints more information), can be invoked multiple times",
	)

	# Parse arguments
	args = parser.parse_args()

	# Normalize chain designation and detect invalid input
	if args.chains is not None:
		args.chains = re.sub(r"[^A-Z]", "", args.chains.upper())
		if len(args.chains) != 2:
			chain_selection = ", ".join(args.chains)
			logger.error(f"You must select two chains. You selected {chain_selection}")
			sys.exit(1)

	return args


def distance(a, b):
	return ((a[0]-b[0])**2 + (a[1]-b[1])**2 + (a[2]-b[2])**2)**0.5


def parse_pdb(file):
	# Return values
	chains = []
	terminus = {}
	cysloop = {}

	# Bookkeeping
	previous_resSeq = -100

	for line in file:
		if line.startswith("ATOM"):
			chain = line[21]

			# Match CYS-residues
			residue = line[17:20]
			if residue == "CYS":
				resSeq = int(line[22:26].strip())
				if resSeq == previous_resSeq:
					continue
				logger.debug(f"CYS found in chain {chain} at {resSeq}")
				if (resSeq - previous_resSeq) == 14:
					coordinates = (
						float(line[30:38].strip()),  # x
						float(line[38:46].strip()),  # y
						float(line[46:54].strip()),  # z
					)
					logger.debug(f"cys-loop of chain {chain} found at {coordinates}")
					if chain in cysloop:
						logger.warning(
							f"Multiple CYS-CYS matches in chain (new: {coordinates}, previous: {cysloop[chain]}"
						)
					cysloop[chain] = coordinates
				previous_resSeq = resSeq

			# Detect new chains and save N-terminus coordinates
			if chain not in terminus:
				coordinates = (
					float(line[30:38].strip()),  # x
					float(line[38:46].strip()),  # y
					float(line[46:54].strip()),  # z
				)
				terminus[chain] = coordinates
				chains.append(chain)
				logger.debug(f"N-terminus of chain {chain} found at {coordinates}")
				previous_resSeq = -100

	return (chains, terminus, cysloop)


def init_logger():
	global logger

	# Define logger
	logger = logging.getLogger(NAME)

	# Configure handler
	stderr_handler = logging.StreamHandler(sys.stderr)
	stderr_handler.setLevel(logging.WARNING)
	stderr_handler.setFormatter(logging.Formatter(fmt="%(levelname)s: %(message)s"))

	# Attach handler to logger
	logger.addHandler(stderr_handler)


def configure_logger(args):
	# Map verbosity to logging levels
	level_map = {
		0: logging.WARNING,
		1: logging.INFO,
		2: logging.DEBUG,
	}

	# Configure logger
	logger.setLevel(level_map[args.verbose])

	# Configure handler
	stdout_handler = logging.StreamHandler(sys.stdout)
	stdout_handler.addFilter(MaxLevelFilter(logging.INFO))
	stdout_handler.setFormatter(logging.Formatter(fmt="%(message)s"))

	# Attach handler to logger
	logger.addHandler(stdout_handler)


def main():
	# Setup
	init_logger()
	args = parse_commandline_options()
	configure_logger(args)
	if not os.path.exists(args.file):
		logger.error(f"PDB-file '{args.file}' does not exist")
		sys.exit(1)

	# Open and parse PDB-file
	with open(args.file, 'rt') as fp:
		(chains, terminus, cysloop) = parse_pdb(fp)
	logger.info(f"Chains: {chains}")
	logger.info(f"N-terminus: {terminus}")
	logger.info(f"Cysloop: {cysloop}")

	# Parse user chains request
	if len(chains) < 2:
		logger.error(f"PDB-file only contains {len(chains)} chains")
	if args.chains is None:
		args.chains = "".join(chains[0:2])
	if args.chains[0] not in chains or args.chains[1] not in chains:
		logger.error("PDB-file does not contain selected chains")

	# Parse distance request and calculate result
	d = None
	if args.between == "cys-cys":
		d = distance(cysloop[args.chains[0]], cysloop[args.chains[1]])
	elif args.between == "n-cys":
		d = distance(terminus[args.chains[0]], cysloop[args.chains[1]])
	elif args.between == "cys-n":
		d = distance(cysloop[args.chains[0]], terminus[args.chains[1]])
	else:
		logger.error("Program reached illegal state")
		sys.exit(1)

	# Print result
	print(d)


class MaxLevelFilter(logging.Filter):
	"""
	A custom filter to ensure messages above a spesified level do not pass
	through to the handler
	"""

	def __init__(self, max_level):
		super().__init__()
		self.max_level = max_level

	def filter(self, record):
		return record.levelno <= self.max_level


# Run main function
if __name__ == "__main__":
	main()
