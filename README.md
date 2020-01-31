# kotatsu

Hackable and easy to deploy imageboard software written in Guile/Scheme.  
It should run right out of the box without the need to setup Apache2, Nginx, or a database.  
By default it will use sqlite3 as the database and the built-in Artanis engine for serving data.  
  
However, if more speed and scalability is required then services such as Apache2, Nginx, PostgresQL, and MySQL are also supported and can be enabled in the config files. This may require some code changes to allow storage of capcode posts.

## Dependencies

* guile 2.2.3
* artanis 0.4.1 
* guile-dbi 2.1.7
* imagemagick
* Nginx(artanis still has issues that require this)
* Kernel version 3.9 or higher (allows binding multiple instances to the same port, for lower kernel versions recommend using Apache2 or Nginx)

## Installation

* Edit the Artanis config file to your liking: `conf/artanis.conf`
* Edit the Kotatsu config file to your liking: `prv/modules/settings.scm`
* Start the server with `./start-server`
