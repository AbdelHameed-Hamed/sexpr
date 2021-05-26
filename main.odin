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
    source := "(x (y) () (z . w) . (v))";

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
                    if source[j] == '+' || source[j] == '-' { j += 1; }
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
        res := AST{ type = .LIST};
        res.value = "()";
        if len(tokens) == 0 {
            res.type = .NIL;
            res.value = "nil";
            return res;
        }

        determine_paran_range_end_offset :: proc(tokens: []Token) -> int {
            scope_depth := 0;
            for token, i in tokens {
                #partial switch token.type {
                case .L_PARAN:
                    scope_depth += 1;
                case .R_PARAN:
                    scope_depth -= 1;
                    if scope_depth == 0 {
                        return i;
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

        parse_dot_rhs :: proc(tokens: []Token, lhs: AST) -> (AST, int) {
            res := AST{ .PAIR, ".", make([dynamic]AST) };
            offset := 0;
            append(&res.children, lhs);
            if len(tokens) == 0 {
                assert(false, "The \".\" is a binary operator and is missing a rhs");
            }

            switch tokens[0].type {
                case .L_PARAN:
                    offset = determine_paran_range_end_offset(tokens[:]);
                    temp_res := parse_list(tokens[1 : offset]);
                    append(&res.children, temp_res);
                    // To account for the initial "("
                    offset += 1;
                case .R_PARAN: fallthrough;
                case .DOT:
                    assert(false, "Invalid rhs for \".\"");
                case .STRING: fallthrough;
                case .NUMBER: fallthrough;
                case .SYMBOL:
                    append(&res.children, AST{ .ATOM, tokens[0].token, make([dynamic]AST) });
                    offset = 1;
            }

            return res, offset;
        }

        for i := 0; i < len(tokens); i += 1 {
            switch tokens[i].type {
            case .L_PARAN:
                end_offset := determine_paran_range_end_offset(tokens[i:]);
                temp_res := parse_list(tokens[i + 1 : i + end_offset]);
                append(&res.children, temp_res);
                i += end_offset;
            case .R_PARAN:
                assert(false, "Invalid: shouldn't be parsing \")\"");
            case .DOT:
                last_idx := len(res.children) - 1;
                temp_res, offset := parse_dot_rhs(tokens[i + 1 :], res.children[last_idx]);
                res.children[last_idx] = temp_res;
                i += offset;
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

    AST2 :: struct {
        type: enum {
            NIL,
            ATOM,
            PAIR,
        },
        value: string,
        children: [dynamic]^AST2,
    };

    parse_list_iterative :: proc(tokens: [dynamic]Token) -> AST2 {
        res := AST2{};

        parans: container.Array(rune);
        container.array_init(&parans);
        defer container.array_delete(parans);

        current_root := &res;
        roots: container.Array(^AST2);
        container.array_init(&roots);
        defer container.array_delete(roots);

        for token in tokens {
            switch token.type {
            case .L_PARAN:
                container.array_push_back(&parans, '(');
                container.array_push_back(&roots, current_root);
                current_root = new(AST2);
            case .R_PARAN:
                container.array_pop_back(&parans);
                current_root = container.array_pop_back(&roots);
            case .DOT:
            case .STRING: fallthrough;
            case .NUMBER: fallthrough;
            case .SYMBOL:
            case: assert(false, "Invalid token type");
            }
        }

        return res;
    }

    // ToDo: gotta free the memory properly, but honestly too lazy atm. Just let the OS reclaim the memory
    // once the process exists
    res := parse_list(tokens[:]);

    fmt.println(res);
}