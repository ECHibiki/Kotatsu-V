# 4taba Server

This initial upload is still a "beta version". Please check back in a few weeks (or months) for version 1.0, with a competent README file.

--------------------

## Requirements
- Apache2 (or equivalent, such as nginx)
- PostgresQL
- mod_wsgi with python3
- Python modules:
    - PIL
    - psycopg2

## Apache Configuration

Nothing here yet.

## Server Setup

- Edit file `settings/default_settings.py` to your preferences
- Remember to set the `BoardGreetingDir` to a directory where you will keep board MOTD's
    - For example, to set the greeting on the board /a/ you would create a new file inside your `BoardGreetingDir` named "a" with the greeting text
    - This directory can be anywhere and does not have to lie in the server root. It is read from only when the server starts up and is not served from
- Edit `dbinit_4taba` to set the database connection variables at the top and then run it to initialize the database

Static data such as CSS files go in the `dat` directory, and user uploaded files will be saved to `dat/brd/<board>/<thread number>`
