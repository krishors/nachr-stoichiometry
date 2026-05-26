#!/usr/bin/env python3

import argparse
import json
import csv
import os.path


def parse_commandline_options():
	# Define argument parser
	parser = argparse.ArgumentParser(
		description="Process ranking_debug.json into table of AlphaFold2-scores"
	)
	parser.add_argument("outdir", help="Output directory")
	parser.add_argument(
		"-i",
		"--input",
		metavar="ranking_debug.json",
		help="Path to ranking_debug.json file"
	)

	# Parse arguments
	args = parser.parse_args()

	return args


def main():
	# Parse command line arguments
	args = parse_commandline_options()

	# Parse ranking_debug.json
	with open(args.input, 'rt') as fp:
		ranking = json.load(fp)

	# Prepare output
	rows = [["Input", "Model", "Stoichiometry", "AlphaFold2"]]

	# Loop through iptm+ptm values
	for model, score in ranking["iptm+ptm"].items():
		subdir = model[model.find('_')+1:]

		# Get Input, Model and Stoichiometry from other scoring function
		with open(os.path.join(args.outdir, subdir, "zrank.tsv")) as fp:
			zrank = list(csv.reader(fp, delimiter="\t"))

		# Append row
		rows.append([
			zrank[1][0],  # Input
			zrank[1][1],  # Model
			zrank[1][2],  # Stoichiometry
			score,
		])

	# Write out table
	with open(os.path.join(args.outdir, "alphafold2.tsv"), 'wt') as fp:
		writer = csv.writer(fp, rows, delimiter='\t')
		writer.writerows(rows)


# Run main function
if __name__ == "__main__":
	main()
