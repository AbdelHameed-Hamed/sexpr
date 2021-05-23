package main

import "core:fmt"

Token_Type :: enum {
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

    ast: AST;

    // Parsing
    for token, i in tokens {
        fmt.println(token);
        switch token.type {
        case .L_PARAN:
        case .R_PARAN:
        }
    }
}