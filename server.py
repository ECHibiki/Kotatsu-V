#!/bin/bash/env python3

# 4taba.net server code
# Made for Apache + mod_wsgi with python3 (python2 will give encoding or library errors) with Apache configured to serve this script for all requests made to the server aside from static files located at <server_root>/dat
# Before running make sure to complete the following initialization steps first:
#     * Start postgresql, set the database information inside the "dbinit_4taba" script and then run it to initialize the database
#     * create a <server_root>/dat/brd directory to hold user uploaded files

BasePath = '/home/wwwrun/4taba'

import os
import math
import binascii
import psycopg2
from cgi import parse_qs, escape, FieldStorage
from urllib.parse import unquote_plus, parse_qs
from time import strftime, time, gmtime
from PIL import Image
from shutil import rmtree, copyfile, move
from random import randint

os.chdir(BasePath)
import sys
sys.path.append(BasePath)

from settings.default_settings import *
from settings.local_settings import *

if UsingCloudflare:
    IP_HEADER = 'HTTP_CF_CONNECTING_IP'
else:
    IP_HEADER = 'REMOTE_ADDR'

DBconnection = None
Cur = None

BannerCurrent = ''

with open(BasePath+'dat/headerEN','r') as f:
    PageHeader = f.read()
with open(BasePath+'dat/formtopEN','r') as f:
    FtEN = f.read()
with open(BasePath+'dat/formbotEN','r') as f:
    FbEN = f.read()

BoardGreetings = {}
for i in os.listdir(BoardGreetingDir):
    with open(os.path.join(BoardGreetingDir, i), 'r') as f:
        BoardGreetings[i] = f.read()


#############################################################
### THIS IS THE MAIN FUNCTION CALLED BY THE APACHE SERVER ###
#############################################################
def application(environ, start_response):
    databaseConnection() # Connect to database, or reconnect if timed out
    Cur.execute('ROLLBACK') # Get rid of any errors from previous runs so the server doesn't hang

    # Get path and user data, send response and quit when appropriate
    response_body, path, admin, cookieStyle, ip = get_path_and_data(environ)
    if response_body:
        return send_and_finish(response_body, start_response)

    # Parse path and return path information
    userquery, mode, last50, catalog, autoupdate, autoupdateoffset, boardupdate, modParams, login, report = processPath(path, ip)

    # Get user report if reporting a post
    if report:
        return send_and_finish(reportPost(environ, ip), start_response)

    # Process user query (which board or multi-boards they are requesting to view)
    userquery, board, realquery, mixed = processQuery(userquery)
    if '"' in board:
        return send_and_finish('INVALID BOARD NAME', start_response)
        
    # Send thread-updates if requested
    if autoupdate:
        response_body = send_thread_update(autoupdate, autoupdateoffset, board, mode)
        return send_and_finish(response_body, start_response)

    # Send board-updates if requested
    if boardupdate:
        response_body = send_board_update(boardupdate, realquery)
        return send_and_finish(response_body, start_response)

    # Handle mod logins
    if login:
        response_body = mod_login(environ)
        return send_and_finish(response_body, start_response)

    # Process new thread or post if given
    if environ.get('REQUEST_METHOD') == 'POST':
        response_body = new_post_or_thread(environ, path, mode, board, last50, ip, admin, modParams)
        if response_body:
            return send_and_finish(response_body, start_response)

    # Build page or thread and send response
    response_body = load_page(mode, board, mixed, catalog, realquery, userquery, last50, ip, admin, cookieStyle)
    return send_and_finish(response_body, start_response)

#############################################################


def databaseConnection():
    global Cur
    global DBconnection
    if not DBconnection or DBconnection.closed:
        temp = ["dbname='"+DBNAME+"'"] 
        temp += ["user='"+DBUSER+"'"] if DBUSER else []
        temp += ["host='"+DBHOST+"'"] if DBHOST else []
        temp += ["password='"+DBPASS+"'"] if DBPASS else []
        DBconnection = psycopg2.connect(' '.join(temp))
    Cur = DBconnection.cursor()

def send_and_finish(response, start_response): # Calling this function sends the final message to the user
    status = '200 OK'
    response = response.encode()
    response_headers = [('Content-type','text/html'), ('Content-Length', str(len(response)))]
    start_response(status, response_headers)
    return [response]

def fbuffer(f, chunk_size=10000): # Buffer for user uploaded files
    while True:
        chunk = f.read(chunk_size)
        if not chunk: break
        yield chunk

def convertSize(size): # Convert file sizes to human readable
    size_name = ("B", "KB", "MB", "GB")
    i = int(math.floor(math.log(size,1024)))
    p = math.pow(1024,i)
    s = round(size/p,2)
    if (s > 0):
        return '%s %s' % (s,size_name[i])
    else:
        return '0 B'

def processPath(path, ip): # Take the URI path (e.g. 4taba.net/all/5 has path: "/all/5") and return the relevant information
    # PATH MAP:
    # For N=0 N can be eliminated
    #
    # / = index
    # /B = page 0 of board B
    # /B/pN = page N of board B
    # /B/c = catalog of board B
    # /B/cN = page N of catalog on board B (only useful on boards such as "all" which technically can show threads beyond the board thread limit)
    # /B/# = thread # of board B
    # /B/a/#/o = autoupdate thread # on board B at offset o (the offset is the last post the user received in the thread they are auto-updating)
    if path[-1] == '/': path = path[:-1]
    path = path.split('/')
    userquery = '' # userquery is the actual B value (remember it can be combinations of boards like "a+ma")
    mode = -1 # -1 means viewing the thread listing. 0 and higher means viewing a particular thread.
    last50 = False
    catalog = False
    autoupdate = False
    autoupdateoffset = 0
    boardupdate = False
    modParams = [] # Parameters sent to the server by a moderator for things such as deleting posts/threads
    login = False # Is the user requesting a mod login?
    report = False # Is the user reporting a post?
    try:
        if path[1] == 'res': # User resources. Such as the post reporting form.
            if len(path) == 3 and path[2] == 'report':
                report = 1
        elif path[1] == 'mod': # Moderator resources.
            if len(path)==5 and path[2] == 'del':
                modParams = ['delt',path[3],path[4],'']
                mode = -1
                userquery = 'all'
            elif len(path)==6:
                modParams = [path[2],path[3],path[4],path[5]]
            elif len(path)==3 and path[2]=='login':
                login = 1
        elif path[1]: # User is just requesting a (non-blank) board or thread to view/post on
            userquery = path[1]
            if len(path) > 2:
                if path[2][0] in ['p','c']:
                    mode = int(path[2][1:])-1 if len(path[2])>1 else 0
                    if mode > -1:
                        mode = (mode + 1) * -1
                    if path[2][0] == 'c':
                        catalog = 1
                elif path[2][0] == 'b':
                    if len(path[2]) > 1:
                        boardupdate = 2
                    else:
                        boardupdate = 1
                elif len(path) > 3 and path[3] == 'l50':
                    last50 = 1
                    mode = int(path[2])
                elif len(path) > 4:
                    if path[2] == 'a':
                        mode = int(path[3])
                        userquery = path[1]
                        autoupdate = 1
                        autoupdateoffset = int(path[4])
                    if path[2] == 'd':
                        mode = int(path[3])
                        userquery = path[1]
                        autoupdate = 2
                else:
                    mode = int(path[2])

    except(ValueError):
        userquery = ''
        mode = -1
        catalog = 0

    userquery = ''.join(ch for ch in userquery if ch not in ' \/"')
    return [userquery, mode, last50, catalog, autoupdate, autoupdateoffset, boardupdate, modParams, login, report]

