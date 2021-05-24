package main

import "core:fmt"
import "core:container"

Token_Type :: enum {
    NONE,
    L_PARAN,
    R_PARAN,
    DOT,
    STRING,
    NUMBER,
    SYMBOL,
}

Token :: struct {
    type: Token_Type,
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
    token: Token,
    children: [dynamic]AST,
}

main :: proc() {
    source: string = "(x\":D\" 0123 -42 0.73)";

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

    // ToDo: gotta free the memory properly, but honestly too lazy atm. Just let the OS reclaim the memory
    // once the process exists
    ast: AST;

    current_root := &ast;
    roots: container.Array(^AST);
    container.array_init(&roots);
    defer container.array_delete(roots);

    // Parsing
    for token in tokens {
        fmt.println(token);
        append(&current_root.children, AST{ token, make([dynamic]AST) });

        switch token.type {
        case .L_PARAN:
            container.array_push_back(&roots, current_root);
            last_idx := len(current_root.children) - 1;
            current_root = &current_root.children[last_idx];
        case .R_PARAN:
            current_root = container.array_pop_back(&roots);
        case .DOT: // ToDo
        case .STRING:
        case .NUMBER:
        case .SYMBOL:
        case .NONE: fallthrough;
        case:
            fmt.println("Invalid AST");
            assert(false);
        }
    }

    if (roots.len != 0) {
        fmt.println("Mismatch in paranthases");
        assert(false);
    }

    fmt.println(ast);
}