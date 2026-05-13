\ set screen size - top left is (1, 1)
80 CONSTANT width
24 CONSTANT height
1 CONSTANT ball_ymin \ all the way to the top
22 CONSTANT ball_ymax \ room at btm for bat & score

\ send ESC char 
: esc ( char -- ) 0x1b emit emit ;

\ clear the screen 
: cls 'H' esc 'J' esc ; 

\ position cursor 
: at ( x y -- ) 'Y' esc 31 + emit 31 + emit ;

\ cursor to 1,1 
: home 0 0 at ;

\ ball position and velocity
VARIABLE x
VARIABLE y
VARIABLE dx
VARIABLE dy

\ bat position and size 
VARIABLE batx ( centre of bat )
VARIABLE baty
VARIABLE batw ( bat width in chars )
VARIABLE halfbat ( # bat chars either side of the central one )
VARIABLE batminx ( minimum value for bat-centre x )
VARIABLE batmaxx ( maximum value for bat-centre x )
VARIABLE batleftx ( x cord of left-edge of bat )
VARIABLE batrightx ( x cord of right-edge of bat )

\ stuff that's dependent on bat width
5 batw !
batw @ 2/ dup halfbat ! ( halfbat -- )
dup 1 + batminx ! ( halfbat -- ) \ min x coord of bat centre
dup width swap - batmaxx ! ( halfbat -- ) \ max x coord of bat centre
dup batx @ swap - batleftx ! ( halfbat -- ) \ left end x coord
dup batx @ + batrightx ! ( -- ) \ right end x coord


\ score position & amount
VARIABLE score
VARIABLE scorex
VARIABLE scorey
33 scorex ! 24 scorey !

\ system ticks: 32 bit counter, highly FW version-specific! 
0xff04 CONSTANT ticks_lo
0xff06 CONSTANT ticks_hi

\ timer related variables
VARIABLE last_tick_lo
VARIABLE last_tick_hi
VARIABLE delta
VARIABLE ball_ticks
VARIABLE bat_ticks
VARIABLE ball_tick_delta
VARIABLE bat_tick_delta

\ misc flags & vars
VARIABLE gameover

\ initialise everything
: init_game
    \ init score & state
    0 gameover !
    0 score ! 

    \ init the bat
    16 ball_tick_delta !
    1 bat_tick_delta !
    40 batx ! 23 baty ! 

    \ init the ball
    1 x !
    1 y !
    1 dx !
    1 dy !
;

\ utility words 
: >= ( n1 n2 -- flag ) < 0= ;
: <= ( n1 n2 -- flag ) > 0= ;

\ change the sign of a VARIABLE
: flip ( addr -- ) dup @ negate swap ! ;

\ change the sign of dx
: negdx dx flip ;

\ change the sign of dy
: negdy dy flip ;

\ compute new x and y positions
: xdx x @ dx @ + ;
: ydy y @ dy @ + ;

\ player scored a point
: score_point
    1 score +! \ score 1 pt for a bat back
    score @ 0x1 and 0= IF \ every 2 points, speed up the ball
        ball_tick_delta @  1 - 0 max ball_tick_delta !
    THEN
    score @ 0x3 and 0= IF \ every 4 points slow down the bat
        bat_tick_delta @  1 + 255  min bat_tick_delta !
    THEN
;

: game_over
    cls
    36 12 at ." GAME OVER"
    33 14 at ." SCORE " score @ 8 U.R
    0 22 at
;


\ update ball x 
: updx xdx dup dup 1 < swap width > or IF
    drop negdx xdx
  THEN 
    x !
;

\ update ball y 
\ : updy ydy dup dup ball_ymin < swap ball_ymax > or IF
\    drop negdy ydy
\  THEN 
\    y !
\ ;

\ update ball y ( now bat aware! ) 
: updy
    ydy dup ( ny ny )
    ball_ymax > IF ( ny ) \ off the bottom
        \ drop negdy ydy ( ny1 ) \ OLD VERSION: not bat aware, just bounce
        x @ dup batleftx @ >= ( ny1 x flag_l )
        swap batrightx @ <= ( ny1 flag_l flag_r )
        AND IF ( ny ) \ the ball is over the bat
            drop negdy ydy 
            score_point
        ELSE ( ny ) \ the ball is NOT over the bat
            -1 gameover !
        THEN
    ELSE ( ny -- )
        dup ball_ymin < IF ( ny ) \ off the top
            drop negdy ydy ( ny1 )
        THEN
    THEN
        y !
;

\ update ball position 
: upd updx updy ;

\ draw `char` at ball position 
: bdraw ( char -- ) x @ y @ at emit ;

\ erase the ball 
: berase 0x20 bdraw ; 

\ draw the ball 
: bplot 'o' bdraw ;

\ erase the bat ( erase the whole line )
: baterase 0 baty @ at 'K' esc ; 

\ draw the bat 
\ : batplot batx @ batw @ 2/ 1+ - dup batw @ + swap do I baty @ at '=' emit loop ;  
\ : batplot batrightx @ batleftx @ do I baty @ at '=' emit loop ;  
: batplot batleftx @ baty @ at  batw @ 0 do '=' emit loop ;  

\ move the bat by n chars (-ve is left, +ve is right)
: batmove ( n --)
    dup dup
    batx @ + batminx @ max batx !
    batleftx @ + batleftx ! 
    batrightx @ + batrightx ! 
;

\ move the bat left by n chars
: batleft ( n --) 
    negate batmove
;

\ move the bat right by n chars
: batright ( n --) 
    batmove
;


\ delay 
: delay 1000 0 do loop ;

\ test loop
: foo 99 0 do upd '(' emit x @ . ',' emit y @ . ')' emit cr loop ;

\ test loop 2
: bar cls bplot 99 0 do berase baterase upd bplot batplot home delay loop ;  



\ calculate number of 64 Hz ticks since last call
: update_delta 
   ticks_lo @ ticks_hi @ 2dup last_tick_lo @ last_tick_hi @ D- D>S delta !
   last_tick_hi ! last_tick_lo !
;

\ update timers from master delta
: update_timers 
    delta @ ball_ticks +!
    delta @ bat_ticks +!
;

\ display the score
: draw_score
    scorex @ scorey @ at 
    ." SCORE: " score @ 8 U.R
;

\ test loop 3
: play
    init_game
    cls
    update_delta
    bplot
    batplot
    draw_score

    BEGIN
        update_delta
        update_timers

        ball_ticks @  ball_tick_delta @ > IF
            berase
            upd
            bplot
            draw_score
            home
            0 ball_ticks !
        THEN

        bat_ticks @ bat_tick_delta @  > IF
            key? IF
                key 
                dup 'z' = IF
                    baterase
                    1 batleft
                    batplot
                    home
                THEN

                dup 'x' = IF
                    baterase
                    1 batright
                    batplot
                    home
                THEN

                dup 'q' = IF
                    drop exit
                THEN
                drop
            THEN
            0 bat_ticks !
        THEN

    gameover @ UNTIL
    game_over
;
