#!/bin/bash/env python3

#NOTE: Because these settings are set as global variables making changes here requires restarting the server

import re

# Set this to True if your traffic will go through cloudflare
UsingCloudflare = False

FFpath = 'ffmpeg' # Set this to the ffmpeg command for creating thumbnails. Feel free to set an absolute path or add additional command line arguments

Allow_Email = False # Allow users to post any text (including email addresses) in the Email form field
TimeoutThread = 120 # Amount of seconds users must wait between creating threads
TimeoutPost = 15 # Amount of seconds users must wait between posts
MaxPostLength = 8000 # Maximum character count per post
MaxPostLines = 200 # Maximum line count per post
PostLineCutoff = 30 # Lines to display on board views (where the post is cut giving a message "view entire thread to see full comment")
BannerRandom = False # Should banner rotation pick a random banner or simply cycle through them in order?
BannerRotationTime = 5 # In minutes (This is only used if BannerRandom=False. When banners are random they will change every page load rather than using a rotation time)
Banners = ( 'banner1.jpg', 'banner2.jpg', 'banner3.jpg' ) # List of images inside res/banners to use for banners

# Threads are only pruned after meeting BOTH of the following conditions:
#   1) When all threads on a board are sorted by bump-order
#      and the thread is beyond the maximum number of threads
#      configured for that board
#   2) The time since it last received a bump is greater than
#      the PruneTime set below
PruneTime = 9676800 # 4 months
AutoPrune = False # Enable this option to turn on auto thread pruning

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
    # Listed boards
    #KEY   ( NAME             STYLE       USERNAME     THREADS POSTS  DISPLAY   OP-UP      POSTER-UP  LISTED )
    'ni':  ('日本裏'  ,      'mona',     '名無しさん', 150,    200,  'normal', 'img+vid', 'img+vid',  True   ),
    'd':   ('二次元エロ',    'yotsuba',  'Anonymous',  150,    200,  'normal', 'img+vid', 'img+vid',  True   ),
    'cc':  ('Computer Club', 'computer', 'guest@cc',   150,    200,  'normal', 'img+vid', 'img+vid',  True   ),
    'f':   ('Flash/HTML5',   'yotsuba',  'Anonymous',  30,     200,  'flash',  'flash',   ''       ,  True   ),
    'ho':  ('Other',         'yotsuba',  'Anonymous',  150,    200,  'normal', 'img+vid', 'img+vid',  True   ),

    # Unlisted boards
    #KEY    ( NAME               STYLE      USERNAME    THREADS POSTS  DISPLAY   OP-UP            POSTER-UP       LISTED )
    '*':    ('Unlisted',        'unlisted', 'Anonymous', 150,    200, 'normal', 'img+vid',       'img+vid',       False  ),
    'meta': ('Meta Discussion', 'unlisted', 'Anonymous', 150,    200, 'normal', 'img+vid+flash', 'img+vid+flash', False  ),

    ### Avoid modifying these for now
    ### These are special boards. Modifying them should be fairly easy still,
    ### but will require some changes inside the server code, otherwise something might break.
    #KEY        ( NAME                   STYLE       USERNAME THREADS POSTS  DISPLAY   OP-UP  POSTER-UP  LISTED )
    'listed':   ('All Listed Boards',   'main',     '',       -1,     0,    'normal', '',    '',         True   ),
    'unlisted': ('All Unlisted Boards', 'unlisted', '',       1500,   0,    'normal', '',    '',         True   ), 
    'all':      ('All Boards',          'main',     '',       -1,     0,    'normal', '',    '',         True   ),
}

# List of disallowed board names. In addition to this list any boards containing quotes or beginning with a period are also disallowed for security reasons
BoardBlacklist = ['', 'res', 'bin']

# Note: If you change/remove/add files in the greetings directory you will need to restart the server for it to take effect
# Note2: Messages are read as HTML. You can create files to display messages on both listed and unlisted boards. If a message isn't found for a listed board then it will be blank, and if a message isn't found for an unlisted board it will use a defualt message defined in the variable "unlistedMessage" below.
# Note3: Make sure the filenames don't contain any extension such as .txt, or they will be applied to boards such as /a.txt/

# These are the simulated transparency colors for thumbnails. Add an entry for each CSS stylesheet and give the background color in (R,G,B) format one for the OP background color and one for the regular post background color
StyleTransparencies = {
                    'main':     ( (238,238,238), (238,221,204) ),
                    'unlisted': ( (238,238,238), (238,221,204) ),
                    'yotsuba':  ( (255,255,238), (240,224,214) ),
                    'mona':     ( (221,221,221), (238,238,238) ),
                    'computer': ( (239,239,239), (239,239,239) ),
}

# List of post filters (this includes quotes, post links, URL highlighting, etc)
# Now using regex formatting
# The 1st element is a descriptive label, the 2nd element is the actual regex filter, and the 3rd element is what to replace the text with
# NOTE: Filters are applied one after the other, so order can make a difference
# NOTE: Posts are already escaped (e.g. ">" characters show up as "&gt;") and newlines are already converted to <br>
Filters = [
            # === Post link filters === (Order is important here)
                ('cross-board-cross-thread-post-link',
                 re.compile(r'(?<!&gt;)&gt;&gt;&gt;/([^/ ]*)/([0-9]+)/([0-9]+)'),
                 r'<a href="/\1/\2#\3">&gt;&gt;&gt;/\1/\2/\3</a>'),

                ('cross-board-cross-thread-link',
                 re.compile('[^">]&gt;&gt;&gt;/([^/ ]*)/([0-9]+)'),
                 r'<a href="/\1/\2">&gt;&gt;&gt;/\1/\2</a>'),

                ('cross-board-link',
                 re.compile('[^">]&gt;&gt;&gt;/([^/ ]*)/'),
                 r'<a href="/\1">&gt;&gt;&gt;/\1/</a>'),

                ('cross-thread-link',
                 re.compile(r'[^">]&gt;&gt;&gt;([0-9]+)/([0-9]+)'),
                 r'<a href="/%s/\1#\2">&gt;&gt;&gt;/%s/\1/\2</a>'),
                 #NOTE: This is not necessarily the most elegant solution
                 #      But for now, there is an if-statement in the server code that will look for the label: cross-thread-link
                 #      and fill in the %s's here with the board name

                ('post-link',
                 re.compile(r'(?<!&gt;)&gt;&gt;([0-9]+)'),
                 r'<a href="/%s/%s#\1">&gt;&gt;\1</a>'),
                 #NOTE: Same here
            # =========================

            ('quote',
             #re.compile(r'(^&gt;[^<]*)'),
             re.compile(r'(^|<br>)(&gt;[^<]*)'),
             r'\1<span class="quote">\2</span>'),

            ('url',
             re.compile(r'([^ >]*)://([^ <]*)'),
             r'<a href="\1://\2">\1://\2</a>'),

#            ('code',
#             re.compile(r'\[code\](.*)\[/code\]'),
#             r'<span class="code">\1</span>'),

#            ('japanese',
#             re.compile(r'\[ja\](.*)\[/ja\]'),
#             r'<span class="ja">\1</span>'),

#            ('spoiler',
#             re.compile(r'\[spoiler\](.*)\[/spoiler\]'),
#             r'<span class="spoiler">\1</span>'),
]
