#!/bin/bash

# Get the PDF file path from command-line argument
pdf_file_original_path="$1"

# This is the file we want to split up, since paperless copies a file from the consume folder into this temp folder
# We cannot modify the original consumed file, cause this would trigger more consumers to start and run this script again
pdf_file_path="${DOCUMENT_WORKING_PATH}"

# Check if the file starts with "split_this"
if [[ ! -f "$pdf_file_path" ]] || [[ $(basename "$pdf_file_path") != split_this* ]]; then
    echo "Invalid file path or file does not start with 'split_this'."
    exit 0
fi


# Some python checks, there is propably a better way to do it:
# Check if Python is installed
if ! command -v python &> /dev/null; then
    echo "Python is not installed. Please install Python to run this script."
    exit 1
fi

# Check if PyPDF2 is installed
if ! python -c "import PyPDF2" &> /dev/null; then
    echo "PyPDF2 is not installed. Installing PyPDF2..."
    python -m pip install PyPDF2
fi

# Check if PyCryptodome is installed
if ! python -c "import Cryptodome" &> /dev/null; then
    echo "PyCryptodome is not installed. Installing PyCryptodome..."
    python -m pip install PyCryptodome
fi

# Run the Python script
python - "$pdf_file_path" "$pdf_file_original_path" << EOF
import os
import sys
from PyPDF2 import PdfReader, PdfWriter
from Crypto.Cipher import AES

def split_pdf_pages(input_path, output_prefix):
    pdf = PdfReader(input_path)
    directory = os.path.dirname(pdf_file_original_path) # this is the consume-folder since its the path from the original file

    # this shouldn't happen, but just in case (e.g. your scanner jammed after the first page)
    if len(pdf.pages) == 1:
        print("skipping split since file only got one page")
        sys.exit(0)

    for page_number in range(len(pdf.pages)):
        if page_number == 0:
            # The first page should be stored in the temporary path that paperless is working with
            # so after this script is done, paperless will consume it - but it contains only the first page
            output_path = os.path.join(input_path)
        else:
            # All pages but the first page are saved as separate documents into the consumer folder (where the original pdf came from)
            # and are handle as seperate documents - for each this script will run but be skipped due to the filename
            output_path = os.path.join(directory, f"splittet_{output_prefix}_page{page_number + 1}.pdf")        
        output = PdfWriter()
        output.add_page(pdf.pages[page_number])

        with open(output_path, "wb") as output_file:
            output.write(output_file)

        print(f"Page {page_number + 1} saved to {output_path}")

# Get the PDF file path from command-line argument
if len(sys.argv) < 2:
    print("Please provide the PDF file path as a command-line argument.")
    sys.exit(1)

pdf_file_path = sys.argv[1]
pdf_file_original_path = sys.argv[2]
output_prefix = os.path.splitext(os.path.basename(pdf_file_path))[0]

# Split the PDF pages
split_pdf_pages(pdf_file_path, output_prefix)

# Delete the source file if successful
# os.remove(pdf_file_path)
EOF
