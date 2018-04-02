#!/bin/bash/env python3

#NOTE: Because these settings are set as global variables making changes here requires restarting the server

import re

# Set this to True if your traffic will go through cloudflare
UsingCloudflare = False

BasePath = '/home/wwwrun/4taba/' # Set this to the server root directory
FFpath = 'ffmpeg' # Set this to the ffmpeg command for creating thumbnails. Feel free to set an absolute path or add additional command line arguments

Allow_Email = False # Allow users to post any text (including email addresses) in the Email form field
TimeoutThread = 120 # Amount of seconds users must wait between creating threads
TimeoutPost = 15 # Amount of seconds users must wait between posts
BannerRandom = False # Should banner rotation pick a random banner or simply cycle through them in order?
BannerRotationTime = 5 # In minutes (This is only used if BannerRandom=False. When banners are random they will change every page load rather than using a rotation time)
Banners = ( 'banner1.jpg', 'banner2.jpg', 'banner3.jpg' ) # List of images inside res/banners to use for banners

# The credentials for connecting to the PostgreSQL database
DBNAME = '4taba'
DBUSER = 'postgres'
DBHOST = '127.0.0.1'
DBPASS = ''

# === DECLARE BOARDS HERE ===
# STYLE     - the stylesheet "res/stylesheets/<STYLE>.css" to use on this board
# THREADS   - max thread count on the board
# POSTS     - max post count per thread
# DISPLAY   - "normal" or "flash" style
# OP-UP     - set upload filetypes allowed by OP
#             Add combinations of "img", "vid", and "flash"
#             e.g. use "vid+flash" to create a board that allows videos and flash/html5 but disallows images
#             "vid" flag includes audio files
# POSTER-UP - set upload filetypes allowed by normal (non opening) posts
BoardInfo = {
  #  KEY   ( NAME             STYLE      USERNAME     THREADS POSTS DISPLAY   OP-UP      POSTER-UP )
    'ni':  ('二次元裏',      'dis',     '名無しさん', 150,    200, 'normal', 'img+vid', 'img+vid'),
    'cc':  ('Computer Club', 'default', 'Anonymous',  150,    200, 'normal', 'img+vid', 'img+vid'),
    'f':   ('Flash/HTML5',   'yotsuba', 'Anonymous',  15,     200, 'flash',  'flash',   ''       ),
    'ho':  ('Other',         'yotsuba', 'Anonymous',  150,    200, 'normal', 'img+vid', 'img+vid'),
}
UnlistedBoardInfo = {
  #  KEY    ( NAME               STYLE      USERNAME    THREADS  POSTS  DISPLAY   OP-UP            POSTER-UP )
    '*':    ('Unlisted',        'default', 'Anonymous', 150,     200,  'normal', '',              ''             ),
    'meta': ('Meta Discussion', 'default', 'Anonymous', 150,     200,  'normal', 'img+vid+flash', 'img+vid+flash'),
}
SpecialBoardInfo = {
    ### Avoid modifying these for now
    ### These are special boards. Modifying them should be fairly easy still,
    ### but will require some changes inside the server code, otherwise something might break.
  #  KEY        ( NAME                   STYLE      USERNAME  THREADS  POSTS  DISPLAY   OP-UP  POSTER-UP )
    'listed':   ('All Listed Boards',   'main',    '',        0,       0,    'normal', '',    ''),
    'unlisted': ('All Unlisted Boards', 'default', '',        0,       0,    'normal', '',    ''), 
    'all':      ('All Boards',          'main',    '',        0,       0,    'normal', '',    ''),
}
UnlistedMessage = 'This board has no pre-defined topic. Feel free to use it however you like after reading the <a href="/res/faqEN">FAQ</a> and the <a href="/res/rulesEN">global rules</a>.' # The default greeting for unlisted boards
UnlistedLifetime = 0 # Set this to the number of hours threads on unlisted boards can go without receiving replies before they are deleted. 0 means they live forever (or at least until they fall off the last page of the board)

# List of disallowed board names. In addition to this list any boards containing quotes or beginning with a period are also disallowed for security reasons
BoardBlacklist = ['', 'res']

# Note: If you change/remove/add files in the greetings directory you will need to restart the server for it to take effect
# Note2: Messages are read as HTML. You can create files to display messages on both listed and unlisted boards. If a message isn't found for a listed board then it will be blank, and if a message isn't found for an unlisted board it will use a defualt message defined in the variable "unlistedMessage" below.
# Note3: Make sure the filenames don't contain any extension such as .txt, or they will be applied to boards such as /a.txt/

# These are the simulated transparency colors for thumbnails. Add an entry for each CSS stylesheet and give the background color in (R,G,B) format one for the OP background color and one for the regular post background color
StyleTransparencies = {
                    'main':     ( (238,238,238), (238,221,204) ),
                    'default':  ( (238,238,238), (238,221,204) ),
                    'yotsuba':  ( (255,255,238), (240,224,214) ),
                    'yotsubab': ( (238,242,255), (214,218,240) ),
                    'dis':      ( (239,239,239), (239,239,239) ),
                    'eb':       ( (238,238,238), (221,221,238) ),
}

# NOTE: To set the board greetings for listed boards (the ones defined above) create a file inside the bMessages directory for it


# List of post filters (this includes quotes, post links, URL highlighting, etc)
# Now using regex formatting
# The 1st element is a descriptive label, the 2nd element is the actual regex filter, and the 3rd element is what to replace the text with
# NOTE: Filters are applied one after the other, so order can make a difference
# NOTE: Posts are already escaped (e.g. ">" characters show up as "&gt;") and newlines are already converted to <br>
Filters = [
            # === Post link filters === (Order is important here)
                ('cross-board-cross-thread-post-link',
                 re.compile(r'[^">]&gt;&gt;&gt;/([^/ ]*)/([0-9]+)/([0-9]+)'),
                 '<a href="/\1/\2#\3">&gt;&gt;&gt;/\1/\2/\3</a>')

                ('cross-board-cross-thread-link',
                 re.compile('[^">]&gt;&gt;&gt;/([^/ ]*)/([0-9]+)'),
                 '<a href="/\1/\2">&gt;&gt;&gt;/\1/\2</a>')

                ('cross-board-link',
                 re.compile('[^">]&gt;&gt;&gt;/([^/ ]*)/'),
                 '<a href="/\1">&gt;&gt;&gt;/\1/</a>')

                ('cross-thread-link',
                 re.compile(r'[^">]&gt;&gt;&gt;([0-9]+)/([0-9]+)'),
                 '<a href="/%s/\1#\2">&gt;&gt;&gt;/%s/\1/\2</a>')
                 #NOTE: There is an if-statement in the server code that will look for the label: cross-thread-link
                 #      and fill in the %s's here with the board name

                ('post-link',
                 re.compile(r'[^">]&gt;&gt;([0-9]+)'),
                 '<a href="#\1">&gt;&gt;\1</a>')
            # =========================

            ('quote',
             re.compile(r'(^&gt;[^<]*)'),
             '<span class="quote">\1</span>')

            ('url',
             re.compile(r'(^|>)(&gt;[^<]*)'),
             '<a href="\1\2">\1\2</a>\3')

            ('code',
             re.compile(r'\[code\](.*)\[/code\]'),
             '<span class="code">\1</span>')

            ('japanese',
             re.compile(r'\[ja\](.*)\[/ja\]'),
             '<span class="ja">\1</span>')

            ('spoiler',
             re.compile(r'\[spoiler\](.*)\[/spoiler\]'),
             '<span class="spoiler">\1</span>')
]
