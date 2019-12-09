use strict;
use warnings FATAL => 'all';

package MarpaX::ESLIF::YAML;

# ABSTRACT: YAML Parser using MarpaX::ESLIF

# AUTHORITY

# VERSION

use Carp qw/croak/;
use Data::Section -setup;
use Log::Any qw/$log/;
use MarpaX::ESLIF 3.0.29;     # if-action uses embedded lua
use MarpaX::ESLIF::URI 0.005; # tag schema
use MarpaX::ESLIF::YAML::PreparseRecognizerInterface;
use MarpaX::ESLIF::YAML::PreparseValueInterface;
use MarpaX::ESLIF::YAML::RecognizerInterface;

use Log::Log4perl qw/:easy/;
use Log::Any::Adapter;
#
# Init log
#
our $defaultLog4perlConf = '
log4perl.rootLogger              = INFO, Screen
log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.stderr  = 0
log4perl.appender.Screen.layout  = PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = %d %-5p %6P %m{chomp}%n
';
Log::Log4perl::init(\$defaultLog4perlConf);
Log::Any::Adapter->set('Log4perl');

# ---------------
# ESLIF singleton
# ---------------
my $ESLIF = MarpaX::ESLIF->new($log);

# -------------------------
# Grammar for YAML Preparse
# -------------------------
my $YAML_SOURCE  = ${__PACKAGE__->section_data('YAML')};
my $YAML_GRAMMAR = MarpaX::ESLIF::Grammar->new($ESLIF, $YAML_SOURCE);
print $YAML_GRAMMAR->show();

sub decode {
    my ($input) = @_;

    my $recognizerInterface = MarpaX::ESLIF::YAML::RecognizerInterface->new(input => $input);
    my $valueInterface = MarpaX::ESLIF::YAML::ValueInterface->new();

    return $YAML_GRAMMAR->parse($recognizerInterface, $valueInterface)
}

1;

__DATA__
__[ YAML ]__
#
# Please note that we do NOT need to deal with BOM: ESLIF natively considers BOM
# when it is character mode.
#
# Reference: http://yaml.org/spec/1.2/spec.html
#
# The order of alternatives inside a production is significant.
# Subsequent alternatives are only considered when previous ones fails.
# See for example the b-break production.
#
autorank is on by default

#
# How to do parameterized rule ? Suppose we have an RHS that is parameterized, i.e.
# LHS ::=  r(n, m)
# We rewrite the rule like this:
#
# LHS                    ::= <r NULLABLE n m> <r PARAM n m>
# event r[n][m]            = nulled <r NULLABLE n m>
# <r NULLABLE n m>       ::=
# <r PARAM n m>            ~ [^\s\S] # Matches nothing
#
# ==> The end-user will have the event "r[n][m]" that it maps to a function
#     with name "r", accepting two arguments "n" and "m". The output
#     of this function will have to be a true value on success, a false value on
#     failure, and this function will be responsible to inject what the grammar
#     expects in the lexeme <r PARAM n m> in case of success.
#
#     In order to be independant of the end-user language, the following implementation
#     uses the embedded LUA interpreter to manage all events.
#
# :default event-action => ::lua->lua_event_action

#
# Chapter 5. Characters
# =====================

#
# 5.1. Character Set
# ------------------
<c printable> ::= /[\x{9}\x{A}\x{D}\x{20}-\x{7E}\x{85}\x{A0}-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]/u
<nb json>     ::= /[\x{9}\x{20}-\x{10FFFF}]/u

#
# 5.2. Character Encodings
# ------------------------
#
# Note: no-op with ESLIF that handle natively encodings
#
<c byte order mark> ::= /\x{FEFF}/u