def processQuery(userquery): # Process the board query sent by the user (e.g. prepare an SQL string for multiple board requests like "a+ma") and also any timestamp filter (marked by exclamation point, used for the board-watcher) and return the main board
    e = userquery.find('!')
    if e>-1:
        epochquery = userquery[e+1 :]
        if len(epochquery) > 20:
            epochquery = epochquery[:20]
        userquery = userquery[: e]
#    epochquery = int(time())
#    if TEMPquery == '':
#        query = query[: i] + str(epochquery - 86400)
#    else:
#        for j in [q.split('m') for q in TEMPquery.split('h')]:
#            if j == ['']:
#                continue
#            if j[0]:
#                epochquery -= int(j[0]) * 3600
#            if len(j) == 2:
#                epochquery -= int(j[1]) * 60
#        query = query[: i] + str(epochquery)
    mixed = False
    idx = 0
    for i in range(0, len(userquery)):
        idx = i
        if userquery[i] in ['+','-']:
            mixed = True
            idx -= 1
            break
    board = userquery[:idx+1]
    if len(board) > 10:
        board = board[:10]
#    realquery = 'SELECT * FROM t'+' EXCEPT SELECT * FROM t'.join((' INTERSECT SELECT * FROM t'.join((' UNION SELECT * FROM t'.join(userquery.split('+'))).split('/'))).split('-'))
    #realquery = 'SELECT * FROM "b'+'" UNION SELECT * FROM "b'.join(userquery.split('+'))+'"'
    if e>-1:
        ct = '" WHERE ct>'+epochquery
    else:
        ct = '"'
    realquery = 'SELECT * FROM "b'+(ct+' EXCEPT SELECT * FROM "b').join((ct+' UNION SELECT * FROM "b').join(userquery.split('+')).split('-')) + ct

    return [userquery, board, realquery, mixed]

def processComment(comment, board, thread, last50, limited): # Process the user comment to add things such as "greentext", post links, URL's, etc.
    # NOTE: Sorry if this function is confugsing. It looks this way because it was implemented as a stream editor (e.g. it passes through the string only once, character by character, and makes all the changes). I'm aware that it could be made MUCH cleaner, smaller, and easier to read using more "pythonic" syntax, but that would result in scanning the string multiple times which might be slower
    i = 0
    i2 = 0
    tag = 0
    quit = 0 # Quit is only used on posts containing banned text (e.g. links to CP)
    insert = ''
    while i < len(comment):
        if comment[i] == '&' and comment[i+1:i+4] == 'gt;': # This finds ">" in the users comment which are escaped as "&gt;"
            if len(comment)>i+4 and comment[i+4] == '&' and comment[i+5:i+8] == 'gt;':
                i2 = i+8
                while i2 < len(comment) and comment[i2] not in ' 　<-,.':
                    i2 += 1
                inner = comment[i:i2]
                h = inner[8:].split('/')
                if len(h) == 4 and h[0] == '' and h[2].isdigit() and h[3].isdigit():
                    insert = '<a href="/'+h[1]+'/'+h[2]+'#'+h[3]+'">'+inner+'</a>'
                elif len(h) == 3 and h[0] == '' and h[2] == '':
                    insert = '<a href="/'+h[1]+'">'+inner+'</a>'
                elif len(h) == 3 and h[0] == '' and h[2].isdigit():
                    h[1] = h[1].split('+')[0]
                    q = inner.split('+')
                    inner = q[0]+'/'
                    if len(q)>1:
                        r = q[1].split('/')
                        inner += '/'.join(r[1:])
                    insert = '<a href="/'+h[1]+'/'+h[2]+'">'+inner+'</a>'
                elif len(h) == 2 and h[0].isdigit() and h[1].isdigit():
                    insert = '<a href="/'+board+'/'+h[0]+'#'+h[1]+'">'+inner+'</a>'
                elif len(h) == 1 and h[0].isdigit():
                    insert = '<a href="/'+board+'/'+str(thread)+'#'+h[0]+'">'+inner+'</a>'
                else:
                    insert = inner
            elif not limited and (i==0 or (i>3 and comment[i-4:i]=='<br>')):
                i2 = i+4
                while i2 < len(comment) and comment[i2] != '<':
                    i2 += 1
                insert = '<span class="quote">' + comment[i:i2] + '</span>'
            else:
                i2 = i
                insert = ''

            comment = comment[0:i] + insert + comment[i2:]
            i += len(insert)

        elif comment[i] == '[':
            if comment[i:i+4] == '[ja]' and not limited:
                tag = 1
                i2 = i+4
                while i2 < len(comment) and comment[i2:i2+5] != '[/ja]':
                    i2 += 1
                insert, quit = processComment(comment[i+4:i2], board, thread, last50, 1)
                insert = '<span class="ja">' + insert + '</span>'
            elif comment[i:i+4] == '[cb]' and not limited:
                tag = 1
                i2 = i+4
                while i2 < len(comment) and comment[i2:i2+5] != '[/cb]':
                    i2 += 1
                insert = '<div class="cb">' + comment[i+4:i2] + '</div>'
            elif comment[i:i+4] == '[sp]':
                tag = 1
                i2 = i+4
                while i2 < len(comment) and comment[i2:i2+5] != '[/sp]':
                    i2 += 1
                insert = '<span class="sp">' + comment[i+4:i2] + '</span>'
            if i2+5 <= len(comment) and tag == 1:
                tag = 0
                i2 += 5
            else:
                insert = ''
                i2 = i
            tag = 0
            comment = comment[0:i] + insert + comment[i2:]
            i += len(insert)
        elif comment[i] == 'h':
            if comment[i:i+7] == 'http://':
                tag = 1
                i2 = i+7
                while i2 < len(comment) and comment[i2] not in ' <':
                    i2 += 1
                insert = '<a href="' + comment[i:i2] + '">' + comment[i:i2] + '</a>'
            elif comment[i:i+8] == 'https://':
                tag = 1
                i2 = i+8
                while i2 < len(comment) and comment[i2] not in ' <':
                    i2 += 1
                insert = '<a href="' + comment[i:i2] + '">' + comment[i:i2] + '</a>'
            elif comment[i:i+6] == 'ftp://':
                tag = 1
                i2 = i+6
                while i2 < len(comment) and comment[i2] not in ' <':
                    i2 += 1
                insert = '<a href="' + comment[i:i2] + '">' + comment[i:i2] + '</a>'
            for j in ['BLOCKED_URL_1','BLOCKED_URL_2']: # Drop posts containing particular website links (e.g. links posted by CP spammers) NOTE: the actual list used by 4taba.net is not shown here to avoid advertising CP sites
                if j in insert:
                    quit = 1
            if tag == 1:
                tag = 0
            else:
                insert = ''
                i2 = i
            comment = comment[0:i] + insert + comment[i2:]
            i += len(insert)

        i += 1
                
    return [comment, quit]

def setOptions(options): # Set options from the "Email" field on the post form
    bump = 1
    email = options if Allow_Email else ''
    options = options.split(' ')
    for i in options:
        if i.lower() in ['sage','さげ','下げ']: # Different ways a post can be saged
            bump = 0
            if not Allow_Email:
                email = i # Even with email disabled the options used will still show as "mailto"
    return bump,email

