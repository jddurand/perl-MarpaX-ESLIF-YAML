use strict;
use warnings FATAL => 'all';

package MarpaX::ESLIF::URI::_generic;

# ABSTRACT: YAML Parser using MarpaX::ESLIF

# AUTHORITY

# VERSION

use Carp qw/croak/;
use Data::Section -setup;
use Log::Any qw/$log/;
use MarpaX::ESLIF;

use Log::Log4perl qw/:easy/;
use Log::Any::Adapter;
use Log::Any qw/$log/;
our $defaultLog4perlConf = '
        log4perl.rootLogger              = TRACE, Screen
        log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.stderr  = 0
        log4perl.appender.Screen.layout  = PatternLayout
        log4perl.appender.Screen.layout.ConversionPattern = %d %-5p %6P %m{chomp}%n
        ';
Log::Log4perl::init(\$defaultLog4perlConf);
Log::Any::Adapter->set('Log4perl');

my $ESLIF = MarpaX::ESLIF->new($log);

# -----------------------------------------------
# Grammar for BOM detection using the first bytes
# -----------------------------------------------
my $BOM_SOURCE  = ${__PACKAGE__->section_data('BOM')};
my $BOM_GRAMMAR = MarpaX::ESLIF::Grammar->new($ESLIF, $BOM_SOURCE);

# ----------------
# Grammar for YAML
# ----------------
my $YAML_SOURCE  = ${__PACKAGE__->section_data('YAML')};
my $YAML_GRAMMAR = MarpaX::ESLIF::Grammar->new($ESLIF, $YAML_SOURCE);
print $YAML_GRAMMAR->show();

1;

__DATA__
__[ BOM ]__
#
# Unusual ordering is not considered
#
BOM ::= [\x{00}] [\x{00}] [\x{FE}] [\x{FF}] action => UTF_32BE
      | [\x{FF}] [\x{FE}] [\x{00}] [\x{00}] action => UTF_32LE
      | [\x{FE}] [\x{FF}]                   action => UTF_16BE
      | [\x{FF}] [\x{FE}]                   action => UTF_16LE
      | [\x{EF}] [\x{BB}] [\x{BF}]          action => UTF_8

__[ YAML ]__
#
# Reference: http://yaml.org/spec/1.2/spec.html
#
# --------------------
# Indicator Characters
# --------------------
<c printable>                 ::= [\x{9}\x{A}\x{D}\x{20}-\x{7E}\x{85}\x{A0}-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]:u
<nb json>                     ::= [\x{9}\x{20}-\x{10FFFF}]:u
<c byte order mark>           ::= [\x{FEFF}]:u
<c sequence entry>            ::= "-"
<c mapping key>               ::= "?"
<c mapping value>             ::= ":"
<c collect entry>             ::= ","
<c sequence start>            ::= "["
<c sequence end>              ::= "]"
<c mapping start>             ::= "{"
<c mapping end>               ::= "}"
<c comment>                   ::= "#"
<c anchor>                    ::= "&"
<c alias>                     ::= "*"
<c tag>                       ::= "!"
<c literal>                   ::= "|"
<c folded>                    ::= ">"
<c single quote>              ::= "'"
<c double quote>              ::= '"'
<c directive>                 ::= "%"
<c reserved>                  ::= [@`]
<c indicator>                 ::= [-?:,[]{}#&*!|>'"%@`]
<c flow indicator>            ::= [,[]{}]

# ---------------------
# Line Break Characters
# ---------------------
<b line feed>                 ::= [\x{A}]
<b carriage return>           ::= [\x{D}]
<b char>                      ::= <b line feed>
                                | <b carriage return>
<nb char>                     ::= [\x{9}\x{20}-\x{7E}\x{85}\x{A0}-\x{D7FF}\x{E000}-\x{FEFE}\x{FF00}\x{FFFD}\x{10000}-\x{10FFFF}]:u # <c printable> - <b char> - <c byte order mark>
event ^b_break = completed <b break>  # Triggers a START_OF_LINE zero-length lexeme if the later is predicted
<b break>                     ::= <b carriage return> <b line feed> /* DOS, Windows */
                                | <b carriage return>               /* MacOS upto 9.x */
                                | <b line feed>
<b as line feed>              ::= <b break>
<b non content>               ::= <b break>

# ----------------------
# White Space Characters
# ----------------------
<s space>                     ::= S_SPACE
<s tab>                       ::= [\x{9}]  /* TAB */
<s white>                     ::= <s space>
                                | <s tab>
<ns char>                     ::= [\x{1F}\x{21}-\x{7E}\x{85}\x{A0}-\x{D7FF}\x{E000}-\x{FEFE}\x{FF00}\x{FFFD}\x{10000}-\x{10FFFF}]:u # <nb char> - <s white>

# ------------------------
# Miscellaneous Characters
# ------------------------
<ns dec digit>                ::= [\x{30}-\x{39}] /* 0-9 */
<ns hex digit>                ::= <ns dec digit>
                                | [\x{41}-\x{46}] /* A-F */
                                | [\x{61}-\x{66}] /* a-f */
