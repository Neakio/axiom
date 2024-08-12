import json
import argparse
from urllib.parse import urlparse


def transform_json(input_file: str, output_file: str):

    original_data = [json.loads(line) for line in open(input_file, 'r')]
    transformed_data = {}

    for entry in original_data:
        url = entry['url']
        parsed_url = urlparse(url)
        key = f"{parsed_url.scheme}://{parsed_url.netloc}".lower()
        if key not in transformed_data:
            transformed_data[key] = []
        transformed_data[key].append(url)

    with open(output_file, "w") as f:
        json.dump(transformed_data, f, indent=2)

def main():
    parser = argparse.ArgumentParser(
        description='Group Gau result')
    parser.add_argument('-i', '--input_file', required=True,
                        help='Path to the JSON file')
    parser.add_argument('-o', '--output_file', required=True,
                        help='Path for the created JSON')
    args = parser.parse_args()

    transform_json(args.input_file, args.output_file)

if __name__ == "__main__":
    main()
