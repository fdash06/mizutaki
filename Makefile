run: datasets datasets/parsed.csv datasets/factors.txt
	ruby make_json.rb

datasets/parsed.csv: datasets input.csv
	ruby parser.rb

datasets/factors.txt: datasets datasets/parsed.csv
	python predict.py

datasets:
	mkdir datasets

.PHONY: clean
clean:
	rm -rf datasets data.json
