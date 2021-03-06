#!/usr/bin/perl
##
##  Copyright (c) 2010 The WebM project authors. All Rights Reserved.
##
##  Use of this source code is governed by a BSD-style license
##  that can be found in the LICENSE file in the root of the source
##  tree. An additional intellectual property rights grant can be found
##  in the file PATENTS.  All contributing project authors may
##  be found in the AUTHORS file in the root of the source tree.
##


# ads2gas.pl
# Author: Eric Fung (efung (at) acm.org)
#
# Convert ARM Developer Suite 1.0.1 syntax assembly source to GNU as format
#
# Usage: cat inputfile | perl ads2gas.pl > outputfile
#
print "@ This file was created from a .asm file\n";
print "@  using the ads2gas.pl script.\n";
print "\t.equ DO1STROUNDING, 0\n";

while (<STDIN>)
{
    # Comment character
    s/;/@/g;

    # Hexadecimal constants prefaced by 0x
    s/#&/#0x/g;

    # Convert :OR: to |
    s/:OR:/ | /g;

    # Convert :AND: to &
    s/:AND:/ & /g;

    # Convert :NOT: to ~
    s/:NOT:/ ~ /g;

    # Convert :SHL: to <<
    s/:SHL:/ << /g;

    # Convert :SHR: to >>
    s/:SHR:/ >> /g;

    # Convert ELSE to .else
    s/ELSE/.else/g;

    # Convert ENDIF to .endif
    s/ENDIF/.endif/g;

    # Convert ELSEIF to .elseif
    s/ELSEIF/.elseif/g;

    # Convert LTORG to .ltorg
    s/LTORG/.ltorg/g;

    # Convert IF :DEF:to .if
    # gcc doesn't have the ability to do a conditional
    # if defined variable that is set by IF :DEF: on
    # armasm, so convert it to a normal .if and then
    # make sure to define a value elesewhere
    if (s/\bIF :DEF:\b/.if /g)
    {
        s/=/==/g;
    }

    # Convert IF to .if
    if (s/\bIF\b/.if/g)
    {
        s/=+/==/g;
    }

    # Convert INCLUDE to .INCLUDE "file"
    s/INCLUDE(\s*)(.*)$/.include $1\"$2\"/;

    # Code directive (ARM vs Thumb)
    s/CODE([0-9][0-9])/.code $1/;

    # No AREA required
    # But ALIGNs in AREA must be obeyed
    s/^\s*AREA.*ALIGN=([0-9])$/.text\n.p2align $1/;
    # If no ALIGN, strip the AREA and align to 4 bytes
    s/^\s*AREA.*$/.text\n.p2align 2/;

    # DCD to .word
    # This one is for incoming symbols
    s/DCD\s+\|(\w*)\|/.long $1/;

    # DCW to .short
    s/DCW\s+\|(\w*)\|/.short $1/;
    s/DCW(.*)/.short $1/;

    # Constants defined in scope
    s/DCD(.*)/.long $1/;
    s/DCB(.*)/.byte $1/;

    # RN to .req
    if (s/RN\s+([Rr]\d+|lr)/.req $1/)
    {
        print;
        next;
    }

    # Make function visible to linker, and make additional symbol with
    # prepended underscore
    s/EXPORT\s+\|([\$\w]*)\|/.global $1 \n\t.type $1, function/;
    s/IMPORT\s+\|([\$\w]*)\|/.global $1/;

    # No vertical bars required; make additional symbol with prepended
    # underscore
    s/^\|(\$?\w+)\|/_$1\n\t$1:/g;

    # Labels need trailing colon
#   s/^(\w+)/$1:/ if !/EQU/;
    # put the colon at the end of the line in the macro
    s/^([a-zA-Z_0-9\$]+)/$1:/ if !/EQU/;

    # Strip ALIGN
    s/\sALIGN/@ ALIGN/g;

    # Strip ARM
    s/\sARM/@ ARM/g;

    # Strip REQUIRE8
    #s/\sREQUIRE8/@ REQUIRE8/g;
    s/\sREQUIRE8/@ /g;      #EQU cause problem

    # Strip PRESERVE8
    s/\sPRESERVE8/@ PRESERVE8/g;

    # Strip PROC and ENDPROC
    s/\sPROC/@/g;
    s/\sENDP/@/g;

    # EQU directive
    s/(.*)EQU(.*)/.equ $1, $2/;

    # Begin macro definition
    if (/MACRO/) {
        $_ = <STDIN>;
        s/^/.macro/;
        s/\$//g;                # remove formal param reference
        s/;/@/g;                # change comment characters
    }

    # For macros, use \ to reference formal params
    s/\$/\\/g;                  # End macro definition
    s/MEND/.endm/;              # No need to tell it where to stop assembling
    next if /^\s*END\s*$/;
    print;
}
