import argparse
from docx import Document
from docx.oxml.ns import qn

def remove_bookmarks(docx_in, docx_out):
    doc = Document(docx_in)

    fp_bookmark_ids = set()

    for element in doc.element.findall(".//w:bookmarkStart", namespaces=doc.element.nsmap):
        bookmark_name = element.get(qn("w:name"))
        if bookmark_name and bookmark_name.startswith("fp_"):
            fp_bookmark_ids.add(element.get(qn("w:id")))  # Store ID of removed bookmarks
            parent = element.getparent()
            parent.remove(element)

    for element in doc.element.findall(".//w:bookmarkEnd", namespaces=doc.element.nsmap):
        bookmark_id = element.get(qn("w:id"))
        if bookmark_id in fp_bookmark_ids:  # Remove only matching bookmarkEnd
            parent = element.getparent()
            parent.remove(element)

    doc.save(docx_out)
    print(f"Processed file saved at '{docx_out}'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Remove only bookmarks that start with 'fp_' from a Word document")
    parser.add_argument('-i', '--input', type=str, required=True, help="Input docx file path")
    parser.add_argument('-o', '--output', type=str, required=True, help="Output docx file path")
    args = parser.parse_args()

    remove_bookmarks(args.input, args.output)
