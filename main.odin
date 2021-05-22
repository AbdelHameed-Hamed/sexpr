package main

import "core:fmt"

Token_Type :: enum {
    L_BRACE,
    R_BRACE,
    DOT,
    STRING,
    IDENTIFIER,
}

Token :: struct {
    type: Token_Type,
    token: string,
}

main :: proc() {
    source: string = "(x\":D\")";

    tokens: [dynamic]Token;

    for i := 0; i < len(source); i += 1 {
        switch source[i] {
        case ' ', '\t', '\n':
            continue;
        case '(':
            append(&tokens, Token{ .L_BRACE, source[i:i + 1] });
        case ')':
            append(&tokens, Token{ .R_BRACE, source[i:i + 1] });
        case '.':
            append(&tokens, Token{ .DOT, source[i:i + 1] });
        case '"':
            j := i + 1;
            for source[j] != '\"' do  j += 1;
            append(&tokens, Token { .STRING, source[i:j + 1]});
            i = j;
        case '_', 'A'..'Z', 'a'..'z':
            j := i + 1;
            is_alphanumeric :: proc (c: u8) -> bool {
                switch c {
                    case '_', 'A'..'Z', 'a'..'z', '0'..'9':
                        return true;
                    case:
                        return false;
                }
            }
            for is_alphanumeric(source[j]) do j += 1;
            append(&tokens, Token { .IDENTIFIER, source[i:j + 1]});
            i = j;
        }
    }

    for token in tokens do fmt.println(token);
}