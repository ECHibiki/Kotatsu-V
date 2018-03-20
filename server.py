#!/usr/bin/env python3

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

#from settings.default_settings import *
#from settings.local_settings import *
from default_settings import *
from local_settings import *

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
        response_body, new_session = new_post_or_thread(environ, path, mode, board, last50, ip, admin, modParams)
        if response_body:
            return send_and_finish(response_body, start_response, new_session)

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

def send_and_finish(response, start_response, set_cookies=[]): # Calling this function sends the final message to the user
    status = '200 OK'
    response = response.encode()

    response_headers = [('Content-type','text/html'), ('Content-Length', str(len(response)))]
    for cookie in set_cookies:
        response_headers.append(cookie)

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
                userquery = 'listed'
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
    if board == 'all':
        userquery = 'listed+unlisted'+userquery[3:]
        mixed = False
    if len(board) > 10:
        board = board[:10]
#    realquery = 'SELECT * FROM t'+' EXCEPT SELECT * FROM t'.join((' INTERSECT SELECT * FROM t'.join((' UNION SELECT * FROM t'.join(userquery.split('+'))).split('/'))).split('-'))
    #realquery = 'SELECT * FROM "b'+'" UNION SELECT * FROM "b'.join(userquery.split('+'))+'"'
    if e>-1:
        ct = '" WHERE creation_time>'+epochquery
    else:
        ct = '"'
    realquery = 'SELECT * FROM board."'+(ct+' EXCEPT SELECT * FROM board."').join((ct+' UNION SELECT * FROM board."').join(userquery.split('+')).split('-')) + ct

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
    target = 0

    options = options.split(' ')
    for i in options:
        if i.lower() in ['sage','さげ','下げ']: # Different ways a post can be saged
            bump = 0
            if not Allow_Email:
                email = i # Even with email disabled the options used will still show as "mailto"
        try:
            target = int(i)
            if target<2:
                target = 0
        except(ValueError):
            pass
    return bump,email,target

def getStyle(b): # Return the board style
    if b in BoardInfo:
        style = BoardInfo[b][1]
    else:
        style = UnlistedCSS
    return style

def getBan(ip):
    try:
        Cur.execute('SELECT ban_type FROM main.ban WHERE ip=%s;', (ip,))
        ban = Cur.fetchone()[0]
    except(TypeError):
        ban = ''
        Cur.execute("ROLLBACK")
    if ban:
        if ban == 'global':
            return '<html><body><h1>Your IP has a been banned.</h1></body></html>'
    return ''

