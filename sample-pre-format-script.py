#!/usr/bin/python3

""" Sample of pre-processing formating script """

__author__ = "xenlo (Laurent G.)"
__license__ = "Apache v2.0"

import fileinput
import re
import sys

"""
Walk through the input and replace the 'preformatted text' (starting with 2 spaces) 
into 'Fixed width text' (<code>…</code>).
So from:
  |   echo "key: value" >> /etc/myDaemon.cfg
  |   systemctl reload myDaemon
to:
  | <code>
  | echo "key: value" >> /etc/myDaemon.cfg
  | systemctl reload myDaemon
  | </code> 
"""
def render_code_block(lines):
  preform_txt_regex = re.compile(r"^  ")
  code_block = []
  output = []
  for line in lines:
    if line.startswith("  "):
      code_block.append(preform_txt_regex.sub('', line))
    else:
      if code_block != []:
        output.append("<syntaxhighlight lang='shell'>\n")
        output = output + code_block
        output.append("</syntaxhighlight>\n")
        code_block = []
      output.append(line)
  return output

"""
Remove the all 'Category' tags
"""
def remove_category_tags(lines):
  output = []
  for line in lines:
    line_no_cat = re.sub(r'\[\[Cat[ée]gor.*:[^\]]*]]', r'', line)
    if line == "\n" or line_no_cat != "\n":
      output.append(line_no_cat)
  return output

""" Main """
lines_buffer = []
lines_buffer = fileinput.input()
lines_buffer = render_code_block(lines_buffer)
lines_buffer = remove_category_tags(lines_buffer)
for line in lines_buffer:
  sys.stdout.write(line)

