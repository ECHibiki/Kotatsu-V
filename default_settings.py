#!/bin/bash/env python3

#NOTE: Because these settings are set as global variables making changes here requires restarting the server

import re

UsingCloudflare = False

BasePath = '/home/wwwrun/4taba/' # Set this to the server root directory with a trailing /
FFpath = '/run/current-system/sw/bin/ffmpeg' # Set this to the ffmpeg command for creating thumbnails (On this server ffmpeg was installed manually to a non $PATH directory located at BasePath+"ffmpeg"). However if ffmpeg is installed at a location in your server users $PATH then you can just set this to FFpath='ffmpeg'

Allow_Email = False # Allow users to post any text (including email addresses) in the Email form field
TimeoutThread = 120 # Amount of seconds users must wait between creating threads
TimeoutPost = 15 # Amount of seconds users must wait between posts
BannerPath = BasePath+'dat' # Location where banner images reside
BannerRandom = False # Should banner rotation pick a random banner or simply cycle through them in order?
BannerRotationTime = 5 # In minutes (This is only used if BannerRandom=False. When banners are random they will change every page load rather than using a rotation time)
Banners = ( 'banner1.jpg', 'banner2.jpg', 'banner3.jpg' )

# The credentials for connecting to the PostgreSQL database
DBNAME = '4taba'
DBUSER = 'postgres'
DBHOST = '127.0.0.1'
DBPASS = ''

# The "BoardInfo" dictionary below uses the board URL as the key, and the value is an ordered tuple of board settings: (title, CSS, defaultUserName, maxThreads, displayMode, uploaders, fileTypes)
# The actual CSS file used will be named "style<CSS>.css"
# for example the following entry: 'a': ('Anime','yotsubab','Anonymous',150,'normal','This is the Anime board') defines the board /a/ with the following settings: it will be titled 'Anime', using the stylesheet styleyotsubab.css, with the default username 'Anonymous', 150 maximum threads, and a normal display
# The displayMode option may either be "normal", "all" (posting disabled, displays all threads), "listed" (posting disabled, displays all threads from listed boards), "unlisted" (posting disabled, displays all threads from unlisted boards), or "flash" (flash-style thread listing)
# The uploaders option determines who may upload files in a thread. Options are: "all", "OP", "posters", or "none"
# The fileTypes option may either be "all", "noflash" (all filetypes except flash/html5), or "flash" (flash/html5)
BoardInfo = { 'listed': ('All Listed Boards', 'main', '', 150, 'listed', 'none', ''),
            'unlisted': ('All Unlisted Boards', 'default', '', 150, 'unlisted', 'none', ''),
            'all': ('All Boards', 'main', '', 150, 'all', 'none', ''),
            'a': ('Anime', 'yotsubab', 'Anonymous', 150, 'normal', 'all', 'noflash'),
            'ma': ('Manga', 'yotsubab', 'Anonymous', 150, 'normal', 'all', 'noflash'),
            'jp': ('Otaku Culture', 'dis', 'Anonymous', 150, 'normal', 'all', 'noflash'),
            'd': ('二次元エロ', 'yotsuba', 'Anonymous', 150, 'normal', 'all', 'noflash'),
            'ni': ('日本語と英語', 'dis', 'Anonymous', 150, 'normal', 'none', ''),
            'hw': ('Hardware', 'default', 'Anonymous', 150, 'normal', 'none', ''),
            'sw': ('Software & Operating Systems', 'default', 'Anonymous', 150, 'normal', 'none', ''),
            'pr': ('Programming', 'default', 'Anonymous', 150, 'normal', 'none', ''),
            'f': ('Flash', 'yotsuba', 'Anonymous', 15, 'flash', 'OP', 'flash'),
            'lit': ('Literature', 'yotsubab', 'Anonymous', 150, 'normal', 'noflash', 'all'),
            'sci': ('Science & Mathematics', 'yotsubab', 'Anonymous', 150, 'normal', 'none', ''),
            'sf': ('Science Fiction', 'yotsuban', 'Anonymous', 150, 'normal', 'noflash', 'all'),
            'v': ('Video Games', 'eb', 'Anonymous', 150, 'normal', 'noflash', 'all'),
            'ho': ('Other', 'yotsuba', 'Anonymous', 150, 'normal', 'noflash', 'all') }