def reportPost(environ, ip): # User is reporting a post (Currently this is very unelegant, it just adds the reports to a text file on the server. In the future there will be a way for mods to view the reports without having to SSH into the server first)
    timestamp = str(int(time()))
    post = FieldStorage(fp=environ['wsgi.input'],environ=environ,keep_blank_values=True)

    ban = getBan(ip)
    if ban:
        return ban

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

    if b in BoardInfo: # listed board
        listed = True
    else:
        listed = False
    if admin: #real admin
        if a == 'delt': # delete thread
            Cur.execute('DELETE FROM board."'+b+'" WHERE threadnum=%s;', (t,))
            if listed:
                Cur.execute('DELETE FROM board.listed WHERE board=%s AND threadnum=%s;', (b, t))
            else:
                Cur.execute('DELETE FROM board.unlisted WHERE board=%s AND threadnum=%s;', (b, t))
            Cur.execute('DROP TABLE thread."'+b+'/'+t+'";')
            DBconnection.commit()
            Cur.execute('SELECT * FROM board."'+b+'" LIMIT 1;')
            if len(Cur.fetchall()) == 0:
                Cur.execute('DROP TABLE board."'+b+'";')
                #DBconnection.commit()
            if os.path.exists(BasePath+'dat/brd/'+b+'/'+t):
                rmtree(BasePath+'dat/brd/'+b+'/'+t)
            if os.listdir(BasePath+'dat/brd/'+b) == []:
                if os.path.exists(BasePath+'dat/brd/'+b):
                    os.rmdir(BasePath+'dat/brd/'+b)
        elif a == 'warn':
            Cur.execute('UPDATE thread."'+b+'/'+t+'" SET comment = comment || \'<br><br><span class="warn">USER WAS WARNED FOR THIS POST</span>\' WHERE postnum=%s;', (p,))
        elif a == 'del':
            Cur.execute('DELETE FROM thread."'+b+'/'+t+'" WHERE postnum=%s;', (p,))
            Cur.execute('UPDATE board."'+b+'" SET post_count=post_count-1 WHERE threadnum=%s;', (t,))
            if listed:
                Cur.execute('UPDATE board.listed SET post_count=post_count-1 WHERE threadnum=%s AND board=%s;', (t, b))
            else:
                Cur.execute('UPDATE board.unlisted SET post_count=post_count-1 WHERE threadnum=%s AND board=%s;', (t, b))
        elif a == 'ban':
            Cur.execute('SELECT ip FROM thread."'+b+'/'+t+'" WHERE postnum=%s;', (p,))
            ip = Cur.fetchone()[0]
            Cur.execute('INSERT INTO main.ban VALUES (%s, 2);', (ip,))
            Cur.execute('UPDATE thread."'+b+'/'+t+'" SET comment = comment || \'<br><br><span class="band">USER WAS BANNED FOR THIS POST</span>\' WHERE postnum=%s;', (p,))

    elif a == 'udel': # User deleting his own post/thread
        Cur.execute('SELECT a FROM thread."'+b+'/'+t+'" WHERE postnum=%s;', (p,))
        if ip==Cur.fetchone()[0]:
            if p=='1': #delete thread
                Cur.execute('DELETE FROM board."'+b+'" WHERE threadnum=%s;', (t,))
                if listed:
                    Cur.execute('DELETE FROM board.listed WHERE board=%s AND threadnum=%s;', (b, t))
                else:
                    Cur.execute('DELETE FROM board.unlisted WHERE board=%s AND threadnum=%s;', (b, t))
                Cur.execute('DROP TABLE thread."'+b+'/'+t+'";')
                DBconnection.commit()
                Cur.execute('SELECT * FROM board."'+b+'" LIMIT 1;')
                if len(Cur.fetchall()) == 0:
                    Cur.execute('DROP TABLE board."'+b+'";')
                    Cur.execute('DELETE FROM main.dat WHERE board=%s;', (b,))
                    #DBconnection.commit()
                rmtree(BasePath+'dat/brd/'+b+'/'+t)
                if os.listdir(BasePath+'dat/brd/'+b) == []:
                    os.rmdir(BasePath+'dat/brd/'+b)
            else:
                Cur.execute('DELETE FROM thread."'+b+'/'+t+'" WHERE postnum=%s;', (p,))
                Cur.execute('UPDATE board."'+b+'" SET postcount=postcount-1 WHERE threadnum=%s;', (t,))
                if listed:
                    Cur.execute('UPDATE board.listed SET post_count=post_count-1 WHERE threadnum=%s AND board=%s;', (t, b))
                else:
                    Cur.execute('UPDATE board.unlisted SET post_count=post_count-1 WHERE threadnum=%s AND board=%s;', (t, b))

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
            Cur.execute('SELECT board FROM board.unlisted ORDER BY bump_time DESC LIMIT 8;')
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
                        Cur.execute('SELECT name FROM main.mod WHERE cookie=%s;', (data[1],))
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
        Cur.execute('SELECT * FROM thread."'+board+'/'+str(mode)+'" WHERE postnum>=%s ORDER BY postnum ASC;', (str(autoupdateoffset),))
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
            Cur.execute('(%s) ORDER BY bump_time DESC;', (realquery,))
            threads = Cur.fetchall()
            response_body = str(int(time())) + '  ' if len(threads)>0 else ''
            for idc, thread in enumerate(threads):
                tboard = thread[3]
                Cur.execute('SELECT * FROM thread."'+board+'/'+str(thread[0])+'" ORDER BY postnum ASC LIMIT 2;')
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
            Cur.execute('SELECT phash FROM main.mod WHERE name=%s;', (mid,))
            if password == Cur.fetchone()[0]:
                code = str(binascii.b2a_hex(os.urandom(15)))[2:-1]
                Cur.execute('UPDATE main.mod SET cookie=%s WHERE name=%s;', (code, mid))
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
    set_cookie = []
    if board in BoardInfo: # listed board
        listed = True
    else:
        listed = False

    Cur.execute('SELECT time FROM '+('main.thread_cooldown' if mode<0 else 'main.post_cooldown')+' where ip=%s;', (ip,))
    timestamp2 = Cur.fetchone()
    if timestamp2 is not None:
        timestamp2 = int(timestamp2[0])+(TimeoutThread if mode<0 else TimeoutPost)
        curtime = int(time())
        if timestamp2 < curtime:
            Cur.execute('UPDATE '+('main.thread_cooldown' if mode<0 else 'main.post_cooldown')+' SET time=%s WHERE ip=%s;', (str(curtime), ip))
        else:
            return ['You must wait '+str(timestamp2-curtime)+' more seconds before '+('starting a new thread.' if mode<0 else 'posting.'), set_cookie]
    else:
        Cur.execute('INSERT INTO '+('main.thread_cooldown' if mode<0 else 'main.post_cooldown')+' VALUES (%s, %s);', (ip, str(int(time()))))

    session = ''
    try:
        cookie = escape(environ.get('HTTP_COOKIE'))
        cookie = cookie.split('; ')
        for a in cookie:
            data = a.split('=')
            if data[0] == '4taba':
                if len(data[1])==30:
                    try:
                        Cur.execute('SELECT * FROM main.cookie WHERE cookie=%s;', (data[1],))
                        temp = Cur.fetchone()
                        if temp:
                            session = data[0]
                    except(psycopg2.ProgrammingError):
                        session = ''
                        Cur.execute("ROLLBACK")
            elif data[0] == 'style':
                if data[1] == 'tomorrow':
                    cookieStyle = 'tomorrow'
    except(AttributeError):
        session = ''

    if not session:
        session = str(binascii.b2a_hex(os.urandom(15)))[2:-1]
        set_cookie.append( ('Set-Cookie', '4taba='+session) )

    timestamp = str(int(time()))
    post = FieldStorage(fp=environ['wsgi.input'],environ=environ,keep_blank_values=True)
    #password = escape(post.getfirst('pass'))

    if board in BoardInfo:
        username = BoardInfo[board][2]
    else:
        username = UnlistedUsername

    try:
        value = escape(post.getfirst('submit'))
    except(AttributeError):
        pass
    #    modAction(password, admin, ip, *modParams)
    #    value=''

    if board in ['listed','unlisted','all','res','mod','watcher','settings','']:
        return ['', set_cookie]

    ban = getBan(ip)
    if ban:
        return [ban, set_cookie]

    if value == 'Submit':
        try:
            title = escape(post.getfirst('title'))
            if len(title)>150:
                title=title[:150]+'...'
        except:
            title = ''

        try:
            name = escape(post.getfirst('name'))
            if len(name)>50:
                name=name[:50]+'...'
        except:
            name = ''

        try:
            options = escape(post.getfirst('email'))
        except:
            options = ''

        if mode < 0: # on main page get thread number for OP post linking
            try:
                Cur.execute('SELECT last_value FROM board."'+board+'_threadnum_seq";')
                threadnum = int(Cur.fetchone()[0]) + 1
            except(psycopg2.ProgrammingError):
                threadnum = 1
        else: #inside thread threadnum is just mode
            threadnum = mode

        try:
            #comment = '<br>'.join(escape(post.getfirst('comment')).split('\n'))
            #comment = escape(post.getfirst('comment')).replace('\n','<br>')
            comment = escape(post.getfirst('comment'))
            if len(comment)>8000:
                response_body = 'Post body was too long.'
                return [response_body, set_cookie]
            if comment.find('\r\n') != -1:
                comment = comment.split('\r\n')
            elif comment.find('\n') != -1:
                if comment.find('\r') != -1:
                    comment = comment.replace('\r','')
                comment = comment.split('\n')
            else:
                comment = comment.split('\r')
            if len(comment)>200:
                response_body = 'Post body has too many lines.'
                return [response_body, set_cookie]
            comment,quit = processComment('<br>'.join(comment), board, threadnum, last50, 0)
        except:
            comment = ''
            quit = 0

        if quit:
            return ['Post contains illegal content: dropped', set_cookie]

        images = True if 'y' in [escape(images) for images in post.getlist('images')] else False
        spoiler = True if 'y' in [escape(spoiler) for spoiler in post.getlist('spoiler')] else False

        bump,email,target = setOptions(options)
        if name == '':
            name = username
        if admin and name == admin: name = '<span style="color:#AA0;text-shadow:1px 1px #000;">'+admin+'</span>'
        if email: name = '<a href="mailto:'+email+'">'+name+'</a>'

        if images or board == 'f':
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
            return ['Only flash files allowed on /f/', set_cookie]

        if filename != '' and comment == '':
            comment = '<br>ｷﾀ━━━(ﾟ∀ﾟ)━━━!!'

        if mode < 0 and (comment != '' or filename != ''): # new thread
