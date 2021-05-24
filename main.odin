package main

import "core:fmt"
import "core:container"

Token :: struct {
    type: enum {
        L_PARAN,
        R_PARAN,
        DOT,
        STRING,
        NUMBER,
        SYMBOL,
    },
    token: string,
}

is_alpha :: proc(c: u8) -> bool {
    switch c {
        case 'A'..'Z', 'a'..'z':
            return true;
    }

    return false;
}

is_numeric :: proc(c: u8) -> bool {
    switch c {
        case '0'..'9':
            return true;
    }

    return false;
}

is_alphanumeric :: proc(c: u8) -> bool {
    return is_alpha(c) || is_numeric(c);
}

AST :: struct {
    type: enum {
        NIL,
        ATOM,
        PAIR,
        LIST,
    },
    value: string,
    children: [dynamic]AST,
};

main :: proc() {
    // source: string = "(x\":D\" 0123 -42 0.73)";
    source := "(x (y) () (z))";

    tokens: [dynamic]Token;
    defer delete(tokens);

    // Lexing
    for i := 0; i < len(source); i += 1 {
        switch source[i] {
        case ' ', '\t', '\n':
            continue;
        case '(':
            append(&tokens, Token{ .L_PARAN, source[i:i + 1] });
        case ')':
            append(&tokens, Token{ .R_PARAN, source[i:i + 1] });
        case '.':
            append(&tokens, Token{ .DOT, source[i:i + 1] });
        case '"':
            j := i + 1;
            for source[j] != '\"' do  j += 1;

            append(&tokens, Token { .STRING, source[i:j + 1] });
            i = j;
        case '-', '0'..'9':
            j := i;
            if source[j] == '-' { j += 1; }

            for is_numeric(source[j]) do j += 1;
            if source[j] == '.' {
                j += 1;
                for is_numeric(source[j]) do j += 1;
                if source[j] == 'e' {
                    j += 1;
                    for is_numeric(source[j]) do j += 1;
                }
            }

            append(&tokens, Token { .NUMBER, source[i:j] });
            i = j - 1;
        case '_', 'A'..'Z', 'a'..'z':
            j := i;
            for is_alphanumeric(source[j]) || source[j] == '_' do j += 1;

            append(&tokens, Token { .SYMBOL, source[i:j] });
            i = j - 1;
        case:
            fmt.println("Invalid syntax");
            assert(false);
        }
    }

    parse_list :: proc(tokens: []Token) -> AST {
        res := AST{};
        res.type = .LIST;
        res.value = "()";
        if len(tokens) == 0 {
            res.type = .NIL;
            res.value = "nil";
            return res;
        }

        determine_paran_range_end :: proc(tokens: []Token, start: int) -> int {
            scope_depth := 0;
            for token, i in tokens {
                #partial switch token.type {
                case .L_PARAN:
                    scope_depth += 1;
                case .R_PARAN:
                    scope_depth -= 1;
                    if scope_depth == 0 {
                        return start + i;
                    } else if scope_depth < 0 {
                        assert(false, "Scope depth is less than 0");
                    }
                case: continue;
                }
            }

            if scope_depth == 0 {
                fmt.println("No paranthases were encountered\n", tokens, "\n");
            } else if scope_depth > 0 {
                fmt.println("Paranthases mismatch\n", tokens, "\n");
            } else {
                fmt.println("Unknown error\n", tokens, "\n");
            }
            assert(false);
            return 0;
        }

        for i := 0; i < len(tokens); i += 1 {
            switch tokens[i].type {
            case .L_PARAN:
                end := determine_paran_range_end(tokens[i:], i);
                temp_res := parse_list(tokens[i + 1: end]);
                append(&res.children, temp_res);
                i += end - i;
            case .R_PARAN:
                assert(false, "Invalid: shouldn't be parsing \")\"");
            case .DOT: // ToDo
            case .STRING: fallthrough;
            case .NUMBER: fallthrough;
            case .SYMBOL:
                append(&res.children, AST{ .ATOM, tokens[i].token, make([dynamic]AST) });
            case:
                assert(false, "Invalid Token");
            }
        }

        return res;
    }

    // ToDo: gotta free the memory properly, but honestly too lazy atm. Just let the OS reclaim the memory
    // once the process exists
    res := parse_list(tokens[:]);

    fmt.println(res);
}