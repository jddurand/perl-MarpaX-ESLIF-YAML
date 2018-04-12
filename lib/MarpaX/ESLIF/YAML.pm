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
<c printable>                ::= [\x{9}\x{A}\x{D}\x{20}-\x{7E}\x{85}\x{A0}-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]:u
<nb json>                    ::= [\x{9}\x{20}-\x{10FFFF}]:u
<c byte order mark>          ::= [\x{FEFF}]:u
<c sequence entry>           ::= "-"
<c mapping key>              ::= "?"
<c mapping value>            ::= ":"
<c collect entry>            ::= ","
<c sequence start>           ::= "["
<c sequence end>             ::= "]"
<c mapping start>            ::= "{"
<c mapping end>              ::= "}"
<c comment>                  ::= "#"
<c anchor>                   ::= "&"
<c alias>                    ::= "*"
<c tag>                      ::= "!"
<c literal>                  ::= "|"
<c folded>                   ::= ">"
<c single quote>             ::= "'"
<c double quote>             ::= '"'
<c directive>                ::= "%"
<c reserved>                 ::= [@`]
<c indicator>                ::= [-?:,[]{}#&*!|>'"%@`]
<c flow indicator>           ::= [,[]{}]

# ---------------------
# Line Break Characters
# ---------------------
<b line feed>                ::= [\x{A}]
<b carriage return>          ::= [\x{D}]
<b char>                     ::= <b line feed>
                               | <b carriage return>
<nb char>                    ::= [\x{9}\x{20}-\x{7E}\x{85}\x{A0}-\x{D7FF}\x{E000}-\x{FEFE}\x{FF00}\x{FFFD}\x{10000}-\x{10FFFF}]:u # <c printable> - <b char> - <c byte order mark>
event ^b_break = completed <b break>  # Triggers a START_OF_LINE zero-length lexeme if the later is predicted
<b break>                    ::= <b carriage return> <b line feed> /* DOS, Windows */
                               | <b carriage return>               /* MacOS upto 9.x */
                               | <b line feed>
<b as line feed>             ::= <b break>
<b non content>              ::= <b break>

# ----------------------
# White Space Characters
# ----------------------
<s space>                    ::= S_SPACE
<s tab>                      ::= S_TAB
<s white>                    ::= S_WHITE
<ns char>                    ::= [\x{1F}\x{21}-\x{7E}\x{85}\x{A0}-\x{D7FF}\x{E000}-\x{FEFE}\x{FF00}\x{FFFD}\x{10000}-\x{10FFFF}]:u # <nb char> - <s white>

# ------------------------
# Miscellaneous Characters
# ------------------------
<ns dec digit>               ::= [\x{30}-\x{39}] /* 0-9 */
<ns hex digit>               ::= <ns dec digit>
                               | [\x{41}-\x{46}] /* A-F */
                               | [\x{61}-\x{66}] /* a-f */
<ns ascii letter>            ::= [\x{41}-\x{5A}] /* A-Z */
                               | [\x{61}-\x{7A}] /* a-z */
<ns word char>               ::= <ns dec digit>
                               | <ns ascii letter>
                               | "-"
<ns uri char>                ::= "%" <ns hex digit> <ns hex digit>
                               | <ns word char>
                               | [#;/?:@&=+$,_.!~*'()[]]

<ns tag char>                ::= "%" <ns hex digit> <ns hex digit>
                               | <ns word char>
                               | [#;/?:@&=+$_.~*'()] # <ns uri char> - "!" - <c flow indicator>
# ------------------
# Escaped Characters
# ------------------
<c escape>                   ::= "\\"
<ns esc null>                ::= "0"
<ns esc bell>                ::= "a"
<ns esc backspace>           ::= "b"
<ns esc horizontal tab>      ::= "t"
                               | [\x{9}]
<ns esc line feed>           ::= "n"
<ns esc vertical tab>        ::= "v"
<ns esc form feed>           ::= "f"
<ns esc carriage return>     ::= "r"
<ns esc escape>              ::= "e"
<ns esc space>               ::= [\x{20}]
<ns esc double quote>        ::= '"'
<ns esc slash>               ::= "/"
<ns esc backslash>           ::= "\\"
<ns esc next line>           ::= "N"
<ns esc non breaking space>  ::= "_"
<ns esc line separator>      ::= "L"
<ns esc paragraph separator> ::= "P"
<ns esc 8 bit>               ::= "x" <ns hex digit> <ns hex digit>
<ns esc 16 bit>              ::= "u" <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit>
<ns esc 32 bit>              ::= "U" <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit>
<c ns esc char>              ::= "\\" <ns esc null>
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
# Parameterized rules are not supported by ESLIF, we use a lexeme
# to handle the inner loop
#
event ^s_indent_n    = predicted <s indent n>
event ^s_indent_lt_n = predicted <s indent lt n>
event ^s_indent_le_n = predicted <s indent le n>

<s indent n>                ::= S_SPACE_N          # s-space × n
<s indent lt n>             ::= S_SPACE_LT_N       # s-space × m /* Where m < n */ 
<s indent le n>             ::= S_SPACE_LE_N       # s-space × m /* Where m <= n */

S_SPACE_N                     ~ [\s\S]             # Matches nothing: callback in user space will fill it
S_SPACE_LT_N                  ~ [\s\S]             # Matches nothing: callback in user space will fill it
S_SPACE_LE_N                  ~ [\s\S]             # Matches nothing: callback in user space will fill it

# -----------------
# Separation Spaces
# -----------------
#
<s separate in line>        ::= S_WHITE_MANY
                              | START_OF_LINE

S_WHITE_MANY                  ~ [\s\S]             # Matches nothing: callback in user space will fill it, including start_of_line
START_OF_LINE                 ~ [\s\S]             # START_OF_LINE is a zero-length lexeme automatically trigger when <b break> is completed

# -------------
# Line Prefixes
# -------------
<s line prefix n block out> ::= <s block line prefix n>
<s line prefix n block in>  ::= <s block line prefix n>
<s line prefix n flow out>  ::= <s flow line prefix n>
<s line prefix n flow in>   ::= <s flow line prefix n>

# --------------------------------------------
# Lexemes on which user-space callbacks depend
# --------------------------------------------
S_SPACE                       ~ [\x{20}] /* SP */
S_TAB                         ~ [\x{9}]  /* TAB */
S_WHITE                       ~ S_SPACE
                              | S_TAB