#                Cur.execute('SELECT EXISTS(SELECT * FROM information_schema.tables WHERE table_name=%s);', ('b'+board,))
#                threadnum = 0
#                if Cur.fetchone()[0]: #board exists
            if threadnum == 1: # new board
                Cur.execute('CREATE TABLE board."'+board+'" (threadnum serial, bump_time integer, post_count integer, board text, creation_time integer, deletion_time integer, title text, imageAllow boolean);')
                #Cur.execute('INSERT INTO main.dat VALUES (%s, 1);', (board,))
#                    threadnum = 1

            if filename:
                filestring, localstring, sizestring, width = getFileUpload(fileitem, post, filename, extension, board, threadnum, spoiler, 1, 256)
            else:
                filestring = localstring = sizestring = ''
                width = 25

            #Cur.execute('UPDATE main.dat SET thread_count=thread_count+1 WHERE board=%s;', (board,))
            Cur.execute('INSERT INTO board."'+board+'" VALUES (DEFAULT, %s, 0, %s, %s, 0, %s, %s);', (timestamp, board, timestamp, title, images))
            if listed:
                Cur.execute('INSERT INTO board.listed VALUES (%s, %s, 0, %s, %s, 0, %s, %s);', (threadnum, timestamp, board, timestamp, title, images))
            else:
                Cur.execute('INSERT INTO board.unlisted VALUES (%s, %s, 0, %s, %s, 0, %s, %s);', (threadnum, timestamp, board, timestamp, title, images))

            Cur.execute('CREATE TABLE thread."'+board+'/'+str(threadnum)+'" (time_string text, file_path text, comment text, file_name text, name text, ip text, postnum serial, hidden boolean, image_size text, image_width integer, session text, subs boolean);')
            Cur.execute('INSERT INTO thread."'+board+'/'+str(threadnum)+'" VALUES (%s, %s, %s, %s, %s, %s, DEFAULT, false, %s, %s, %s, false);', (strftime('(%a)%b %d %Y %X',gmtime()), localstring, comment, filestring, name, ip, sizestring, str(width), session))
            DBconnection.commit()
            #response_body = '<html><head><script>function redirect(){window.location.replace("'+(path if noko else '/'.join(path.split('/')[:2]))+'/'+str(threadnum)+'");}</script></head><body onload="redirect()"><h1>Thread submitted successfully...</h1></body></html>'
            return [page_redirect(path+'/'+str(threadnum)+'/l50', 'Thread submitted successfully...'), set_cookie]
        elif comment != '' or filename != '': #just a post
            try:
                Cur.execute('SELECT imageAllow FROM board."'+board+'" WHERE threadnum=%s;', (threadnum,))
                imageAllow = bool(Cur.fetchone()[0])

                if imageAllow and filename:
                    filestring, localstring, sizestring, width = getFileUpload(fileitem, post, filename, extension, board, threadnum, spoiler, 0, 150)
                else:
                    filestring = localstring = sizestring = ''
                    width = 25

                #Cur.execute('SELECT hidden FROM thread."'+board+'/'+str(mode)+'" WHERE postnum=0;')
                #dnum = Cur.fetchone()[0]

                if not target:
                    Cur.execute('INSERT INTO thread."'+board+'/'+str(threadnum)+'" VALUES (%s, %s, %s, %s, %s, %s, DEFAULT, false, %s, %s, %s, false);', (strftime('(%a)%b %d %Y %X',gmtime()), localstring, comment, filestring, name, ip, sizestring, str(width), session))
                    #Cur.execute('UPDATE thread."'+board+'/'+str(mode)+'" SET hidden=%s WHERE postnum=0;', (str(int(dnum)+1),))

                    #Cur.execute('SELECT postnum FROM thread."'+board+'/'+str(mode)+'" WHERE postnum=(SELECT max(postnum) FROM thread."'+board+'/'+str(mode)+'");')
                    #postnum = Cur.fetchone()[0]
                    Cur.execute('UPDATE board."'+board+'" SET '+('bump_time='+timestamp+',' if bump else '')+'post_count=post_count+1 WHERE threadnum=%s;', (str(threadnum),))
                    if listed:
                        Cur.execute('UPDATE board.listed SET '+('bump_time='+timestamp+',' if bump else '')+'post_count=post_count+1 WHERE threadnum=%s AND board=%s;', (str(threadnum), board))
                    else:
                        Cur.execute('UPDATE board.unlisted SET '+('bump_time='+timestamp+',' if bump else '')+'post_count=post_count+1 WHERE threadnum=%s AND board=%s;', (str(threadnum), board))
                    DBconnection.commit()
                else:
                    Cur.execute('SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=\'sub\' AND table_name=\''+board+'/'+str(threadnum)+'/'+str(target)+'\');')
                    if not Cur.fetchone()[0]:
                        Cur.execute('CREATE TABLE sub."'+board+'/'+str(threadnum)+'/'+str(target)+'" (time_string text, comment text, ip text, postnum serial, hidden boolean, session text);')
                        Cur.execute('UPDATE thread."'+board+'/'+str(threadnum)+'" SET subs=true WHERE postnum=%s;', (target,))
                    Cur.execute('INSERT INTO sub."'+board+'/'+str(threadnum)+'/'+str(target)+'" VALUES (%s, %s, %s, DEFAULT, false, %s);', (strftime('(%a)%b %d %Y %X',gmtime()), comment, ip, session))
            except(psycopg2.ProgrammingError):
                Cur.execute("ROLLBACK")
                return [page_error('Error creating post.'), set_cookie]
            #response_body = '<html><head><script>function redirect(){window.location.replace("'+(path if noko else '/'.join(path.split('/')[:2]))+'");}</script></head><body onload="redirect()"><h1>Post submitted successfully...</h1></body></html>'
            return [page_redirect(path, 'Post submitted successfully...'), set_cookie]
        else:
            return [page_error('Please provide a comment or file.'), set_cookie]

    return ['', set_cookie]

