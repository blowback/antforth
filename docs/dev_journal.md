# Things we're missing, discovered during the course of development

(It's not for features or big ticket items, but for gaps).

 - `UD.` - display unsigned double precision int 
 - "EXCEPTION" and "EXCEPTION-EXT" environment queries
 - "DOUBLE" and "DOUBLE-EXT" environment queries
 - "SEARCH-ORDER" and "SEARCH-ORDER-EXT" environment queries

## 2025-05-20

OUT and IN don't follow the <dst> <src> convention for register order 
- `A C OUT,` (in the incumbent convention) gives "bad operand". 
