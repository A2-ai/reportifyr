import os
import argparse
from docx import Document

# This still uses the bookmark approach via fp_ 
def remove_footnotes(docx_in, docx_out):
    namespace = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'

    doc = Document(docx_in)

    # Remove footnotes with 'fp_' in the bookmark name
    for bookmark in doc.element.xpath('//w:bookmarkStart'):
        name = bookmark.get(namespace + 'name')
        if name.startswith('fp_'):
            bookmark_id = bookmark.get(namespace + 'id')
            end_bookmark = doc.element.xpath(f'//w:bookmarkEnd[@w:id="{bookmark_id}"]')[0]
            
            elements_to_remove = []
            current_element = bookmark.getnext()
            while current_element is not end_bookmark:
                elements_to_remove.append(current_element)
                current_element = current_element.getnext()
                
            for element in elements_to_remove:
                element.getparent().remove(element)
            
            parent_element = bookmark.getparent()
            
            bookmark.getparent().remove(bookmark)
            end_bookmark.getparent().remove(end_bookmark)
            
            if len(parent_element) == 0:
                parent_element.getparent().remove(parent_element)
            elif parent_element.tag.endswith('p') and not any(child.tag.endswith('r') for child in parent_element):
                parent_element.getparent().remove(parent_element)

    doc.save(docx_out)
    print(f"Processed file saved at '{docx_out}'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add figures to input docx document")
    parser.add_argument('-i', '--input', type = str, required=True, help = "input docx file path")
    parser.add_argument("-o", "--output", type = str, required=True, help = "Output docx file")
    args = parser.parse_args()

    remove_footnotes(args.input, args.output)