#
# 5.3. Indicator Characters
# -------------------------
<c sequence entry> ::= “-”
<c mapping key>    ::= “?”
<c mapping value>  ::= “:”
<c collect entry>  ::= “,”
<c sequence start> ::= “[”
<c sequence end>   ::= “]”
<c mapping start>  ::= “{”
<c mapping end>    ::= “}”
<c comment>        ::= “#”
<c anchor>         ::= “&”
<c alias>          ::= “*”
<c tag>            ::= “!”
<c literal>        ::= “|”
<c folded>         ::= “>”
<c single quote>   ::= “'”
<c double quote>   ::= “"”
<c directive>      ::= “%”
<c reserved>       ::= “@”
                     | “`”
<c indicator>      ::= “-”
                     | “?”
                     | “:”
                     | “,”
                     | “[”
                     | “]”
                     | “{”
                     | “}”
                     | “#”
                     | “&”
                     | “*”
                     | “!”
                     | “|”
                     | “>”
                     | “'”
                     | “"”
                     | “%”
                     | “@”
                     | “`”
<c flow indicator> ::= “,”
                     | “[”
                     | “]”
                     | “{”
                     | “}”

#
# 5.4. Line Break Characters
# --------------------------
<b line feed>       ::= /\x{A}/ /* LF */
<b carriage return> ::= /\x{D}/ /* CR */
<b char>            ::= <b line feed>
                      | <b carriage return>
# <nb-char          ::= <c printable> - <b char> - <c byte order mark>
<nb char>           ::= /[\x{9}\x{20}-\x{7E}\x{85}\x{A0}-\x{D7FF}\x{E000}-\x{FEFE}\x{FF00}-\x{FFFD}\x{10000}-\x{10FFFF}]/u
<b break>           ::= <b carriage return> <b line feed> /* DOS, Windows */
                      | <b carriage return>               /* MacOS upto 9.x */
                      | <b line feed>                     /* UNIX, MacOS X */
<b as line feed>    ::= <b break>
<b non content>     ::= <b break>

#
# 5.5. White Space Characters
# ---------------------------
<s space>   ::= <S SPACE>
<s tab>     ::= <S TAB>
<s white>   ::= <s space>
              | <s tab>
# <ns char> ::= <nb char> - <s white>
<ns char>   ::= /[\x{21}-\x{7E}\x{85}\x{A0}-\x{D7FF}\x{E000}-\x{FEFE}\x{FF00}-\x{FFFD}\x{10000}-\x{10FFFF}]/u

#
# 5.6. Miscellaneous Characters
# -----------------------------
<ns dec digit>    ::= /[\x{30}-\x{39}]/ /* 0-9 */
<ns hex digit>    ::= <ns dec digit>
                    | /[\x{41}-\x{46}]/ /* A-F */
                    | /[\x{61}-\x{66}]/ /* a-f */
<ns ascii letter> ::= /[\x{41}-\x{5A}]/ /* A-Z */
                    | /[\x{61}-\x{7A}]/ /* a-z */
<ns word char>    ::= <ns dec digit>
                    | <ns ascii letter>
                    | “-”

<ns uri char>     ::= “%” <ns hex digit> <ns hex digit>
                    | <ns word char>
                    | “#”
                    | “;”
                    | “/”
                    | “?”
                    | “:”
                    | “@”
                    | “&”
                    | “=”
                    | “+”
                    | “$”
                    | “,”
                    | “_”
                    | “.”
                    | “!”
                    | “~”
                    | “*”
                    | “'”
                    | “(”
                    | “)”
                    | “[”
                    | “]”
# <ns tag char>     ::= <ns uri char> - “!” - c-flow-indicator
<ns tag char>       ::= “%” <ns hex digit> <ns hex digit>
                    | <ns word char>
                    | “#”
                    | “;”
                    | “/”
                    | “?”
                    | “:”
                    | “@”
                    | “&”
                    | “=”
                    | “+”
                    | “$”
                    | “_”
                    | “.”
                    | “~”
                    | “*”
                    | “'”
                    | “(”
                    | “)”

#
# 5.7. Escaped Characters
# -----------------------
<c escape>                   ::= “\\”
<ns esc null>                ::= “0”
<ns esc bell>                ::= “a”
<ns esc backspace>           ::= “b”
<ns esc horizontal tab>      ::= “t”
                               | /\x{9}/
