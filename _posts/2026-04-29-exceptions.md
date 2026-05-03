---
layout: post
title: "Exception handling and internal error migration"
date: 2026-04-29
---

Epic 11 will give us exception handling - the [ANS Forth "EXCEPTION" word-set](https://forth-standard.org/standard/exception) and 
also the [ANS Forth "EXCEPTION-EXT" word-set](https://forth-standard.org/standard/exception) - although  the user should note 
that as of 2017 "EXCEPTION-EXT" is no longer optional and now considered mandatory,
so "EXCEPTION-EXT" is itself exceptional, it would seem.

AntForth is not shy! It includes both!

Note that ANS Forth's exception handling centres around the `THROW`, `CATCH`, `ABORT` and 
`ABORT"` words, which differ from many traditional implementations with words like `ALERT`, 
`(ALERT)`, `ESCAPE`, `EXCEPT` etc.


## Planning

Nothing too remarkable, just the usual cycle of `/bmad-create-story`, `/mad-dev-story` and
`/bmad-code-review` finishing off with a retro `/bmad-bmm-retrospective`.

## CATCH and THROW 

The `CATCH` word sets up an exception handling context: any exceptions that are thrown (by the 
`THROW` keyword) within the exception context are handled by the code that immediately follows it. 

If the exception *handling* code immediately follows `CATCH` how do we tell it what code to 
execute in the exception *context* - i.e. the code we want to run that might `throw` ? 

We use an *execution token*, which is Forth's equivalent of a pointer to a function. It's the 
address of a word's implementation. If you're thinking "that sounds like the Code Field Address 
of the word" then you'd be right (for an indirect threaded Forth like AntForth).

The usual approach is something like this:

```Forth
: safe/ ( n1 n2 -- n1/n2 | 0 error-code )
  ['] / catch ;  \ Executes / , catches error if n2 is 0

: test-division
  10 0 safe/ ?dup IF
    ." Error occurred: " . cr \ Handles error (e.g., prints -50, etc.)
  ELSE
    ." Result: " . cr        \ Executes if no error
  THEN ;

```

Let's see it in action:

![Catch exception handler](/antforth/assets/images/2026-04-29/catch.png)

We get the *xt* for the builtin `/` word and use `CATCH` to execute it. If that code throws 
an exception (for example, attempted division by zero) then whatever value was thrown goes in 
TOS execution immediately resumes with the word following `CATCH`. Otherwise if no exception 
was thrown (or if a 0 was explicitly thrown) `CATCH` pushes a zero  onto TOS and continues.

`?DUP` duplicates TOS only if it is non-zero, so it's only going to DUP if an exception was 
thrown. If an exception was thrown, `?DUP` duplicates the error code so that we can both 
test it with `IF` **and** print it out with `.`. But if an exception wasn't thrown TOS contains 
zero, so we don't `?DUP`, `IF` consumes the 0 in TOS and the `.` in the `ELSE` clause prints
the value of the division operation, which was underneath TOS.

Here's what it looks like when the exception *isn't* thrown:

![Catch exception handler no exception](/antforth/assets/images/2026-04-29/catch2.png)

`THROW` simply takes an error code from TOS and throws it:

```Forth
: check-range ( n -- )
  dup 10 > IF -99 throw THEN ; \ Throws -99 if n > 10

```

Note that that includes error code 0. The -1 error code is special, and performs the action 
of the `ABORT` word (more details below). Similarly -2 is special, and performs the action 
of the `ABORT"` ("abort-quote") word, more details below.

## Rethrowing

Exception handlers nest, so it is quite acceptable to handle an exception, do some cleanup, 
and then re-throw the exception to a higher level exception handler:

```Forth
: managed-word
  ['] risky-word catch
  dup IF \ If an error happened
    ." Cleaning up..." cr
    throw \ Rethrow the original error
  THEN ;

```

## ABORT 

`ABORT` (or `-1 throw`) immediately quits execution, and, crucially **clears the data and 
return stacks**. 

```Forth
: PROCESS-DATA ( n -- )
  DUP 100 > IF
    DROP
    CR ." Value too high, aborting."
    ABORT
  THEN
  . ;

50 PROCESS-DATA   \ Output: 50 ok
150 PROCESS-DATA  \ Output: Value too high, aborting. ok

```

## ABORT"

`ABORT"` is a compile-time word that parses a string (ending with a `"`). At *run-time*, it 
removes a value from TOS and if it's not zero it displays the string that was defined, 
then follows up with the usual `ABORT` sequence (clearing the stacks).

## Error codes 

Here's a complete list of AntForth's error codes. Values between -1 and -255 are reserved 
for the [ANS Forth standard assignments 9.3.4](https://forth-standard.org/standard/exception).

Values between -4095 and -256 are reserved for use by AntForth itself.

Positive non-zero values are available for custom user error codes.

|Error code | Where | Meaning |
|-----------|-------|---------|
|-1|Standard|`ABORT`|
|-2|Standard|`ABORT"`|
|-3|Standard|Stack overflow|
|-4|Standard|Stack underflow|
|-5|Standard|Return Stack overflow|
|-6|Standard|Return Stack underflow|
|-7|Standard|DO loops nested too deep|
|-8|Standard|Dictionary overflow|
|-9|Standard|Invalid memory address|
|-10|Standard|Division by zero|
|-11|Standard|Result out of range|
|-12|Standard|Argument type mismatch|
|-13|Standard|Undefined word|
|-14|Standard|Interpreting a compile-only word|
|-15|Standard|Invalid `FORGET`|
|-16|Standard|Attempt to use zero-length string as a name|
|-17|Standard|Pictured numeric output string overflow|
|-18|Standard|Parsed string overflow|
|-19|Standard|Definition name too long|
|-20|Standard|Write to a read-only location|
|-21|Standard|Unsupported operation|
|-22|Standard|Control structure mismatch|
|-23|Standard|Address alignment exception|
|-24|Standard|Invalid numeric argument|
|-25|Standard|Return stack imbalance|
|-26|Standard|Loop parameters unavailable|
|-27|Standard|Invalid recursion|
|-28|Standard|User interrupt|
|-29|Standard|Compiler nesting|
|-30|Standard|Obsolescent feature|
|-31|Standard|`>BODY` used on non-`CREATE` definition|
|-32|Standard|Invalid name argument|
|-47|Standard|Compilation word list deleted|
|-48|Standard|Invalid postpone|
|-49|Standard|Search order overflow|
|-50|Standard|Search order underflow|
|-51|Standard|Compilation word list changed|
|-52|Standard|Control flow stack overflow|
|-53|Standard|Exception stack overflow|
|-56|Standard|`QUIT`|
|-57|Standard|Exception sending/receiving char|
|-58|Standard|`[IF]`, `[ELSE]` or `[THEN]` exception|
|-258|System|Bad operand (asm)|
|-259|System|Nested `CODE` (asm)|
|-260|System|`CODE` needs name (asm)|
|-261|System|`END-CODE` without `CODE` (asm)|
|-262|System|LABEL must precede opcodes (asm)|
|-263|System|JR out of range (asm)|
|-264|System|Too many labels (asm)|
|-265|System|Too many fixups (asm)|
|-266|System|EQU outside CODE (asm)|
|-267|System|Bare integer (asm)|
|-268|System|Unresolved label (asm)|
|-269|System|Already fixed (asm)|
|-270|System|Not in `CODE` (asm)|
|-271|System|Bad Displacement range (asm)|
|-272|System|Bad bit range (asm)|