def getStyle(b): # Return the board style
    if b in BoardInfo:
        style = BoardInfo[b][1]
    else:
        style = UnlistedCSS
    return style

def reportPost(environ, ip): # User is reporting a post (Currently this is very unelegant, it just adds the reports to a text file on the server. In the future there will be a way for mods to view the reports without having to SSH into the server first)
    timestamp = str(int(time()))
    post = FieldStorage(fp=environ['wsgi.input'],environ=environ,keep_blank_values=True)

    try:
        Cur.execute('SELECT b FROM aban WHERE a=%s;', (ip,))
        ban = Cur.fetchone()
    except(psycopg2.ProgrammingError):
        ban = 0
        Cur.execute("ROLLBACK")
    if not ban:
        ban = 0
    else:
        ban = ban[0]
        if ban == 2:
            response_body = '<html><body><h1>Your IP has a been banned.</h1></body></html>'
            return response_body

    try:
        board = escape(post.getfirst('board'))
        tnum = escape(post.getfirst('tnum'))
        pnum = escape(post.getfirst('pnum'))
        reason = escape(post.getfirst('reason'))
    except:
        return 'Please fill out the form Properly.'
    reportBody = 'Board: '+board+'\nThread Number: '+tnum+'\nPost Number: '+pnum+'\nReason: '+reason+'\n\n'
    with open(BasePath+'reports','a') as f:
        f.write(reportBody)
    return '<html><body>The following report has been submitted:<br><br>'+reportBody.replace('\n','<br>')+'<hr><h1>Thank you for your report.</h1></body></html>'

def modAction(password, admin, ip, a, b, t, p): # Uh oh, a mod is taking action
    databaseConnection()
    if admin: #real admin
        if a == 'delt': # delete thread
            Cur.execute('DELETE FROM "b'+b+'" WHERE num=%s;', (t,))
            Cur.execute('DELETE FROM ball WHERE b=%s AND num=%s;', (b, t))
            Cur.execute('DROP TABLE "t'+b+'/'+t+'";')
            DBconnection.commit()
            Cur.execute('SELECT * FROM "b'+b+'" LIMIT 1;')
            if len(Cur.fetchall()) == 0:
                Cur.execute('DROP TABLE "b'+b+'";')
                Cur.execute('DELETE FROM adat WHERE b=%s;', (b,))
                Cur.execute('DELETE FROM un WHERE b=%s;', (b,))
                #DBconnection.commit()
            if os.path.exists(BasePath+'dat/brd/'+b+'/'+t):
                rmtree(BasePath+'dat/brd/'+b+'/'+t)
            if os.listdir(BasePath+'dat/brd/'+b) == []:
                if os.path.exists(BasePath+'dat/brd/'+b):
                    os.rmdir(BasePath+'dat/brd/'+b)
        elif a == 'warn':
            Cur.execute('UPDATE "t'+b+'/'+t+'" SET p = p || \'<br><br><span class="warn">USER WAS WARNED FOR THIS POST</span>\' WHERE c=%s;', (p,))
        elif a == 'del':
            Cur.execute('DELETE FROM "t'+b+'/'+t+'" WHERE c=%s;', (p,))
            Cur.execute('UPDATE "b'+b+'" SET cnt=cnt-1 WHERE num=%s;', (t,))
            Cur.execute('UPDATE ball SET cnt=cnt-1 WHERE num=%s AND b=%s;', (t, b))
        elif a == 'ban':
            Cur.execute('SELECT a FROM "t'+b+'/'+t+'" WHERE c=%s;', (p,))
            ip = Cur.fetchone()[0]
            Cur.execute('INSERT INTO aban VALUES (%s, 2);', (ip,))
            Cur.execute('UPDATE "t'+b+'/'+t+'" a SET p = p || \'<br><br><span class="band">USER WAS BANNED FOR THIS POST</span>\' WHERE c=%s;', (p,))

    elif a == 'udel': # User deleting his own post/thread
        Cur.execute('SELECT a FROM "t'+b+'/'+t+'" WHERE c=%s;', (p,))
        if ip==Cur.fetchone()[0]:
            if p=='1': #delete thread
                Cur.execute('DELETE FROM "b'+b+'" WHERE num=%s;', (t,))
                Cur.execute('DELETE FROM ball WHERE b=%s AND num=%s;', (b, t))
                Cur.execute('DROP TABLE "t'+b+'/'+t+'";')
                DBconnection.commit()
                Cur.execute('SELECT * FROM "b'+b+'" LIMIT 1;')
                if len(Cur.fetchall()) == 0:
                    Cur.execute('DROP TABLE "b'+b+'";')
                    Cur.execute('DELETE FROM adat WHERE b=%s;', (b,))
                    #DBconnection.commit()
                rmtree(BasePath+'dat/brd/'+b+'/'+t)
                if os.listdir(BasePath+'dat/brd/'+b) == []:
                    os.rmdir(BasePath+'dat/brd/'+b)
            else:
                Cur.execute('DELETE FROM "t'+b+'/'+t+'" WHERE c=%s;', (p,))
                Cur.execute('UPDATE "b'+b+'" SET cnt=cnt-1 WHERE num=%s;', (t,))
                Cur.execute('UPDATE ball SET cnt=cnt-1 WHERE num=%s AND b=%s;', (t, b))

## These are OP moderation actions (hiding posts/images), currently removed from the server, but for the time being the code will remain here commented out just in case
    #else: #NON-ADMIN ACTION
    #    Cur.execute('SELECT p FROM "p'+b+'" WHERE t='+t+';')
    #if a != 'udel' and (admin or password == Cur.fetchone()[0]): #OP action
    #    if a == 'fhid':
    #        Cur.execute('SELECT i FROM "t'+b+'/'+t+'" WHERE c='+p+';')
    #        f = Cur.fetchone()[0]
    #        if f[0] == 'o':
    #            move(BasePath+'dat/brd/'+b+'/'+t+'/'+f, BasePath+'dat/brd/'+b+'/'+t+'/h_'+f)
    #            copyfile(BasePath+'dat/fdel.png', BasePath+'dat/brd/'+b+'/'+t+'/'+f)
    #        else:
    #            flst = f.split('/')
    #            for fi in flst:
    #                move(BasePath+'dat/brd/'+b+'/'+t+'/t'+fi+'.jpg', BasePath+'dat/brd/'+b+'/'+t+'/h_t'+fi+'.jpg')
    #                copyfile(BasePath+'dat/fdel.png', BasePath+'dat/brd/'+b+'/'+t+'/t'+fi+'.jpg')
    #    elif a == 'hide':
    #        Cur.execute('UPDATE "t'+b+'/'+t+'" SET x=1 WHERE c='+p+';')
    #    elif a == 'ahid':
    #        Cur.execute('UPDATE "t'+b+'/'+t+'" SET x=1 WHERE c='+p+';')
    #        Cur.execute('SELECT a FROM "t'+b+'/'+t+'" WHERE c='+p+';')
    #        ip = Cur.fetchone()[0]
    #        Cur.execute('INSERT INTO "n'+b+'/'+t+'" VALUES (%s, 1);',(ip,))
    #        Cur.execute('UPDATE "t'+b+'/'+t+'" a SET p = p || \'<br><br><span class="band">USER WAS AUTO-HIDDEN BY OP</span>\' WHERE c='+p+';')
    #    elif a == 'unhide':
    #        Cur.execute('SELECT i FROM "t'+b+'/'+t+'" WHERE c='+p+';')
    #        f = Cur.fetchone()[0]
    #        if f[0] == 'o':
    #            if os.path.exists(BasePath+'dat/brd/'+b+'/'+t+'/h_'+f):
    #                move(BasePath+'dat/brd/'+b+'/'+t+'/h_'+f, BasePath+'dat/brd/'+b+'/'+t+'/'+f)
    #        else:
    #            flst = f.split('/')
    #            for fi in flst:
    #                if os.path.exists(BasePath+'dat/brd/'+b+'/'+t+'/h_t'+fi+'.jpg'):
    #                    move(BasePath+'dat/brd/'+b+'/'+t+'/h_t'+fi+'.jpg', BasePath+'dat/brd/'+b+'/'+t+'/t'+fi+'.jpg')
    #        Cur.execute('UPDATE "t'+b+'/'+t+'" SET x=0 WHERE c='+p+';')
    #        Cur.execute('SELECT a FROM "t'+b+'/'+t+'" WHERE c='+p+';')
    #        ip = Cur.fetchone()[0]
    #        try:
    #            Cur.execute('DELETE FROM "n'+b+'/'+t+'" WHERE a=%s;',(ip,))
    #        except(psycopg2.ProgrammingError):
    #            pass

    DBconnection.commit()

