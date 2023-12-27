# kotatsu

Hackable and easy to deploy imageboard software written in Guile/Scheme.  
It should run right out of the box without the need to setup Apache2, Nginx, or a database.  
By default it will use sqlite3 as the database and the built-in Artanis engine for serving data.  

However, if more speed and scalability is required then services such as Apache2, Nginx, PostgresQL, and MySQL are also supported and can be enabled in the config files. This may require some code changes to allow storage of capcode posts.

## Dependencies
* Prior deps: ~~libunistring-dev , libffi-dev~~
* guile 3.0.5 ~~( use ./configure --enable-mini-gmp since we don't need high percision digits)~~
* artanis 0.5.1
* guile-dbi 2.1.8 (2.1.7 seems to no longer work , but then again maybe not?)
* imagemagick, ffmpeg and webp
* Nginx(artanis/kotatsu may still issues that require this)
* Kernel version 3.9 or higher (allows binding multiple instances to the same port, for lower kernel versions recommend using Apache2 or Nginx)

## Installation

* Edit the Artanis config file to your liking: `conf/artanis.conf`
* Edit the Kotatsu config file to your liking: `prv/modules/settings.scm`
* Start the server with `./start-server`
* Unicode may not be configured properly on some distros(Ubuntu 18.04). These steps will resolve the annoying ???? unicode issue https://askubuntu.com/questions/770309/cannot-permanently-change-locale-on-16-04-server
