#!/usr/bin/env python3

import argparse
import logging
import os
import re
import sys
import csv
import pickle

# Global variables
NAME = "alphafold-score.py"
logger = None


def parse_commandline_options():
	# Define argument parser
	parser = argparse.ArgumentParser(
		description="Extract pTM, ipTM and 'ranking confedence'-score from AlphaFold2 pickle files"
	)
	parser.add_argument("directory", help="Directory with the AlphaFold2 output")
	parser.add_argument(
		"-o",
		"--output",
		default="-",
		help="Output file (- corresponds to stdout) (Default: %(default)s)",
	)
	parser.add_argument(
		"-f",
		"--force",
		default=False,
		action='store_true',
		help="Overwrite output file if it already exists (Default: %(default)s)",
	)
	parser.add_argument(
		"-v",
		"--verbose",
		action='count',
		default=0,
		help="Increase verbosity (prints more information), can be invoked multiple times",
	)

	# Parse arguments
	args = parser.parse_args()

	return args


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


def main():
	# Setup
	init_logger()
	args = parse_commandline_options()
	configure_logger(args)
	if not os.path.exists(args.directory):
		logger.error(f"Directory '{args.directory}' does not exist")
		sys.exit(1)
	elif not os.path.isdir(args.directory):
		logger.error(f"Supplied path '{args.directory}' is not a directory")
		sys.exit(1)
	logger.info(f"Processing directory '{args.directory}'")
	file = sys.stdout
	if args.output != "-":
		if not os.path.exists(os.path.dirname(args.output)):
			logger.error(f"Output directory '{os.path.dirname(args.output)}' does not exist")
			sys.exit(1)
		if os.path.exists(args.output):
			if args.force:
				logger.warning(f"Overwriting output file '{args.output}'")
			else:
				logger.error(f"Output file {args.output} already exists")
				sys.exit(1)
		file = open(args.output, 'wt', newline='')

	# Walk directory
	rows = []
	inputdir = os.path.basename(os.path.abspath(args.directory))
	pattern = re.compile(r".*(\d+)_multimer_v3_pred_(\d+)\.pkl")
	for entry in os.scandir(args.directory):
		if not entry.is_file():
			logger.debug(f"Skipping non-file entry '{entry.name}'")
			continue
		result = pattern.search(entry.name)
		if result is None:
			logger.debug(f"Skipping file '{entry.name}' -- doesn't match pattern")
			continue
		logger.debug(f"Reading parameters from matching file '{entry.name}'")
		with open(os.path.join(args.directory, entry.name), 'rb') as f:
			modelparams = pickle.load(f)
		rows.append([
			inputdir,
			f"{result.group(1)}_multimer_v3_pred_{result.group(2)}.pdb",
			"",
			modelparams['ptm'].item(),
			modelparams['iptm'].item(),
			modelparams['ranking_confidence']
		])
	if len(rows) == 0:
		logger.error(f"No file in directory '{args.directory}' contained AlphaFold2 model parameters")
		sys.exit(1)
	
	# write TSV file
	rows.sort()
	tsvwriter = csv.writer(file, delimiter="\t", quotechar='"', quoting=csv.QUOTE_MINIMAL)
	tsvwriter.writerow(["input", "model", "stoichio", "pTM", "ipTM", "AlphaFold2"])
	tsvwriter.writerows(rows)


# Run main function
if __name__ == "__main__":
	main()