def get_path_and_data(environ): # Get the URI path and other headers sent by the user request
    admin = ''
    cookieStyle = 'default'

    try:
        request_body_size = int(environ.get('CONTENT_LENGTH', 0))
    except(ValueError):
        request_body_size = 0

    path = escape(environ.get('PATH_INFO').encode('iso-8859-1').decode('utf-8'))
    if path == '/':
        with open(BasePath+'dat/indexEN','r') as f:
            response_body = f.read()
            Cur.execute('SELECT * FROM un ORDER BY t DESC LIMIT 8;')
            boards = Cur.fetchall()
            part1 = ''
            for board in boards:
                part1 += '<a href="/'+board[0]+'">/'+board[0]+'/</a><br>'
            response_body = response_body % (part1,)
            return [response_body, path, admin, cookieStyle, '']
    try:
        cookie = escape(environ.get('HTTP_COOKIE'))
        cookie = cookie.split('; ')
        for a in cookie:
            data = a.split('=')
            if data[0] == 'mod':
                if len(data[1])==30:
                    try:
                        Cur.execute('SELECT i FROM amod WHERE c=%s;', (data[1],))
                        temp = Cur.fetchone()
                        if temp:
                            admin = temp[0]
                    except(psycopg2.ProgrammingError):
                        Cur.execute("ROLLBACK")
            elif data[0] == 'style':
                if data[1] == 'tomorrow':
                    cookieStyle = 'tomorrow'
    except(AttributeError):
        pass

    try:
        ip = escape(environ.get('HTTP_CF_CONNECTING_IP'))
    except:
        try:
            ip = escape(environ.get(IP_HEADER))
        except:
            ip = 'error'

    return ['', path, admin, cookieStyle, ip]

def send_thread_update(autoupdate, autoupdateoffset, board, mode):
    if autoupdate == 1:
        Cur.execute('SELECT * FROM "t'+board+'/'+str(mode)+'" WHERE c>=%s ORDER BY c ASC;', (str(autoupdateoffset),))
    posts = Cur.fetchall()
    response_body = str(len(posts))+'   ' if len(posts) > 0 else ''
    for idx, post in enumerate(posts):
        if post[8] == 1:
            ban = 1
        else:
            ban = 0
        response_body += '<div id="'+str(post[7])+'" class="post'+(' hidden' if ban else '')+'" b="'+board+'" t="'+str(mode)+'">'+('<a id="h'+board+'/'+str(mode)+'/'+str(post[7])+'" href="javascript:void(0)" onclick="unhide(this)">[ + ] </a>' if ban else '')+'<a style="color:inherit;text-decoration:none;" onclick="plink(\''+str(post[7])+'\')" href="/'+board+'/'+str(mode)+'#'+str(post[7])+'">'+str(post[7])+'</a>. <span class="name">'+post[4]+'</span> '+post[0]+'<br><div class="fname">'
        imglst = post[3].split('/')
        if imglst[0] != '':
            lcllst = post[1].split('/')
            fsize = post[9].split('/')
            for idi in range(len(imglst)):
                response_body += '<a href="/res/dat/brd/'+board+'/'+str(mode)+'/'+lcllst[idi]+'">'+imglst[idi]+'</a> ['+fsize[idi]+']<br>'
        response_body += '</div>'
        if post[1] != '':
            imglst = post[1].split('/')
            response_body += '<div'+(' style="display:table"' if len(imglst)>1 else '')+'>'
            for imge in imglst:
                response_body += '<a '+('onclick="return false;" target="_blank" ' if imge[-3:]!='swf' else '')+'href="/res/dat/brd/'+board+'/'+str(mode)+'/'+imge+'"><img src="/res/dat/brd/'+board+'/'+str(mode)+'/t'+imge+'.jpg"></a>'
            response_body += '</div>'
        response_body += '<blockquote style="margin-left:'+str(post[10])+'px">'+post[2]+'</blockquote></div>'

    return response_body

def send_board_update(boardupdate, realquery):
    if boardupdate:
        if boardupdate == 2:    #only send initial epoch time
            response_body = str(int(time())) + '  '
        else:                   #send actual board update
            Cur.execute('(%s) ORDER BY t DESC;', (realquery,))
            threads = Cur.fetchall()
            response_body = str(int(time())) + '  ' if len(threads)>0 else ''
            for idc, thread in enumerate(threads):
                tboard = thread[3]
                Cur.execute('SELECT * FROM "t'+board+'/'+str(thread[0])+'" ORDER BY c ASC LIMIT 2;')
                posts = Cur.fetchall()
                title = posts[0][0]
                imageAllow = int(posts[0][2])
                response_body += '<div class="style'+getStyle(tboard)+'"><div class="thread"><div class="tb" style="margin:0px;padding:0px;"><a class="title" href="/'+tboard+'/'+str(thread[0])+'">'+str(thread[0])+'. '+title+'</a> <span class="tag"><a style="font-size:12px;" href="/'+tboard+'">/'+tboard+'/</a></span></div>'
                if posts[1][1] != '':
                    response_body += '<a href="/res/dat/brd/'+tboard+'/'+str(thread[0])+'/'+posts[1][1].split('/')[0]+'"><img class="cimg" src="/res/dat/brd/'+tboard+'/'+str(thread[0])+'/t'+posts[1][1].split('/')[0]+'.jpg"></a>'
                response_body += '<span class="foot">'+str(thread[2])+' replies</span><br>'+posts[1][2]+'</div></div>'
        return response_body

def mod_login(environ):
    if environ.get('REQUEST_METHOD') == 'POST':
        post = parse_qs(environ['wsgi.input'].readline().decode(),True)