<ns ascii letter>             ::= [\x{41}-\x{5A}] /* A-Z */
                                | [\x{61}-\x{7A}] /* a-z */
<ns word char>                ::= <ns dec digit>
                                | <ns ascii letter>
                                | "-"
<ns uri char>                 ::= "%" <ns hex digit> <ns hex digit>
                                | <ns word char>
                                | [#;/?:@&=+$,_.!~*'()[]]

<ns tag char>                 ::= "%" <ns hex digit> <ns hex digit>
                                | <ns word char>
                                | [#;/?:@&=+$_.~*'()] # <ns uri char> - "!" - <c flow indicator>
# ------------------
# Escaped Characters
# ------------------
<c escape>                    ::= "\\"
<ns esc null>                 ::= "0"
<ns esc bell>                 ::= "a"
<ns esc backspace>            ::= "b"
<ns esc horizontal tab>       ::= "t"
                                | [\x{9}]
<ns esc line feed>            ::= "n"
<ns esc vertical tab>         ::= "v"
<ns esc form feed>            ::= "f"
<ns esc carriage return>      ::= "r"
<ns esc escape>               ::= "e"
<ns esc space>                ::= [\x{20}]
<ns esc double quote>         ::= '"'
<ns esc slash>                ::= "/"
<ns esc backslash>            ::= "\\"
<ns esc next line>            ::= "N"
<ns esc non breaking space>   ::= "_"
<ns esc line separator>       ::= "L"
<ns esc paragraph separator>  ::= "P"
<ns esc 8 bit>                ::= "x" <ns hex digit> <ns hex digit>
<ns esc 16 bit>               ::= "u" <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit>
<ns esc 32 bit>               ::= "U" <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit>
<c ns esc char>               ::= "\\" <ns esc null>
                                | "\\" <ns esc bell>
                                | "\\" <ns esc backspace>
                                | "\\" <ns esc horizontal tab>
                                | "\\" <ns esc line feed>
                                | "\\" <ns esc vertical tab>
                                | "\\" <ns esc form feed>
                                | "\\" <ns esc carriage return>
                                | "\\" <ns esc escape>
                                | "\\" <ns esc space>
                                | "\\" <ns esc double quote>
                                | "\\" <ns esc slash>
                                | "\\" <ns esc backslash>
                                | "\\" <ns esc next line>
                                | "\\" <ns esc non breaking space>
                                | "\\" <ns esc line separator>
                                | "\\" <ns esc paragraph separator>
                                | "\\" <ns esc 8 bit>
                                | "\\" <ns esc 16 bit>
                                | "\\" <ns esc 32 bit>

# ------------------
# Indentation Spaces
# ------------------
#
# Parameterized rules are not supported by ESLIF.
# Anyway it is exactly here that YAML grammar is not context-free
# so callbacks to user-space are (and must be) used.
#
event ^s_indent_n    = predicted <s indent n>
event ^s_indent_lt_n = predicted <s indent lt n>
event ^s_indent_le_n = predicted <s indent le n>

<s indent n>                  ::= S_SPACE_N          # s-space × n
<s indent lt n>               ::= S_SPACE_LT_N       # s-space × m /* Where m < n */ 
<s indent le n>               ::= S_SPACE_LE_N       # s-space × m /* Where m <= n */

# -----------------
# Separation Spaces
# -----------------
#
event ^s_separate_in_line = predicted <s separate in line>
<s separate in line>          ::= <s white many>
                                | <start of line>

event ^start_of_line = predicted <start of line>
<start of line>               ::= START_OF_LINE

# -------------
# Line Prefixes
# -------------
event ^s_line_prefix_n_block_out = predicted <s line prefix n block out>
event ^s_line_prefix_n_block_in  = predicted <s line prefix n block in>
event ^s_line_prefix_n_flow_out  = predicted <s line prefix n flow out>
event ^s_line_prefix_n_flow_in   = predicted <s line prefix n flow in>

<s line prefix n block out>   ::= <s block line prefix n>
<s line prefix n block in>    ::= <s block line prefix n>
<s line prefix n flow out>    ::= <s flow line prefix n>
<s line prefix n flow in>     ::= <s flow line prefix n>

<s block line prefix n>       ::= <s indent n>
<s flow line prefix n>        ::= <s indent n>
                                | <s indent n> <s separate in line>

# -----------
# Empty Lines
# -----------
<l empty n block out>         ::= <s line prefix n block out> <b as line feed>
                                | <s indent lt n>             <b as line feed>
<l empty n block in>          ::= <s line prefix n block in>  <b as line feed>
                                | <s indent lt n>             <b as line feed>
<l empty n flow out>          ::= <s line prefix n flow out>  <b as line feed>
                                | <s indent lt n>             <b as line feed>
<l empty n flow in>           ::= <s line prefix n flow in>   <b as line feed>
                                | <s indent lt n>             <b as line feed>

# ------------
# Line Folding
# ------------
<b l trimmed n block out>     ::= <b non content> <l empty n block out many>
<b l trimmed n block in>      ::= <b non content> <l empty n block in many>
<b l trimmed n flow out>      ::= <b non content> <l empty n flow out many>
<b l trimmed n flow in>       ::= <b non content> <l empty n flow in many>

<b as space>                  ::= <b break>

<b l folded n block out>      ::= <b l trimmed n block out>
                                | <b as space>
<b l folded n block in>       ::= <b l trimmed n block in>
                                | <b as space>
<b l folded n flow out>       ::= <b l trimmed n flow out>
                                | <b as space>
<b l folded n flow in>        ::= <b l trimmed n flow in>
                                | <b as space>

<s flow folded n>             ::= <s separate in line> <b l folded n flow in> <s flow line prefix n>
                                |                      <b l folded n flow in> <s flow line prefix n>

# --------
# Comments
# --------
<c nb comment text>           ::= "#" <nb char any>
<b comment>                   ::= <b non content>
                                | <end of file>

event ^end_of_file = predicted <end of file>
<end of file>                 ::= END_OF_FILE

<s b comment>                 ::=                                          <b comment>
                                | <s separate in line>                     <b comment>
                                | <s separate in line> <c nb comment text> <b comment>
<l comment>                   ::= <s separate in line>                     <b comment>
                                | <s separate in line> <c nb comment text> <b comment>
<s l comments>                ::= <s b comment>   <l comment any>
                                | <start of line> <l comment any>

# ----------------
# Separation Lines
# ----------------
<s separate n block out>     ::= <s separate lines n>
<s separate n block in>      ::= <s separate lines n>
<s separate n flow out>      ::= <s separate lines n>
<s separate n flow in>       ::= <s separate lines n>
<s separate n block key>     ::= <s separate in line>
<s separate n flow key>      ::= <s separate in line>

<s separate lines n>         ::= <s l comments> <s flow line prefix n>
                               | <s separate in line>

# ----------
# Directives
# ----------
<l directive>                ::= "%" <ns yaml directive>     <s l comments>
                               | "%" <ns tag directive>      <s l comments>
                               | "%" <ns reserved directive> <s l comments>
<ns reserved directive>      ::= <ns directive name> <ns directive parameter any>
<ns directive name>          ::= <ns char>+ 
<ns directive parameter>     ::= <ns char>+

# -----------------
# "YAML" Directives
# -----------------
<ns yaml directive>          ::= "Y" "A" "M" "L" <s separate in line> <ns yaml version>
<ns yaml version>            ::= <ns dec digit many> "." <ns dec digit many>

# ----------------
# "TAG" Directives
# ----------------
<ns tag directive>           ::= "T" "A" "G" <s separate in line> <c tag handle> <s separate in line> <ns tag prefix>

# -----------
# Tag Handles
# -----------
<c tag handle>               ::= <c named tag handle>
                               | <c secondary tag handle>
                               | <c primary tag handle>
<c primary tag handle>       ::= "!"
<c secondary tag handle>     ::= "!" "!"
<c named tag handle>         ::= "!" <ns word char any> "!"

# ------------
# Tag Prefixes
# ------------
<ns tag prefix>              ::= <c ns local tag prefix>
                               | <ns global tag prefix>
<c ns local tag prefix>      ::= "!" <ns uri char any>
<ns global tag prefix>       ::= <ns tag char> <ns uri char any>

# ---------------
# Node Properties
# ---------------

# -----------------------------
# Lexemes handled in user space
# -----------------------------
S_SPACE_N                      ~ [\s\S]             # Matches nothing: callback in user space will fill it. Depends on S_SPACE
S_SPACE_LT_N                   ~ [\s\S]             # Matches nothing: callback in user space will fill it. Depends on S_SPACE
S_SPACE_LE_N                   ~ [\s\S]             # Matches nothing: callback in user space will fill it. Depends on S_SPACE
START_OF_LINE                  ~ [\s\S]             # START_OF_LINE is a zero-length lexeme. Depends on <b break> completion
END_OF_FILE                    ~ [\s\S]             # END_OF_LINE is when all bytes are consumed and eof flag is set. Depends on recognizer.

# --------------------------------------------
# Lexemes on which user-space callbacks depend
# --------------------------------------------
S_SPACE                       ~ [\x{20}] /* SP */

# ---------------
# Grammar helpers
# ---------------
<s white many>               ::= <s white>+
<l empty n block out many>   ::= <l empty n block out>+
<l empty n block in many>    ::= <l empty n block in>+
<l empty n flow out many>    ::= <l empty n flow out>+
<l empty n flow in many>     ::= <l empty n flow in>+
<nb char any>                ::= <nb char>*
<l comment any>              ::= <l comment>*
<ns directive parameter any> ::= <ns directive parameter>* separator => <s separate in line>
<ns dec digit many>          ::= <ns dec digit>+
<ns word char any>           ::= <ns word char>+
<ns uri char any>            ::= <ns uri char>*
