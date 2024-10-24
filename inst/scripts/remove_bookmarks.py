import argparse
from docx import Document
from docx.oxml.ns import qn

def remove_bookmarks(docx_in, docx_out):
    # Load the document
    doc = Document(docx_in)
    
    # Remove any remaining bookmark elements (if any exist)
    for element in doc.element.findall(".//w:bookmarkStart", namespaces=doc.element.nsmap):
        parent = element.getparent()
        parent.remove(element)

    for element in doc.element.findall(".//w:bookmarkEnd", namespaces=doc.element.nsmap):
        parent = element.getparent()
        parent.remove(element)

    # Save the modified document
    doc.save(docx_out)
    print(f"Processed file saved at '{docx_out}'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Remove paragraphs with bookmarks that start with 't_' and other bookmarks from input docx document")
    parser.add_argument('-i', '--input', type=str, required=True, help="Input docx file path")
    parser.add_argument('-o', '--output', type=str, required=True, help="Output docx file path")
    args = parser.parse_args()

    remove_bookmarks(args.input, args.output)