#            post = FieldStorage(fp=environ['wsgi.input'],environ=environ,keep_blank_values=True)
        mid = escape(post['id'][0])
        password = escape(post['pass'][0])
        try:
            Cur.execute('SELECT p FROM amod WHERE i=%s;', (mid,))
            if password == Cur.fetchone()[0]:
                code = str(binascii.b2a_hex(os.urandom(15)))[2:-1]
                Cur.execute('UPDATE amod SET c=%s WHERE i=%s;', (code, mid))
                DBconnection.commit()
                response_body = code
            else:
                response_body = 'fail'
        except(psycopg2.ProgrammingError):
            response_body = 'fail'
            Cur.execute("ROLLBACK")
        rtype = 'text/plain'
    else:
        with open(BasePath+'dat/login','r') as f:
            response_body = f.read()
            rtype = 'text/html'

    return response_body

def getFileUpload(fileitem, post, filename, extension, board, threadnum, spoiler, OP, dim):
    loop = 0
    filestring = ''
    localstring = ''
    sizestring = ''
    localname = ''
    while loop<4:
        loop += 1

        fsize='0 B'
        isize = ''
        width = 25

        localname = str(int(time()*1000)+loop)+'.'+extension
        fullpath = BasePath+'dat/brd/'+board+'/'+str(threadnum)
        if not os.path.exists(fullpath):
            os.makedirs(fullpath)
        chunkcount = 1
        with open(fullpath+'/'+localname,'wb',10000) as f:
            for chunk in fbuffer(fileitem.file):
                if chunkcount >= 1259:
                    response_body = '<html><body><h1>Filesize too large. Maximum upload size is 12MB.</h1></body></html>'
                    os.remove(fullpath+'/'+localname)
                    return response_body
                f.write(chunk)
                chunkcount += 1
        if spoiler:
            copyfile(BasePath+'dat/spoiler.jpg', fullpath+'/t'+localname+'.jpg')
        elif extension in ['jpg','jpeg','png','gif']:
            image = Image.open(fullpath+'/'+localname)
            isize = ', '+str(image.size[0])+'x'+str(image.size[1])
            if extension in ['png','gif']:
                image = image.convert('RGBA')
                imageb = Image.new('RGB', image.size, StyleTransparencies[getStyle(board)][0])
                imageb.paste(image, image)
                image = imageb
            image.thumbnail((dim, dim),Image.ANTIALIAS)
            image.save(fullpath+'/t'+localname+'.jpg', 'JPEG', quality=75)
            width = image.size[0]+25
        elif extension in ['webm','mp4','flv']:
            os.system(FFpath+' -i '+fullpath+'/'+localname+' -vf thumbnail -frames:v 1 '+fullpath+'/t'+localname+'.jpg')
            image = Image.open(fullpath+'/t'+localname+'.jpg')
            image.thumbnail((dim, dim),Image.ANTIALIAS)
            image.save(fullpath+'/t'+localname+'.jpg', 'JPEG', quality=75)
            width = image.size[0]+25
        else:
            if extension in ['mp3','m4a','ogg','flac','wav']:
                os.system(FFpath+' -i '+fullpath+'/'+localname+' '+fullpath+'/e'+localname+'.jpg')
                if os.path.exists(fullpath+'/e'+localname+'.jpg'):
                    os.rename(fullpath+'/'+localname, fullpath+'/e'+localname)
                    localname = 'e' + localname
                    image = Image.open(fullpath+'/'+localname+'.jpg')
                    isize = ', '+str(image.size[0])+'x'+str(image.size[1])
                    image.thumbnail((dim, dim),Image.ANTIALIAS)
                    image.save(fullpath+'/t'+localname+'.jpg', 'JPEG', quality=75)
                    width = image.size[0]+25
                else:
                    copyfile(BasePath+'dat/audio.jpg', fullpath+'/t'+localname+'.jpg')
                    width = 153
            elif extension == 'swf':
                copyfile(BasePath+'dat/flash.png', fullpath+'/t'+localname+'.jpg')
                width = 153
            else:
                copyfile(BasePath+'dat/genericThumb.jpg', fullpath+'/t'+localname+'.jpg')
                width = 153
        fsize = convertSize(os.path.getsize(fullpath+'/'+localname)) + isize

        if loop==1:
            filestring = filename
            localstring = localname
            sizestring = fsize
        else:
            filestring += '/'+filename
            localstring += '/'+localname
            sizestring += '/'+fsize
            width = 25
        try:
            fileitem = post['file'+str(loop+1)]
            #filename = fileitem.filename
            filename = escape(fileitem.filename)
            filename.replace('/','')
            if filename == '':
                break
            extension = filename.split('.')
            filename = '.'.join(extension[:-1])
            if len(filename)>33:
                filename = filename[:33]+'..'
            extension = extension[-1].lower()
            filename = filename+'.'+extension
            spoiler = [escape(spoiler) for spoiler in post.getlist('spoiler'+str(loop+1))]
            if 'y' in spoiler:
                spoiler = 1
            else:
                spoiler = 0
        except(KeyError):
            break

    return [filestring, localstring, sizestring, width]

def new_post_or_thread(environ, path, mode, board, last50, ip, admin, modParams):
    Cur.execute('SELECT t FROM '+('atcd' if mode<0 else 'acdt')+' where i=%s;', (ip,))
    timestamp2 = Cur.fetchone()
    if timestamp2 is not None:
        timestamp2 = int(timestamp2[0])+(TimeoutThread if mode<0 else TimeoutPost)
        curtime = int(time())
        if timestamp2 < curtime:
            Cur.execute('UPDATE '+('atcd' if mode<0 else 'acdt')+' SET t=%s WHERE i=%s;', (str(curtime), ip))
        else:
            return 'You must wait '+str(timestamp2-curtime)+' more seconds before '+('starting a new thread.' if mode<0 else 'posting.')
    else:
        Cur.execute('INSERT INTO '+('atcd' if mode<0 else 'acdt')+' VALUES (%s, %s);', (ip, str(int(time()))))

    timestamp = str(int(time()))
    post = FieldStorage(fp=environ['wsgi.input'],environ=environ,keep_blank_values=True)
    password = escape(post.getfirst('pass'))

    if board in BoardInfo:
        username = BoardInfo[board][2]
    else:
        username = UnlistedUsername

    try:
        value = escape(post.getfirst('submit'))
    except(AttributeError):
        modAction(password, admin, ip, *modParams)
        value=''

    if board in ['all','res','mod','watcher','settings','']:
        return ''

    try:
        Cur.execute('SELECT b FROM aban WHERE a=%s;', (ip,))
        ban = Cur.fetchone()
    except(psycopg2.ProgrammingError):
        ban = 0
        Cur.execute("ROLLBACK")
    if not ban:
        ban = 0
    else:
        ban = ban[0]
        if ban == 2:
            response_body = '<html><body><h1>Your IP has a been banned.</h1></body></html>'
            return response_body

    if value == 'Submit':
        title = escape(post.getfirst('title'))
        if len(title)>150:
            title=title[:150]+'...'
        name = escape(post.getfirst('name'))
        if len(name)>50:
            name=name[:50]+'...'
        options = escape(post.getfirst('email'))
        #comment = '<br>'.join(escape(post.getfirst('comment')).split('\n'))
        #comment = escape(post.getfirst('comment')).replace('\n','<br>')
        comment = escape(post.getfirst('comment'))
        if len(comment)>8000:
            response_body = 'Post body was too long.'
            return response_body
        comment = comment.split('\r\n')
        if len(comment)>200:
            response_body = 'Post body has too many lines.'
            return response_body
        if mode < 0: # on main page get thread number for OP post linking
            Cur.execute('SELECT EXISTS(SELECT * FROM information_schema.tables WHERE table_name=%s);', ('b'+board,))
            if Cur.fetchone()[0]: #board exists
                Cur.execute('SELECT num FROM adat WHERE b=%s;', (board,))
                threadnum = int(Cur.fetchone()[0])
            else:
                threadnum = 1
        else: #inside thread threadnum is just mode
            threadnum = mode
        comment,quit = processComment('<br>'.join(comment), board, threadnum, last50, 0)
        if quit:
            return 'post dropped'
        images = [escape(images) for images in post.getlist('images')]
        spoiler = [escape(spoiler) for spoiler in post.getlist('spoiler')]
        if 'y' in spoiler:
            spoiler = 1
        else:
            spoiler = 0

        bump,email = setOptions(options)
        if name == '':
            name = username
        if admin and name == admin: name = '<span style="color:#AA0;text-shadow:1px 1px #000;">'+admin+'</span>'
        if email: name = '<a href="mailto:'+email+'">'+name+'</a>'
        comment = comment.replace('\r','')

        if 'y' in images or board == 'f':
            fileitem = post['file']
            filename = escape(fileitem.filename)
            filename.replace('/','')
            if filename!='':
                extension = filename.split('.')
                if len(extension) == 1:
                    filename = extension[0]
                    extension = ''
                else:
                    filename = '.'.join(extension[:-1])
                    if len(filename)>33:
                        filename = filename[:33]+'..'
                    extension = extension[-1].lower()
                    filename = filename+'.'+extension
            else:
                extension=''
        else:
            filename = ''
            extension = ''

        if board == 'f' and filename != '' and extension != 'swf':
            return 'Only flash files allowed on /f/'

        if filename != '' and comment == '':
            comment = '<br>ｷﾀ━━━(ﾟ∀ﾟ)━━━!!'

        if mode < 0 and (comment != '' or filename != ''): # new thread
