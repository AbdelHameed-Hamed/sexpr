package main

import "core:container"
import "core:fmt"
import "core:mem"
import "core:runtime"

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

// Lexing
tokenize :: proc(source: string) -> [dynamic]Token {
    tokens: [dynamic]Token;

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

    return tokens;
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

parse_list_iterative :: proc(tokens: [dynamic]Token, pool: runtime.Allocator) -> AST2 {
    using container;

    res: ^AST2;

    current_root: ^AST2;

    roots: Array(^AST2);
    array_init(&roots);
    defer array_delete(roots);

    current_to_skip_tree_levels := 0;

    to_skip_tree_levels: Array(int);
    array_init(&to_skip_tree_levels);
    defer array_delete(to_skip_tree_levels);

    construct_pair :: proc(roots: ^container.Array(^AST2), pool: runtime.Allocator) -> ^AST2 {
        current_root := new(AST2, pool);
        current_root.type = .PAIR;
        current_root.value = "()";

        if array_len(roots^) != 0 {
            previous_root := array_get_ptr(roots^, array_len(roots^) - 1);
            append(&previous_root^.children, current_root);
        }

        array_push_back(roots, current_root);

        return current_root;
    }

    for i := 0; i < len(tokens); i += 1 {
        switch tokens[i].type {
        case .L_PARAN:
            array_push_back(&to_skip_tree_levels, current_to_skip_tree_levels);
            current_to_skip_tree_levels = 0;

            current_root = construct_pair(&roots, pool);

            if res == nil {
                res = current_root;
            }
            continue;
        case .R_PARAN:
            array_resize(&roots, array_len(roots) - current_to_skip_tree_levels);
            current_to_skip_tree_levels = array_pop_back(&to_skip_tree_levels);

            current_root = array_pop_back(&roots);
        case .DOT: continue;
        case .STRING: fallthrough;
        case .NUMBER: fallthrough;
        case .SYMBOL:
            current_root = new(AST2, pool);
            current_root.type = .ATOM;
            current_root.value = tokens[i].token;

            previous_root := array_get_ptr(roots, array_len(roots) - 1);
            append(&previous_root^.children, current_root);
        case: assert(false, "Invalid token type");
        }

        if i < len(tokens) - 1 && tokens[i + 1].type != .DOT && tokens[i + 1].type != .R_PARAN {
            current_to_skip_tree_levels += 1;

            current_root = construct_pair(&roots, pool);
        }
    }

    return res^;
}

print_ast :: proc(ast: AST2, indent: int) {
    for i in 0..<indent {
        fmt.print('\t');
    }
    fmt.println(ast.type, ast.value);
    for child in ast.children {
        print_ast(child^, indent + 1);
    }
}

main :: proc() {
    // source: string = "(x\":D\" 0123 -42 0.73)";
    // source := "(x (y) () (z . w) . (v))";
    // (x . ((y) . (() . ((z . w) . (v)))))
    // source := "(x (y . w) (z . (koko wawa)))";
    source := "(x (y z) \":D\")";
    // source := "(x (y) () (z w))";

    tokens := tokenize(source);
    defer delete(tokens);

    // ToDo: gotta free the memory properly, but honestly too lazy atm. Just let the OS reclaim the memory
    // once the process exists
    // res := parse_list(tokens[:]);
    // fmt.println(res);

    using mem;
    pool_raw: Dynamic_Pool;
    dynamic_pool_init(&pool_raw);
    defer dynamic_pool_destroy(&pool_raw);

    pool := dynamic_pool_allocator(&pool_raw);

    res := parse_list_iterative(tokens, pool);
    print_ast(res, 0);
}