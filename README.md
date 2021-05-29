# sexpr

Simple [S-Expression](https://en.wikipedia.org/wiki/S-expression) parser.

## ToDo

1) Fix an issue with parsing the ')' token. Doesn't pop to to the correct root in some nested lists like this
```
(x (y z) ":D")
```

2) Flatten the structure somewhat? Or at least get rid of the way I currently allocate fragments here and there. A pool allocator would work nicely here, I think.