#                Cur.execute('SELECT EXISTS(SELECT * FROM information_schema.tables WHERE table_name=%s);', ('b'+board,))
#                threadnum = 0
#                if Cur.fetchone()[0]: #board exists
            if threadnum>1: # board exists
                if board not in BoardInfo: # bump unofficial boards
                    Cur.execute('UPDATE un SET t=%s WHERE b=%s;', (timestamp, board))
#                    Cur.execute('SELECT num FROM adat WHERE b=%s;', (board,))
#                    threadnum = int(Cur.fetchone()[0])
            else: # create board
                if board not in BoardInfo: # add to unofficial list if unofficial
                    Cur.execute('INSERT INTO un VALUES (%s, %s);', (board, timestamp))
                Cur.execute('CREATE TABLE "b'+board+'" (num integer, t integer, cnt integer, b text, ct integer, dt integer);')
                Cur.execute('INSERT INTO adat VALUES (%s, 1);', (board,))
#                    threadnum = 1

            if filename:
                filestring, localstring, sizestring, width = getFileUpload(fileitem, post, filename, extension, board, threadnum, spoiler, 1, 256)
            else:
                filestring = localstring = sizestring = ''
                width = 25

            Cur.execute('UPDATE adat SET num=num+1 WHERE b=%s;', (board,))
            Cur.execute('INSERT INTO "b'+board+'" VALUES (%s, %s, 0, %s, %s, 0);', (str(threadnum), timestamp, board, timestamp))
            Cur.execute('INSERT INTO ball VALUES (%s, %s, 0, %s, %s, 0);', (str(threadnum), timestamp, board, timestamp))

            Cur.execute('CREATE TABLE "t'+board+'/'+str(threadnum)+'" (h text, i text, p text, f text, n text, a text, c serial, m text, x integer, s text, w integer); ALTER SEQUENCE "t'+board+'/'+str(threadnum)+'_c_seq" MINVALUE 0; ALTER SEQUENCE "t'+board+'/'+str(threadnum)+'_c_seq" RESTART WITH 0;')
            Cur.execute('INSERT INTO "t'+board+'/'+str(threadnum)+'" VALUES (%s, %s, %s, %s, %s, %s, DEFAULT, \'2\', 0, %s, 0), (%s, %s, %s, %s, %s, %s, DEFAULT, \'1\', 0, %s, %s);', (title, '', ('1' if 'y' in images else '0'), '', '', '', '', strftime('(%a)%b %d %Y %X',gmtime()), localstring, comment, filestring, name, ip, sizestring, str(width)))
            DBconnection.commit()
            #response_body = '<html><head><script>function redirect(){window.location.replace("'+(path if noko else '/'.join(path.split('/')[:2]))+'/'+str(threadnum)+'");}</script></head><body onload="redirect()"><h1>Thread submitted successfully...</h1></body></html>'
            response_body = '<!DOCTYPE HTML><html><head><meta charset="utf-8"><script>function redirect(){window.location.replace("'+path+'/'+str(threadnum)+'/l50");}</script></head><body onload="redirect()"><h1>Thread submitted successfully...</h1></body></html>'
            return response_body
        elif comment != '' or filename != '': #just a post
            if board not in BoardInfo: # bump unofficial boards
                Cur.execute('UPDATE un SET t=%s WHERE b=%s;',(timestamp, board))
            try:
                Cur.execute('SELECT p FROM "t'+board+'/'+str(mode)+'" WHERE c=0;') #i and p for the 1st row is tags and imageAllow
                data = Cur.fetchone()[0]

                if int(data)==1 and filename:
                    filestring, localstring, sizestring, width = getFileUpload(fileitem, post, filename, extension, board, threadnum, spoiler, 0, 150)
                else:
                    filestring = localstring = sizestring = ''
                    width = 25

                Cur.execute('SELECT m FROM "t'+board+'/'+str(mode)+'" WHERE c=0;')
                dnum = Cur.fetchone()[0]
                Cur.execute('INSERT INTO "t'+board+'/'+str(mode)+'" VALUES (%s, %s, %s, %s, %s, %s, DEFAULT, %s, %s, %s, %s);', (strftime('(%a)%b %d %Y %X',gmtime()), localstring, comment, filestring, name, ip, dnum, ban, sizestring, str(width)))
                Cur.execute('UPDATE "t'+board+'/'+str(mode)+'" SET m=%s WHERE c=0;', (str(int(dnum)+1),))

                Cur.execute('SELECT c FROM "t'+board+'/'+str(mode)+'" WHERE c=(SELECT max(c) FROM "t'+board+'/'+str(mode)+'");')
                postnum = Cur.fetchone()[0]
                Cur.execute('UPDATE "b'+board+'" SET '+('t='+timestamp+',' if bump else '')+'cnt=cnt+1 WHERE num=%s;', (str(mode),))
                Cur.execute('UPDATE ball SET '+('t='+timestamp+',' if bump else '')+'cnt=cnt+1 WHERE num=%s AND b=%s;', (str(mode), board))
                DBconnection.commit()
            except(psycopg2.ProgrammingError):
                response_body = '<h2>Error creating post.</h2>'
                Cur.execute("ROLLBACK")
                return response_body
            #response_body = '<html><head><script>function redirect(){window.location.replace("'+(path if noko else '/'.join(path.split('/')[:2]))+'");}</script></head><body onload="redirect()"><h1>Post submitted successfully...</h1></body></html>'
            response_body = '<!DOCTYPE HTML><html><head><meta charset="utf-8"><script>window.location.replace("'+path+'");</script></head><body><h1>Post submitted successfully...</h1></body></html>'
            return response_body
        else:
            response_body = '<h2><h2>Please provide a comment or file.</h2>'
            return response_body

    return ''

