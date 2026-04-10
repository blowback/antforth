# AntForth

A modern Forth for the [Feersum Technology MicroBeast](https://feersumbeasts.com/microbeast.html).

(And by "modern" I means ANS Forth standard circa 1997!)

Here's it running on the target hardware:

![antforth running on microbeast](images/antforth.png)

We've got most of the CORE words from the standard, but it 
won't be genuinely useful until we've got some BDOS integration 
working so you can load save files on the 'Beast itself. 

Small barebones systems often suffer from not having easy to 
use development tools, particularly during their genesis, and 
this is the niche that Forth was born for!

And if you're thinking "there's not much modern about a 56 year 
old language on a 50 year old processor" then wait til you see 
how I implemented it using state-of-the-art agentic LLMs...


![antforth venn diagram](images/venn.svg)
