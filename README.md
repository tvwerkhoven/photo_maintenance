# About

This is a collection of scripts to maintain and publish photo archives.

# Archive integrity

To prevent bitrot when the filesystem does not take care of this (e.g. on macOS), one can use `par2` to manually create and check integrity.

# Publishing

To publish pictures in lower resolution to the web or phone, this script scans a source directory for pictures with 5 star rating rating in the IPTC header and exports these pictures in lower resolution to a separate directory. I use this to store more pictures on my iPhone, for example.