def fill_header(header, mode, board, userquery, mixed, tboard, imageAllow, cookieStyle):
    if BannerRandom:
        BannerCurrent = Banners[randint(0, len(Banners))]
    else:
        BannerCurrent = Banners[int(int(time()) / (BannerRotationTime*60)) % len(Banners)]
    boardStyle = getStyle(board)

    if board in BoardInfo:
        boardTitle = BoardInfo[board][0]
        boardMessage = BoardGreetings[board] if board in BoardGreetings else ''
    else:
        boardTitle = UnlistedTitle
        boardMessage = UnlistedMessage

    if cookieStyle == 'tomorrow':
        styles = '<link rel="stylesheet" type="text/css" title="tomorrow" href="/res/dat/styletomorrow.css">'
    else:
        styles = '<link rel="stylesheet" type="text/css" title="default" href="/res/dat/style'+boardStyle+'.css"><link rel="stylesheet" type="text/css" title="default" href="/res/dat/styleThreads.css">'

    if mode < 0:
        header = header % (styles+('<style>.postForm{display:none;}</style>' if board=='all' else '')+('<style>.pon{display:none;}</style>' if board!='all' and not mixed else ''), '', ' bg', BannerCurrent, '/'+userquery+'/ - '+('Mixed Board<br>/'+board+'/ main' if mixed else boardTitle), boardMessage)
    else:
        header = header % (styles+'<style>.hbox{display:none;}'+('.fbox{display:none;}' if imageAllow==0 else '')+'.tb{background:transparent !important;}</style>', 'style="height:100%;margin:0px;padding:0px;border:none;box-shadow:none" class="style'+boardStyle+'" ', '')
    return header

def load_page(mode, board, mixed, catalog, realquery, userquery, last50, ip, admin, cookieStyle):
    fswitch = 1
    error = 0

    if board in BoardInfo:
        displayMode = BoardInfo[board][4]
        maxThreads = BoardInfo[board][3]
    else:
        displayMode = UnlistedDisplayMode
        maxThreads = UnlistedMaxThreads
    
    if mode < 0:
        response_body_header = PageHeader + FtEN
        response_body_header = fill_header(response_body_header, mode, board, userquery, mixed, '', 0, cookieStyle)
        try:
            if catalog == 0:
                Cur.execute('('+realquery+') ORDER BY t DESC OFFSET %s LIMIT 15;', (str(-15*(mode+1)),))
                threads = Cur.fetchall()
            else:
                #CATALOG VIEW
                Cur.execute('('+realquery+') ORDER BY t DESC LIMIT %s;', (maxThreads,))
                threads = Cur.fetchall()
        except(psycopg2.ProgrammingError):
            error = 1
            Cur.execute("ROLLBACK")
    else:
        #VIEWING A THREAD
        Cur.execute('SELECT * FROM "b'+board+'" WHERE num=%s;', (str(mode),))
        threads = Cur.fetchall()
        if len(threads)==0:
            return 'Thread not found.'
        #threads = [(mode,'',0,board)]

    # TABLE FOOTER WITH DYANMIC CATALOG AND PAGE LINKS
    tableFoot = ('<hr>' if mode<0 else '')+'<a href="/res/dat/report">Report a post</a>'
    if displayMode != 'flash':
        tableFoot = '<br>[<a href="/'+userquery+'/c">Catalog</a>] Page: '
        for i in range(1,int(maxThreads/15)+1):
            tableFoot += '[<a href="/'+userquery+'/p'+str(i)+'">'+str(i)+'</a>]'

    response_body = ('<input style="float:right" id="tools" type="submit" value="Thread Tools"><br><br>' if mode>-1 else '')

    if catalog:
        response_body += 'Search OP text: <input type="text" id="srchbr" cols="60"><input type="submit" value="Search"><hr>'

    if error:
        if not mixed:
            response_body += '<h1>HAS NO THREADS YET.</h1>'
        else:
            response_body += '<h1>ONE OF THE BOARDS: '+userquery+'<br> IS EMPTY. PLEASE REPEAT YOUR SEARCH WITHOUT IT.</h1>'
    else:
        if displayMode == 'flash' and mode<0:
            response_body += '<center><table><tr style="height:25px;text-align:center"><td class="label">No.</td><td class="label">File</td><td class="label">Title</td><td class="label">Replies</td><td class="label">Name</td><td class="label">Date</td><td class="label">View</td></tr>'
        for idc, thread in enumerate(threads):
            #tboard = thread[3] if board!='del' else 'del'
            tboard = thread[3]
            try:
                if mode < 0:
                    Cur.execute('SELECT * FROM "t'+tboard+'/'+str(thread[0])+'" ORDER BY c ASC LIMIT 2;')
                    posts = Cur.fetchall()
                    if catalog == 0:
                        Cur.execute('SELECT * FROM "t'+tboard+'/'+str(thread[0])+'" ORDER BY c ASC '+('LIMIT 5 OFFSET '+str(thread[2]-3) if thread[2]>5 else 'OFFSET 2')+';')
                        for i in Cur.fetchall():
                            posts.append(i)
                else:
                    Cur.execute('SELECT * FROM "t'+tboard+'/'+str(thread[0])+'" ORDER BY c ASC;')
                    posts = Cur.fetchall()
            except(psycopg2.ProgrammingError):
                response_body += '<h1>PAGE LOADING ERROR</h1>'
                Cur.execute("ROLLBACK")
                break

            for idx, post in enumerate(posts):
                if idx == 0:
                    #FIRST post in a thread just holds data
                    #post[0] is title
                    #post[1] is tags
                    #post[2] is IMAGESALLOWED
                    title = post[0]
                    #tags = post[1]
                    imageAllow = int(post[2])
