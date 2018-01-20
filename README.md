# madlibs

Madlib Creator is a library for generating madlib sentences out of preexisting text corpuses.

This project was used as part of the **TV Helper** installation at *Art Hack Day: Deluge* at Pioneer Works, NYC in January 2015.

This library will take a collection of text files and create pseudo-mad lib files out of them.  It performs basic POS (parts-of-speech) tagging on text files and selects sentences that fit a pre-defined set of rules, and tags them for noun replacement.

## Installation Instructions

    bundle install

## Usage Instructions

The library looks for subdirectories within the `texts` directory, each containing text files.  It will create a collection of text files within the `output` directory.

This command will execute the script:

    bundle exec bin/splitter

For each subdirectory within `texts`, it will generate two output text files.  for example, the `texts/example` subdirectory will create a `output/example_1.txt` and an `output/example_2.txt`.  

These text files consist of a list of sentences, one per-line. The number indicates the number of nouns in each sentence.  the nouns themselves have been replaced with a placeholder to facilitate automatic find-and-replace.

The placeholders are:

    nn      Noun                                    aircraft, data
    nnp     Noun, proper                            London, Michael
    nnps    Noun, proper, plural                    Australians, Methodists
    nns     Noun, plural                            women, books

Placeholders will can also be specified in uppercase, e.g. NNS. This signals that the noun that was originalled removed started with an uppercase letter, e.g. Cats.

Additionally, it will also generate a list of removed nouns, for example `output/example_removed_nouns.txt`. This is a sorted list of all the words that have been removed from the texts.

---

*A project from Art Hack Day: Deluge*