<ns esc line feed>           ::= “n”
<ns esc vertical tab>        ::= “v”
<ns esc form feed>           ::= “f”
<ns esc carriage return>     ::= “r”
<ns esc escape>              ::= “e”
<ns esc space>               ::= /\x{20}/
<ns esc double quote>        ::= “"”
<ns esc slash>               ::= “/”
<ns esc backslash>           ::= “\\”
<ns esc next line>           ::= “N”
<ns esc non breaking space>  ::= “_”
<ns esc line separator>      ::= “L”
<ns esc paragraph separator> ::= “P”
<ns esc 8 bit>               ::= “x” <ns hex digit> <ns hex digit>
<ns esc 16 bit>              ::= “u” <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit>
<ns esc 32 bit>              ::= “U” <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit> <ns hex digit>
<c ns esc char>              ::= “\\” <ns esc null>
                               | “\\” <ns esc bell>
                               | “\\” <ns esc backspace>
                               | “\\” <ns esc horizontal tab>
                               | “\\” <ns esc line feed>
                               | “\\” <ns esc vertical tab>
                               | “\\” <ns esc form feed>
                               | “\\” <ns esc carriage return>
                               | “\\” <ns esc escape>
                               | “\\” <ns esc space>
                               | “\\” <ns esc double quote>
                               | “\\” <ns esc slash>
                               | “\\” <ns esc backslash>
                               | “\\” <ns esc next line>
                               | “\\” <ns esc non breaking space>
                               | “\\” <ns esc line separator>
                               | “\\” <ns esc paragraph separator>
                               | “\\” <ns esc 8 bit>
                               | “\\” <ns esc 16 bit>
                               | “\\” <ns esc 32 bit>

#
# Chapter 6. Basic Structures
# ===========================

#
# 6.1. Indentation Spaces
# -----------------------
# <s-indent(n)>          ::= <s space> × n
<s indent n>             ::= <s NULLABLE indent n> <s PARAM indent n>
<s NULLABLE indent n>    ::=
event s_indent[n]          = nulled <s NULLABLE indent n>

# s-indent(<n)           ::= s-space × m /* Where m < n */ 
<s indent lt n>          ::= <s NULLABLE indent lt n> <s PARAM indent lt n>
<s NULLABLE indent lt n> ::=
event s_indent_lt[n]       = nulled <s NULLABLE indent lt n>

# s-indent(<=n)          ::= s-space × m /* Where m <= n */ 
<s indent le n>          ::= <s NULLABLE indent le n> <s PARAM indent le n>
<s NULLABLE indent le n> ::=
event s_indent_le[n]       = nulled <s NULLABLE indent le n>

#
# 6.2. Separation Spaces
# ----------------------
event ^s_separate_in_line = predicted <s separate in line>
<s separate in line> ::= <S WHITE MANY OR START OF LINE>

#
# 6.3. Line Prefixes
# ------------------
# s-line-prefix(n,c)         ::= c = block-out ⇒ s-block-line-prefix(n)
#                                c = block-in  ⇒ s-block-line-prefix(n)
#                                c = flow-out  ⇒ s-flow-line-prefix(n)
#                                c = flow-in   ⇒ s-flow-line-prefix(n)
<s line prefix n c>          ::= <s NULLABLE line prefix n c> <s PARAM line prefix n c>
<s NULLABLE line prefix n c> ::=
event s_line_prefix[n][c]      = nulled <s NULLABLE line prefix n c>

#
# Lexemes
# =======
<s PARAM indent n>              ~ [^\s\S] # Matches nothing
<s PARAM indent lt n>           ~ [^\s\S] # Matches nothing
<s PARAM indent le n>           ~ [^\s\S] # Matches nothing
<S SPACE>                       ~ /\x{20}/ /* SP */
<S TAB>                         ~ /\x{9}/  /* TAB */
<S WHITE MANY OR START OF LINE> ~ /[\s\S]/ /* Matches nothing */
<s PARAM line prefix n c>       ~ /[\s\S]/ /* Matches nothing */