BoardGreetingDir = BasePath+'bMessages' # Every file in this directory will be read as a greeting message to be displayed on a board. For example a file named "a" in this directory will set its contents as the greeting message for the /a/ board
# Note: If you change/remove/add files in the greetings directory you will need to restart the server for it to take effect
# Note2: Messages are read as HTML. You can create files to display messages on both listed and unlisted boards. If a message isn't found for a listed board then it will be blank, and if a message isn't found for an unlisted board it will use a defualt message defined in the variable "unlistedMessage" below.
# Note3: Make sure the filenames don't contain any extension such as .txt, or they will be applied to boards such as /a.txt/

# These are the simulated transparency colors for thumbnails. Add an entry for each CSS stylesheet and give the background color in (R,G,B) format one for the OP background color and one for the regular post background color
StyleTransparencies = { 'main': ( (238,238,238), (238,221,204) ),
                        'default': ( (238,238,238), (238,221,204) ),
                        'yotsuba': ( (255,255,238), (240,224,214) ),
                        'yotsubab': ( (238,242,255), (214,218,240) ),
                        'yotsuban': ( (0,0,17), (15,31,41) ),
                        'dis': ( (239,239,239), (239,239,239) ),
                        'eb': ( (238,238,238), (221,221,238) ) }

UnlistedTitle = 'Unlisted' # The board title to display for unlisted boards
UnlistedCSS = 'default' # The CSS file to load for unlisted boards (note: the filename loaded is always "style"+unlistedCSS+".css", so in this case it would be "styledefault.css")
UnlistedUsername = 'Anonymous' # The default username to use on unlisted boards
UnlistedMaxThreads = 150 # Maximum number of threads on unlisted boards
UnlistedDisplayMode = 'normal' # The display mode for unlisted boards (only "normal" or "flash" make any sense here)
UnlistedUploaders = 'none'
UnlistedFiletypes = ''
UnlistedMessage = 'This board has no pre-defined topic. Feel free to use it however you like after reading the <a href="/res/dat/faqEN">FAQ</a> and the <a href="/res/dat/rulesEN">global rules</a>.' # The default greeting for unlisted boards
UnlistedLifetime = 0 # Set this to the number of hours threads on unlisted boards can go without receiving replies before they are deleted. 0 means they live forever (or at least until they fall off the last page of the board)

# List of post filters (this includes quotes, post links, URL highlighting, etc)
#   Parameter 1 - Callback function to filter text if a match is found
#       Callback is called with parameters (start, middle, end) where start is the opening delimeter which was matched, end is the closing delimeter that was matched, and middle is all the text in between
#       Callback function should return new text to replace the matched text, including the delimeters if you want them to remain
#   Parameter 2 - List of opening delimiters to begin matching
#   Parameter 3 - List of closing delimiters to end matching
# NOTE: Filters are applied one after the other, so order can make a difference
#       Posts are already escaped (e.g. ">" characters show up as "&gt;") and newlines are already converted to <br>
Filters = [
            # URL filter
            re.compile(r'(http://|https://|ftp://)([^ ]*)( |<)') # ( |<) not working right

#            [filter_post_link,
#                ['&gt;&gt;'], # >>
#                [' ', '<br>', '(', ')', '[', ']', '{', '}']],
#            [filter_quote,
#                ['&gt;'], # >
#                ['<br>']],
#            [filter_url,
#                ['https://','http://','ftp://'],
#                [' ', '<br>']],
#            [filter_code,
#                ['[code]'],
#                ['[/code]']],
#            [filter_spoiler,
#                ['[spoiler]'],
#                ['[/spoiler]']],

            # Example word filter
#            [filter_duck_roll,
#                ['egg'],
#                ['']],
]