#                    mainTag = tags.split(' ')[0]

                    #only for thread views. For main page it is above
                    if mode > -1:
                        response_body_header = fill_header(PageHeader, mode, board, '', 0, tboard, imageAllow, cookieStyle)
                    continue

                elif last50 and idx != 1 and idx < len(posts)-50: #SKIP POSTS IF LAST50
                    continue

                if idx == 1:
                    divclass = 'thread'
                    OP = True
                else:
                    divclass = 'post'
                    OP = False

                if catalog == 0:
                #NORMAL VIEW + THREAD VIEW
                    postnum = idx
                    #if thread[2]-5 > 0 and idx>1:
                        #postnum += thread[2]-5
                    postnum = post[7]

                    if post[8] == 1:
                        ban = 1
                    else:
                        ban = 0


                    if board == 'f' and mode<0:
                        if idx == 1:
                            fcolor = 'style="background:#FED6AF"' if fswitch else 'style="background:#FFE"'
                            response_body += '<tr class="style'+getStyle(tboard)+'"><td '+fcolor+' id="OP'+tboard+'/'+str(thread[0])+'"><span style="color:#C00;font-weight:bold">'+str(thread[0])+'</span></td><td '+fcolor+'><center>'
                            imglst = post[3].split('/')
                            if imglst[0] != '':
                                lcllst = post[1].split('/')
                                fsize = post[9].split('/')
                                for idi in range(len(imglst)):
                                    response_body += '<a style="font-weight:bold" href="/res/dat/brd/'+tboard+'/'+str(thread[0])+'/'+lcllst[idi]+'">'+imglst[idi][:-4]+'</a> ['+fsize[idi]+']'
                            response_body += '</center></td><td '+fcolor+'><a style="color:#C00;font-weight:bold" href="/'+tboard+'/'+str(thread[0])+'/l50">'+title+'</a></td><td '+fcolor+'>'+str(thread[2])+' Replies</td><td '+fcolor+'><span class="name">'+post[4]+'</span></td><td '+fcolor+'>'+post[0]+'</td><td '+fcolor+'><span class="pon">Posted on: <a class="tag" href="/'+thread[3]+'">/'+thread[3]+'/</a></span>&nbsp;<a href="/'+tboard+'/'+str(thread[0])+'">View</a></td></td>'
                            if fswitch:
                                fswitch = 0
                            else:
                                fswitch = 1

                    else:
                        response_body += ('<div'+(' class="style'+getStyle(tboard)+'"' if mode<0 else '')+'>' if idx==1 else '')+'<div id="'+postnum+'" id2="'+str(post[6])+'" class="'+divclass+(' hidden' if ban else '')+'" b="'+tboard+'" t="'+str(thread[0])+'">'+('<a id="h'+tboard+'/'+str(thread[0])+'/'+postnum+'" href="javascript:void(0)" onclick="unhide(this)">[ + ] </a>' if ban else '')+('<div id="OP'+tboard+'/'+str(thread[0])+'">' if idx==1 else '')+(('<div class="tb"><a class="title" href="/'+tboard+'/'+str(thread[0])+'/l50">['+str(thread[0])+']. '+title+'</a><span class="pon">Posted on: <a class="tag" href="/'+thread[3]+'">/'+thread[3]+'/</a></span>'+('<span style="float:right">Text Only | </span>' if not imageAllow else '')+'&nbsp;<span class="title" style="font-size:initial;"><a href="/'+tboard+'/'+str(thread[0])+'">View</a>|<a onclick="watchThread(\''+tboard+'/'+str(thread[0])+'\','+str(thread[2])+');" href="javascript:void(0)">Watch</a></span></div>') if idx==1 else '')+'<a style="color:inherit;text-decoration:none;" onclick="plink(\''+postnum+'\')" href="'+('/'+tboard+'/'+str(thread[0])+'#'+postnum if mode<0 else 'javascript:void(0)')+'">'+postnum+'</a>. <span class="name">'+post[4]+'</span> '+post[0]+(' <a href="javascript:void(0)" onclick="mod(\'udel\','+str(post[6])+')">Del</a>' if mode>-1 and ip==post[5] else '')+'<br><div class="fname">'

                        imglst = post[3].split('/')
                        if imglst[0] != '':
                            lcllst = post[1].split('/')
                            fsize = post[9].split('/')
                            for idi in range(len(imglst)):
                                response_body += '<a href="/res/dat/brd/'+tboard+'/'+str(thread[0])+'/'+lcllst[idi]+'">'+imglst[idi]+'</a> ['+fsize[idi]+']<br>'
                        response_body += '</div>'
                        if admin:
                            if idx == 1:
                                response_body += '<a href="javascript:void(0)" onclick="mod(\'warn\','+str(post[6])+')">Warn</a> | <a href="javascript:void(0)" onclick="mod(\'delt\','+str(post[6])+')">Delete Thread</a> | <a href="javascript:void(0)" onclick="mod(\'ban\','+str(post[6])+')">Ban</a>'
                            else:
                                response_body += '<a href="javascript:void(0)" onclick="mod(\'warn\','+str(post[6])+')">Warn</a> | <a href="javascript:void(0)" onclick="mod(\'del\','+str(post[6])+')">Del</a> | <a href="javascript:void(0)" onclick="mod(\'ban\','+str(post[6])+')">Ban</a>'

                        if not OP:
                            response_body += '<table><tr style="vertical-align:top">'
                        if post[1] != '':
                            imglst = post[1].split('/')
                            response_body += ('<div'+(' style="display:table"' if len(imglst)>1 else '')+'>') if OP else ''
                            for imge in imglst:
                                response_body += ('<td>' if not OP else '')+'<a '+('onclick="return false;" target="_blank" ' if imge[-3:]!='swf' else '')+'href="/res/dat/brd/'+tboard+'/'+str(thread[0])+'/'+imge+'"><img src="/res/dat/brd/'+tboard+'/'+str(thread[0])+'/t'+imge+'.jpg"></a>'+('</td>' if not OP else '')
                            response_body += '</div>' if OP else ''
                        comment = post[2].split('<br>')
                        if mode<0 and len(comment)>20:
                            comment = '<br>'.join(comment[:20])+'<span class="long"><br>...<br>Comment too long. View thread to see entire comment.</span>'
                        else:
                            comment = '<br>'.join(comment)
                        response_body += ('<td style="padding-top:10px'+('; padding-left:25px' if post[1]=='' else '')+'">' if not OP else '')+('<blockquote style="margin-left:'+str(post[10])+'px">' if OP else '')+comment+('</td>' if not OP else '</blockquote>')
                        if idx > 1:
                            response_body += '</tr></table></div>'
                        else:
                            if mode<0 and thread[2]-5 > 0:
                                response_body += '<span class="foot">'+str(thread[2]-5)+' posts omitted</span>'
                            elif last50 and len(posts)-52 > 0:
                                response_body += '<span class="foot">'+str(len(posts)-52)+' posts omitted</span>'
                            response_body += '</div>'

                else: #CATALOG VIEW
                    response_body += ('<div class="catalog">' if idc==0 else '')+'<div class="style'+getStyle(tboard)+'"><div class="'+divclass+'"><div class="tb" style="margin:0px;padding:0px;"><a class="title" href="/'+tboard+'/'+str(thread[0])+'">'+str(thread[0])+'. '+title+'</a> <span class="tag"><a style="font-size:12px;" href="/'+tboard+'">/'+tboard+'/</a></span></div>'
                    if post[1] != '':
                        imge = post[1].split('/')[0]
                        response_body += '<a href="/'+tboard+'/'+str(thread[0])+'"><img class="cimg" src="/res/dat/brd/'+tboard+'/'+str(thread[0])+'/t'+imge+'.jpg"></a>'
                    response_body += '<span class="foot">'+str(thread[2])+' replies</span><br>'+post[2]+'</div>'

            if catalog == 0:
                response_body += '<div style="clear:both;"></div></div></div>'
            else:
                response_body += '</div>'

            if mode >= 0:
#                response_body += '<div class="autotext">Auto-updating thread in [<span id="countDown"></span>] seconds</div>'
                response_body += '<input id="tools" type="submit" value="Get new posts" onclick="autoUpdate()">'

        if board == 'f' and mode<0:
            response_body += '</table></center>'
        
    response_body += ('</div>' if catalog==1 else '') + (FbEN if mode>-1 else '') + tableFoot + '<br><div style="padding:0px 0px 0px 5px;display:table;background:transparent;border:1px inset #888"><a href="/res/dat/contactEN">Contact</a> ･ <img style="float:none;display:inline-block;vertical-align:middle" src="/res/dat/gentoo-badge3.png" id="badge"></div></div></td></tr></table></body></html>'

    return response_body_header + tableFoot + response_body
