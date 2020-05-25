#!/usr/bin/python3

""" Sample of pre-processing formating script """

__author__ = "xenlo (Laurent G.)"
__license__ = "Apache v2.0"

import fileinput
import re
import sys

preform_txt_regex = re.compile(r"^  ")
code_block = ""

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
for line in fileinput.input():
  if line.startswith("  "):
    code_block = code_block + preform_txt_regex.sub('', line)
  else:
    if code_block != "":
        sys.stdout.write("<syntaxhighlight lang='shell'>\n{}</syntaxhighlight>\n".format(code_block))
        code_block = ""
    sys.stdout.write(line)

