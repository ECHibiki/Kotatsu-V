# 4taba Server

This code may not be entirely functional until version 1.0 as many changes are being made to the database functionality.
Please check back in a few weeks (or months) for version 1.0, with a finished README file and setup instructions.

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

- Copy file `default_settings.py` to `local_settings.py` and edit it to your liking
    - Essential variables to change:
        - UsingCloudflare
        - BasePath
        - FFpath
        - DBNAME
        - DBUSER
        - DBHOST
        - DBPASS
- Run `dbinit_4taba` to initialize the database (make sure you set the correct database information in `local_settings.py` first)

Static data such as CSS files go in the `res` directory, and user uploaded files will be saved to `res/brd/<board>/<thread number>`