def fill_header(header, mode, board, title, userquery, mixed, tboard, imageAllow, cookieStyle):
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
        header = header % ('/'+board+'/', styles+('<style>.postForm{display:none;}</style>' if board in ['listed','unlisted','all'] else '')+('<style>.tag{display:none;}</style>' if board not in ['listed','unlisted','all'] and not mixed else ''), '', ' bg', BannerCurrent, '/'+(userquery+'/ - Mixed Board<br>/'+board+'/ main' if mixed else board+'/ - '+boardTitle), boardMessage)
    else:
        header = header % ('/'+board+'/ '+title, styles+'<style>.hbox{display:none;}'+('.fbox{display:none;}' if imageAllow==0 else '')+'.tb{background:transparent !important;} .thread{border:none;}</style>', 'style="height:100%;margin-left:105px;padding:0px;border:none;box-shadow:none" class="style'+boardStyle+'" ', '')
    return header

def load_page(mode, board, mixed, catalog, realquery, userquery, last50, ip, admin, cookieStyle):
    error = 0

    if board in BoardInfo:
        displayMode = BoardInfo[board][4]
        maxThreads = BoardInfo[board][3]
    else:
        displayMode = UnlistedDisplayMode
        maxThreads = UnlistedMaxThreads
    
    if mode < 0:
        response_body_header = PageHeader + FtEN
        response_body_header = fill_header(response_body_header, mode, board, '', userquery, mixed, '', 0, cookieStyle)
        try:
            if catalog == 0:
                Cur.execute('('+realquery+') ORDER BY bump_time DESC OFFSET %s LIMIT 15;', (str(-15*(mode+1)),))
            else:
                #CATALOG VIEW
                Cur.execute('('+realquery+') ORDER BY bump_time DESC LIMIT %s;', (maxThreads,))
            threads = Cur.fetchall()
        except(psycopg2.ProgrammingError):
            error = 1
            Cur.execute("ROLLBACK")
    else:
        #VIEWING A THREAD
        Cur.execute('SELECT * FROM board."'+board+'" WHERE threadnum=%s;', (str(mode),))
        threads = Cur.fetchall()
        if len(threads)==0:
            return 'Thread not found.'

    # TABLE FOOTER WITH DYANMIC CATALOG AND PAGE LINKS
    tableFoot = ('<hr>' if mode<0 else '')+'<a href="/res/dat/report">Report a post</a>'
    if displayMode != 'flash':
        tableFoot = '<br>[<a href="/'+userquery+'/c">Catalog</a>] Page: '
        for i in range(1,int(maxThreads/15)+1):
            tableFoot += '[<a href="/'+userquery+'/p'+str(i)+'">'+str(i)+'</a>]'

    response_body = ''

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
            posted_on = thread[3]
            title = thread[6]
            imageAllow = int(thread[7])

            try:
                if mode < 0:
                    Cur.execute('SELECT * FROM thread."'+posted_on+'/'+str(thread[0])+'" ORDER BY postnum ASC LIMIT 1;')
                    posts = Cur.fetchall()
                    if catalog == 0:
                        Cur.execute('SELECT * FROM thread."'+posted_on+'/'+str(thread[0])+'" ORDER BY postnum ASC '+('LIMIT 5 OFFSET '+str(thread[2]-4) if thread[2]>5 else 'OFFSET 1')+';')
                        for i in Cur.fetchall():
                            posts.append(i)
                else:
                    Cur.execute('SELECT * FROM thread."'+posted_on+'/'+str(thread[0])+'" ORDER BY postnum ASC;')
                    posts = Cur.fetchall()
            except(psycopg2.ProgrammingError):
                response_body += '<h1>PAGE LOADING ERROR</h1>'
                Cur.execute("ROLLBACK")
                break

            if mode > -1:
                response_body_header = fill_header(PageHeader, mode, board, title, '', 0, posted_on, imageAllow, cookieStyle)
            for idx, post in enumerate(posts):
                if last50 and idx != 0 and idx < len(posts)-50: #SKIP POSTS IF LAST50
                    continue

                if idx == 0:
                    OP = True
                else:
                    OP = False

                if catalog == 0:

                    if post[8] == 1:
                        ban = 1
                    else:
                        ban = 0

                    response_body += buildPost(OP, last50, admin, mode, board, thread, post, ip)

                else: #CATALOG VIEW
                    response_body += ('<div class="catalog">' if idc==0 else '')+'<div class="style'+getStyle(posted_on)+'"><div class="'+divclass+'"><div class="tb" style="margin:0px;padding:0px;"><a class="title" href="/'+posted_on+'/'+str(thread[0])+'">'+str(thread[0])+'. '+title+'</a> <span class="tag"><a style="font-size:12px;" href="/'+posted_on+'">/'+posted_on+'/</a></span></div>'
                    if post[1] != '':
                        imge = post[1].split('/')[0]
                        response_body += '<a href="/'+posted_on+'/'+str(thread[0])+'"><img class="cimg" src="/res/dat/brd/'+posted_on+'/'+str(thread[0])+'/t'+imge+'.jpg"></a>'
                    response_body += '<span class="foot">'+str(thread[2])+' replies</span><br>'+post[2]+'</div>'

            if catalog == 0:
                response_body += '<div style="clear:both;"></div></div></div>'
                #response_body += '<div style="clear:both;"></div></div>'
            else:
                response_body += '</div>'

            if mode >= 0:
