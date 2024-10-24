import os
import re
import json
import yaml
import argparse
from docx import Document
from docx.shared import Pt
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

def add_figure_footnotes(docx_in, docx_out, figure_dir, footnotes_yaml):
    # Load standard footnotes from a yaml file
    with open(footnotes_yaml, 'r') as y:
        footnotes = yaml.safe_load(y)

    document = Document(docx_in)

    # Define magic string pattern
    start_pattern = r'\{rpfy\}\:'   # Matches "{rpfy}:" and any directory structure following it
    end_pattern = r'\.[^.]+$'
    magic_pattern = re.compile(start_pattern + '.*?' + end_pattern)
    paragraphs = document.paragraphs

    for i, par in enumerate(paragraphs):
        matches = magic_pattern.findall(par.text)
        if matches:
            for match in matches:
                # Generalized extraction of the figure name
                figure_name = match.replace("{rpfy}:", "")
                if figure_name in os.listdir(figure_dir):

                    object_name, extension = os.path.splitext(figure_name)
                    metadata_file = os.path.join(figure_dir, f"{object_name}_{extension[1::]}_metadata.json")

                    with open(metadata_file, 'r') as m:
                        metadata = json.load(m)
                        
                    meta_text_lines = []
                    source_text = ""
                    # Add source metadata
                    source = metadata.get("source_meta").get("path")
                    creation_time = metadata.get("source_meta").get("creation_time")
                    if source and creation_time:
                        source_text = f"[Source: {source} {creation_time}]"
                    meta_text_lines.append(source_text)

                    # Add notes metadata
                    notes_text = ""
                    meta_type = metadata.get("object_meta").get("meta_type")
                    notes_list = metadata.get("object_meta").get("footnotes").get("notes") # If empty this might be a list -- should be ok because len will still work.
                    notes_added = False
                    if type(meta_type) == str and meta_type != "NA":
                        n = footnotes["figure_footnotes"][meta_type]
                        if n:
                            notes_text += f"Notes: {n}"
                            notes_added = True

                    if len(notes_list) > 0:
                        for note in notes_list:
                            if notes_added:
                                notes_text += f". {note}"
                            else: 
                                notes_text += f"Notes: {note}"
                                notes_added = True

                    if not notes_added:
                        notes_text += "Notes N/A\n"
                    meta_text_lines.append(notes_text)

                    # Add abbreviations metadata
                    abbrev_text = ""
                    abbrev_list = metadata.get("object_meta").get("footnotes").get("abbreviations")
                    if len(abbrev_list) > 0:
                        for abbrev_ind, abbrev in enumerate(abbrev_list):
                            if abbrev_ind == 0:
                                abbrev_text += f"Abbreviations: {abbrev}: {footnotes['abbreviations'][abbrev]}. "
                            else:
                                abbrev_text += f"{abbrev}: {footnotes['abbreviations'][abbrev]}. "
                    else:
                        abbrev_text += "Abbreviations: N/A"
                    meta_text_lines.append(abbrev_text)
                    
                    # Insert text after the paragraph that contains the image
                    footnote_inserted = False
                    for j in range(i, len(paragraphs)):
                        paragraph = paragraphs[j]
                        if any(run.element.xpath('.//pic:pic') for run in paragraph.runs):
                            if not footnote_inserted:
                                new_paragraph = OxmlElement("w:p")
                                
                                # Create the bookmark start
                                bookmark_start = OxmlElement('w:bookmarkStart')
                                bookmark_start.set(qn('w:id'), str(i))
                                bookmark_start.set(qn('w:name'), f"fp_{figure_name}")
                                new_paragraph.append(bookmark_start)

                                for line in meta_text_lines:
                                    new_run = OxmlElement("w:r")
                                    
                                    rPr = OxmlElement('w:rPr')  
                                    rFonts = OxmlElement('w:rFonts')  
                                    rFonts.set(qn('w:ascii'), 'Arial Narrow')
                                    sz = OxmlElement('w:sz')  
                                    sz.set(qn('w:val'), '20') 
                                    rPr.append(rFonts)
                                    rPr.append(sz)
                                    new_run.append(rPr)
                                    
                                    new_text = OxmlElement("w:t")
                                    new_text.text = line
                                    new_run.append(new_text)
                                    new_paragraph.append(new_run)
                                    
                                    # Add a line break
                                    if line != meta_text_lines[-1] and line.strip() != '':
                                        run_break = OxmlElement('w:r')
                                        br = OxmlElement('w:br')
                                        run_break.append(br)
                                        new_paragraph.append(run_break)
                                    
                                # Create the bookmark end
                                bookmark_end = OxmlElement('w:bookmarkEnd')
                                bookmark_end.set(qn('w:id'), str(i))
                                new_paragraph.append(bookmark_end)

                                paragraph._element.addnext(new_paragraph)
                                footnote_inserted = True

    # Save the processed document
    document.save(docx_out)
    print(f"Processed file saved at '{docx_out}'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add figure footnotes to input docx document")
    parser.add_argument("-i", "--input", type = str, required = True, help = "input docx file path")
    parser.add_argument("-o", "--output", type = str, required = True, help = "Ouptu docx file")
    parser.add_argument("-d", "--figure_dir", type = str, required = True, help = "Path to figures directory")
    parser.add_argument("-f", "--footnotes", type = str, required = True, help = "path to standard footnotes yaml")
    args = parser.parse_args()

    add_figure_footnotes(args.input, args.output, args.figure_dir, args.footnotes)