#
# Lua script
# ==========
<luascript>
-----------------------------------------------------------
function input(n)
-----------------------------------------------------------

  -- This function returns current input, ensuring there
  -- are at least n bytes

  input = marpaESLIFRecognizer:input()
  if (input ~= nil) then
    while (input.len < n) do
      if (not marpaESLIFRecognizer.read()) then
        return nil
      end
      input = marpaESLIFRecognizer:input()
      if (input == nil) then
        return nil
      end
    end
  end

  return input
end

-----------------------------------------------------------
function s_indent(m, lexeme_name)
-----------------------------------------------------------
  rc = nil
  
  input = input(m)
  if (input ~= nil) then
    value = string.rep(' ', m)
    if (input:sub(1,m) == value) then
      if ((lexeme_name ~= nil) and (not marpaESLIFRecognizer:lexemeRead(lexeme_name, value, m))) then
        error(lexeme_name..' lexeme read failure')
      else
        rc = value
      end
    end
  end

  return rc
end

-----------------------------------------------------------
function s_indent_lt(n, lexeme_name)
-----------------------------------------------------------
  rc = nil
  
  for m=n-1,1,-1 do
    input = input(m)
    if (input ~= nil) then
      value = string.rep(' ', m)
      if (input:sub(1,m) == value) then
        if ((lexeme_name ~= nil) and (not marpaESLIFRecognizer:lexemeRead(lexeme_name, value, m))) then
          error(lexeme_name..' lexeme read failure')
        else
          rc = value
        end
      end
    end
  end

  return rc
end

-----------------------------------------------------------
function s_indent_le(n, lexeme_name)
-----------------------------------------------------------
  rc = nil
  
  for m=n,1,-1 do
    input = input(m)
    if (input ~= nil) then
      value = string.rep(' ', m)
      if (input:sub(1,m) == value) then
        if ((lexeme_name ~= nil) and (not marpaESLIFRecognizer:lexemeRead(lexeme_name, value, m))) then
          error(lexeme_name..' lexeme read failure')
        else
          rc = value
        end
      end
    end
  end

  return rc
end

-----------------------------------------------------------
function s_separate_in_line(lexeme_name)
-----------------------------------------------------------
    -- We want to match <s white>+ or <start of line>
    rc = nil

    s_white_many_or_start_of_line = ''
    -- First <s white>+
    i = 1
    while (true) do
      input = input(i)
      if (input ~= nil) then
        value = input:sub(i,1)
        if (value == ' ' or value == '\t') then
          s_white_many_or_start_of_line = s_white_many_or_start_of_line..value
          rc = s_white_many_or_start_of_line
        end
      end
    end
    -- Then <start of line>
    if (rc == nil) then
      if (marpaESLIFRecognizer:column() == 0) then
        rc = ''
      end
    end

    if ((lexeme_name ~= nil) and (rc ~= nil) and (not marpaESLIFRecognizer:lexemeRead(lexeme_name, rc, rc:len()))) then
      error(lexeme_name..' lexeme read failure')
    end

    return rc
end

-----------------------------------------------------------
function s_line_prefix(n, c, lexeme_name)
-----------------------------------------------------------
    rc = nil

    if (c == block_out) then
      rc = s_block_line_prefix(n, lexeme_name)
    elseif (c == block_in) then
      rc = s_block_line_prefix(n, lexeme_name)
    elseif (c == flow_out) then
      rc = s_flow_line_prefix(n, lexeme_name)
    elseif (c == flow_in) then
      rc = s_flow_line_prefix(n, lexeme_name)
    end

    return rc
end

-----------------------------------------------------------
function s_block_line_prefix(n, lexeme_name)
-----------------------------------------------------------
    return s_indent(n, lexeme_name)
end

-----------------------------------------------------------
function s_flow_line_prefix(n, lexeme_name)
-----------------------------------------------------------
    rc = s_indent(n, nil)

    if (rc ~= nil) then
      s_separate_in_line = s_separate_in_line(lexeme_name)
      if (s_separate_in_line ~= nil) then
        rc = rc..s_separate_in_line
      end
    end

    return rc
end
</luascript>