#                response_body += '<div class="autotext">Auto-updating thread in [<span id="countDown"></span>] seconds</div>'
                response_body += '<input id="tools" type="submit" value="Get new posts" onclick="autoUpdate()">'

        if board == 'f' and mode<0:
            response_body += '</table></center>'
        
    response_body += ('</div>' if catalog==1 else '') + (FbEN if mode>-1 else '') + tableFoot + '<br><br><a href="javascript:void(0)" onclick="window.scrollTo(0,0);">▲</a> <span id="botnav"></span> <span id="botlinks"></span><script>checkmenu()</script><hr><div style="padding:0px 0px 0px 5px;display:table;background:transparent;border:1px inset #888"><a href="/res/dat/contactEN">Contact</a> ･ <img style="float:none;display:inline-block;vertical-align:middle" src="/res/dat/gentoo-badge3.png" id="badge"></div></div></td></tr></table></body></html>'

    return response_body_header + tableFoot + response_body

def buildPost(OP, last50, admin, mode, board, thread, post, ip, sub=False):
    threadnum, bump_time, post_count, posted_on, creation_time, delection_time, title, imageAllow = thread
    if not sub:
        time_string, file_path, post_comment, file_name, name, post_ip, postnum, hidden, image_size, image_width, session, subs = post
    else:
        time_string, post_comment, post_ip, postnum, hidden, session = post
        file_path = ''
        file_name = ''
        name = ''
        image_size = ''
        image_width = 25
        subs = False
    #hidden = bool(hidden)
    fswitch = 1
    response_body = ''
    if OP:
        divclass = 'thread'
    else:
        if not sub:
            divclass = 'post'
        else:
            divclass = ''

    # Flash frontpage
    if board == 'f' and mode<0:
        if postnum == 1:
            fcolor = 'style="background:#FED6AF"' if fswitch else 'style="background:#FFE"'
            response_body += '<tr class="style'+getStyle(posted_on)+'"><td '+fcolor+' id="OP'+posted_on+'/'+str(threadnum)+'"><span style="color:#C00;font-weight:bold">'+str(threadnum)+'</span></td><td '+fcolor+'><center>'
            imglst = file_name.split('/')
            if imglst[0] != '':
                lcllst = file_path.split('/')
                fsize = image_size.split('/')
                for idi in range(len(imglst)):
                    response_body += '<a style="font-weight:bold" href="/res/dat/brd/'+posted_on+'/'+str(threadnum)+'/'+lcllst[idi]+'">'+imglst[idi][:-4]+'</a> ['+fsize[idi]+']'
            response_body += '</center></td><td '+fcolor+'><a style="color:#C00;font-weight:bold" href="/'+posted_on+'/'+str(threadnum)+'/l50">'+title+'</a></td><td '+fcolor+'>'+str(post_count)+' Replies</td><td '+fcolor+'><span class="name">'+name+'</span></td><td '+fcolor+'>'+time_string+'</td><td '+fcolor+'><span class="pon">Posted on: <a class="tag" href="/'+posted_on+'">/'+posted_on+'/</a></span>&nbsp;<a href="/'+posted_on+'/'+str(threadnum)+'">View</a></td></td>'
            if fswitch:
                fswitch = 0
            else:
                fswitch = 1

    else:
        #response_body += ('<div'+(' class="style'+getStyle(posted_on)+'"' if mode<0 else '')+'>' if OP==1 else '')+'<div id="'+str(postnum)+'" id2="'+str(postnum)+'" class="'+divclass+(' hidden' if hidden else '')+'" b="'+posted_on+'" t="'+str(threadnum)+'">'+('<a id="h'+posted_on+'/'+str(threadnum)+'/'+str(postnum)+'" href="javascript:void(0)" onclick="unhide(this)">[ + ] </a>' if hidden else '')+('<div id="OP'+posted_on+'/'+str(threadnum)+'">' if OP==1 else '')+(('<div class="tb"><a class="title" href="/'+posted_on+'/'+str(threadnum)+'/l50">['+str(threadnum)+']. '+title+'</a><span class="pon">Posted on: <a class="tag" href="/'+posted_on+'">/'+posted_on+'/</a></span>'+('<span style="float:right">Text Only | </span>' if not imageAllow else '')+'&nbsp;<span class="title" style="font-size:initial;"><a href="/'+posted_on+'/'+str(threadnum)+'">View</a>|<a onclick="watchThread(\''+posted_on+'/'+str(threadnum)+'\','+str(post_count)+');" href="javascript:void(0)">Watch</a></span></div>') if OP==1 else '')+'<a style="color:inherit;text-decoration:none;" onclick="plink(\''+str(postnum)+'\')" href="'+('/'+posted_on+'/'+str(threadnum)+'#'+str(postnum )if mode<0 else 'javascript:void(0)')+'">'+str(postnum)+'</a>. <span class="name">'+name+'</span> '+time_string+(' <a href="javascript:void(0)" onclick="mod(\'udel\','+str(postnum)+')">Del</a>' if mode>-1 and ip==post_ip else '')+'<br><div class="fname">'
        response_body += '<div id="'+str(postnum)+'" id2="'+str(postnum)+'" class="'+('style'+getStyle(posted_on)+' ' if OP else '')+divclass+(' hidden' if hidden else '')+'" b="'+posted_on+'" t="'+str(threadnum)+'">'+('<div class="threadbody">' if OP else '')+('<a id="h'+posted_on+'/'+str(threadnum)+'/'+str(postnum)+'" href="javascript:void(0)" onclick="unhide(this)">[ + ] </a>' if hidden else '')+('<div id="OP'+posted_on+'/'+str(threadnum)+'">' if OP==1 else '')+(('<div class="tb"><a class="tag" href="/'+posted_on+'">/'+posted_on+'/</a> <a class="title" href="/'+posted_on+'/'+str(threadnum)+'/l50">['+str(threadnum)+']. '+title+'</a>'+('<span style="float:right">Text Only | </span>' if not imageAllow else '')+'</div>') if OP==1 else '')+'<a style="color:inherit;text-decoration:none;" onclick="plink(\''+str(postnum)+'\')" href="'+('/'+posted_on+'/'+str(threadnum)+'#'+str(postnum )if mode<0 else 'javascript:void(0)')+'">'+str(postnum)+'</a>. <span class="name">'+name+'</span> <span class="date">'+time_string+'</span>'+(' <a href="javascript:void(0)" onclick="mod(\'udel\','+str(postnum)+')">Del</a>' if mode>-1 and ip==post_ip else '')+'<br><div class="fname">'

        imglst = file_name.split('/')
        if imglst[0] != '':
            lcllst = file_path.split('/')
            fsize = image_size.split('/')
            for idi in range(len(imglst)):
                response_body += '<a href="/res/dat/brd/'+posted_on+'/'+str(threadnum)+'/'+lcllst[idi]+'">'+imglst[idi]+'</a> ['+fsize[idi]+']<br>'
        response_body += '</div>'
        if admin:
            if OP == 1:
                response_body += '<a href="javascript:void(0)" onclick="mod(\'warn\','+str(postnum)+')">Warn</a> | <a href="javascript:void(0)" onclick="mod(\'delt\','+str(postnum)+')">Delete Thread</a> | <a href="javascript:void(0)" onclick="mod(\'ban\','+str(postnum)+')">Ban</a>'
            else:
                response_body += '<a href="javascript:void(0)" onclick="mod(\'warn\','+str(postnum)+')">Warn</a> | <a href="javascript:void(0)" onclick="mod(\'del\','+str(postnum)+')">Del</a> | <a href="javascript:void(0)" onclick="mod(\'ban\','+str(postnum)+')">Ban</a>'

        if not OP:
            response_body += '<table><tr style="vertical-align:top">'
        if file_path != '':
            imglst = file_path.split('/')
            response_body += ('<div'+(' style="display:table"' if len(imglst)>1 else '')+'>') if OP else ''
            for imge in imglst:
                response_body += ('<td>' if not OP else '')+'<a '+('onclick="return false;" target="_blank" ' if imge[-3:]!='swf' else '')+'href="/res/dat/brd/'+posted_on+'/'+str(threadnum)+'/'+imge+'"><img src="/res/dat/brd/'+posted_on+'/'+str(threadnum)+'/t'+imge+'.jpg" onclick="imgswap(this)"></a>'+('</td>' if not OP else '')
            response_body += '</div>' if OP else ''
        comment = post_comment.split('<br>')
        if mode<0 and len(comment)>20:
            comment = '<br>'.join(comment[:20])+'<span class="long"><br>...<br>Comment too long. View thread to see entire comment.</span>'
        else:
            comment = '<br>'.join(comment)
        response_body += ('<td style="padding-top:10px'+('; padding-left:25px' if file_path=='' else '')+'">' if not OP else '')+('<blockquote style="margin-left:'+str(image_width)+'px">' if OP else '')+comment+('</td>' if not OP else '</blockquote>')

        if not OP:
            response_body += '</tr></table>'
            if not sub and subs:
                Cur.execute('SELECT * FROM sub."'+posted_on+'/'+str(threadnum)+'/'+str(postnum)+'" ORDER BY postnum DESC;')
                response_body += '<div class="sub">'
                subposts = Cur.fetchall()
                for subpost in subposts:
                    response_body +=  buildPost(False, False, '', 0, posted_on, thread, subpost, ip, True)
                response_body += '</div>'
            response_body += '</div>'
        else:
            if mode<0 and post_count-5 > 0:
                response_body += '<span class="foot">'+str(post_count-5)+' posts omitted</span>'
            elif last50 and post_count-52 > 0:
                response_body += '<span class="foot">'+str(post_count-52)+' posts omitted</span>'
            response_body += '</div>'
    return response_body

def page_redirect(dest, msg):
    return '<!DOCTYPE HTML><html><head><meta charset="utf-8"><script>function redirect(){window.location.replace("'+dest+'");}</script></head><body onload="redirect()"><h1>'+msg+'</h1></body></html>'

def page_error(msg):
    return '<!DOCTYPE HTML><html><head><meta charset="utf-8"></head><body><h2>'+msg+'</h2></body></html>'
