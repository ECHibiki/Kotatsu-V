#!/usr/bin/env python3

# 4taba.net server code
# Made for Apache + mod_wsgi with python3 (python2 will give encoding or library errors) with Apache configured to serve this script for all requests made to the server aside from static files located at <server_root>/res
# Before running make sure to complete the following initialization steps first:
#     * Start postgresql, set the database information inside the "dbinit_4taba" script and then run it to initialize the database
#     * create a <server_root>/res/brd directory to hold user uploaded files

BasePath = '/home/wwwrun/4taba/' # Set this to the server root directory

import warnings
import os
import math
import binascii
import psycopg2
import magic
from cgi import parse_qs, escape, FieldStorage
from urllib.parse import unquote_plus, parse_qs
from time import strftime, time, gmtime
from PIL import Image
from shutil import rmtree, copyfile, move
from random import randint

if BasePath[-1] != '/': BasePath += '/'
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

with open(BasePath+'res/headerEN','r') as f:
    PageHeader = f.read()
with open(BasePath+'res/formtopEN','r') as f:
    FtEN = f.read()
with open(BasePath+'res/formbotEN','r') as f:
    FbEN = f.read()

BoardGreetings = {}
for i in os.listdir(BasePath+'/bMessages'):
    with open(os.path.join(BasePath+'/bMessages', i), 'r') as f:
        BoardGreetings[i] = f.read()


#############################################################
### THIS IS THE MAIN FUNCTION CALLED BY THE APACHE SERVER ###
#############################################################
def application(environ, start_response):
    databaseConnection() # Connect to database, or reconnect if timed out
    DBconnection.rollback() # Get rid of any errors from previous runs so the server doesn't hang

    # Get path and user data, send response and quit when appropriate
    response_body, path, admin, cookieStyle, ip = get_path_and_data(environ)
    if response_body:
        return send_and_finish(response_body, start_response)

    if len(path) > 4 and path[:4] == '/bin':
        # Process all content under /bin
        return send_and_finish(processBin(path, ip), start_response)
    else:
        # Parse path and return path information
        userquery, mode, last50, catalog, update, updatetimestamp = processPath(path, ip)

    # Process user query (which board or multi-boards they are requesting to view)
    userquery, board, realquery, mixed = processQuery(userquery)
    if '"' in board or board[0] == '.' or board in BoardBlacklist:
        return send_and_finish(page_error('INVALID BOARD NAME'), start_response)
        
    # Send thread-updates if requested
    if update:
        response_body = send_thread_update(update, updatetimestamp, board, mode)
        return send_and_finish(response_body, start_response)

    # Process new thread or post if given
    if environ.get('REQUEST_METHOD') == 'POST':
        response_body, new_session = new_post_or_thread(environ, path, mode, board, last50, ip, admin)
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
    DBconnection.autocommit = True
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
    #
    # / = HOME
    # /B = page 0 of board B
    # /B/pN = page N of board B
    # /B/c = catalog of board B
    # /B/cN = page N of catalog on board B (only useful on boards such as "all" which technically can show threads beyond the board thread limit)
    # /B/# = thread # of board B
    # /B/update/#!t = update thread # from board B at returning new posts after time t
    if path[-1] == '/': path = path[:-1]
    path = path[1:].split('/')
    while len(path) < 5:
        path.append('') # This eliminates the need to perform redundant list length checks
    userquery = '' # userquery is the actual B value (remember it can be combinations of boards like "a+ma")
    mode = -1 # -1 means viewing the thread listing. 0 and higher means viewing a particular thread.
    last50 = False
    catalog = False
    update = False
    updatetimestamp = 0

    userquery = path[0]
    try:
        if path[1]:
            if path[1][0] in ['p','c']:
                mode = int(path[1][1:])-1
                if mode > -1:
                    mode = (mode + 1) * -1
                if path[1][0] == 'c':
                    catalog = 1
            elif path[1][0] == 'b':
                if len(path[1]) > 1:
                    boardupdate = 2
                else:
                    boardupdate = 1
            elif path[1] == 'update':
                if path[1] == 'a':
                    mode = int(path[2])
                    userquery = path[0]
                    update = 1
                    updatetimestamp = int(path[3])
                if path[1] == 'd':
                    mode = int(path[2])
                    userquery = path[0]
                    update = 2
            elif path[2] == 'l50':
                last50 = 1
                mode = int(path[1])
            else:
                mode = int(path[1])
    except:
        pass

    userquery = ''.join(ch for ch in userquery if ch not in ' \/"')
    return [userquery, mode, last50, catalog, update, updatetimestamp]

def binContent(path):
    pass

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

def processComment(comment, board, thread): # Process the user comment to add things such as "greentext", post links, URL's, etc.
    for filt in Filters:
        if filt[0] == 'cross-thread-link':
            comment = re.sub(filt[1], filt[2] % (board, board), comment)
        elif filt[0] == 'post-link':
            comment = re.sub(filt[1], filt[2] % (board, thread), comment)
        else:
            comment = re.sub(filt[1], filt[2], comment)

    return comment

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

def getStyle(board):
    return BoardInfo[board][1] if board in BoardInfo else BoardInfo['*'][1]

def getBan(ip):
    try:
        Cur.execute('SELECT ban_type FROM main.ban WHERE ip=%s;', (ip,))
        ban = Cur.fetchone()[0]
    except(TypeError):
        ban = ''
        DBconnection.rollback()
    if ban:
        if ban == 'global':
            return '<html><body><h1>Your IP has a been banned.</h1></body></html>'
    return ''

def modAction(admin, ip, action, board, thread, post):
    databaseConnection()

    if admin: #real admin
        if action == 'delt': # delete thread
            deleteThread(board, thread)
        elif a == 'del':
            deletePost(board, thread, post)
    elif a == 'udel': # User deleting his own post/thread
        Cur.execute('SELECT ip FROM thread."'+board+'/'+thread+'" WHERE postnum=%s;', (post,))
        if ip==Cur.fetchone()[0]:
            if post=='1': #delete thread
                deleteThread(board, thread)
            else:
                deletePost(board, thread, post)

def deleteThread(board, thread):
    databaseConnection()
    warnings.resetwarnings()
    warnings.warn('@@@@@@@@@@@@@@@@@@@@@@@@@@ START')

    if board in BoardInfo: # listed board
        listed = True
    else:
        listed = False

    Cur.execute('DELETE FROM board."'+board+'" WHERE threadnum=%s;', (thread,))
    warnings.warn('@@@@@@@@@@@@@@@@@@@@@@@@@@ DELETED')
    if listed:
        Cur.execute('DELETE FROM board.listed WHERE board=%s AND threadnum=%s;', (board, thread))
    else:
        Cur.execute('DELETE FROM board.unlisted WHERE board=%s AND threadnum=%s;', (board, thread))
    #DBconnection.commit()
    warnings.warn('@@@@@@@@@@@@@@@@@@@@@@@@@@ COMMITED')
    warnings.warn('@@@@@@@@@@@@@@@@@@@@@@@@@@ DELETED2 INFO: DROP TABLE thread."'+board+'/'+thread+'";')
    DBconnection.rollback()
    Cur.execute('DROP TABLE thread."'+board+'/'+thread+'";')
    DBconnection.rollback()
    warnings.warn('@@@@@@@@@@@@@@@@@@@@@@@@@@ DELETED3')
    #DBconnection.commit()
    warnings.warn('@@@@@@@@@@@@@@@@@@@@@@@@@@ COMMITED2')
    Cur.execute('SELECT threadnum FROM board."'+board+'" LIMIT 1;')
    if len(Cur.fetchall()) == 0:
        Cur.execute('DROP TABLE board."'+board+'";')
    warnings.warn('@@@@@@@@@@@@@@@@@@@@@@@@@@ IF1')
    if os.path.exists(BasePath+'res/brd/'+board+'/'+thread):
        rmtree(BasePath+'res/brd/'+board+'/'+thread)
    warnings.warn('@@@@@@@@@@@@@@@@@@@@@@@@@@ IF2')
    if os.listdir(BasePath+'res/brd/'+board) == []:
        os.rmdir(BasePath+'res/brd/'+board)
    warnings.warn('@@@@@@@@@@@@@@@@@@@@@@@@@@ IF3')
    #DBconnection.commit()
    warnings.warn('@@@@@@@@@@@@@@@@@@@@@@@@@@ COMMITED3')

def deletePost(board, thread, post):
    databaseConnection()
    if board in BoardInfo: # listed board
        listed = True
    else:
        listed = False

    Cur.execute('DELETE FROM thread."'+board+'/'+thread+'" WHERE postnum=%s;', (post,))
    Cur.execute('UPDATE board."'+board+'" SET post_count=post_count-1 WHERE threadnum=%s;', (thread,))
    if listed:
        Cur.execute('UPDATE board.listed SET post_count=post_count-1 WHERE threadnum=%s AND board=%s;', (thread, board))
    else:
        Cur.execute('UPDATE board.unlisted SET post_count=post_count-1 WHERE threadnum=%s AND board=%s;', (thread, board))
    #DBconnection.commit()
    

def get_path_and_data(environ): # Get the URI path and other headers sent by the user request
    admin = ''
    cookieStyle = 'default'

    try:
        request_body_size = int(environ.get('CONTENT_LENGTH', 0))
    except(ValueError):
        request_body_size = 0

    path = escape(environ.get('PATH_INFO').encode('iso-8859-1').decode('utf-8'))
    if path == '/':
        with open(BasePath+'res/indexEN','r') as f:
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
                        DBconnection.rollback()
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

def send_thread_update(update, updatetimestamp, board, mode):
    if update == 1:
        Cur.execute('SELECT * FROM thread."'+board+'/'+str(mode)+'" WHERE postnum>=%s ORDER BY postnum ASC;', (str(updatetimestamp),))
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
                response_body += '<a href="/res/brd/'+board+'/'+str(mode)+'/'+lcllst[idi]+'">'+imglst[idi]+'</a> ['+fsize[idi]+']<br>'
        response_body += '</div>'
        if post[1] != '':
            imglst = post[1].split('/')
            response_body += '<div'+(' style="display:table"' if len(imglst)>1 else '')+'>'
            for imge in imglst:
                response_body += '<a '+('onclick="return false;" target="_blank" ' if imge[-3:]!='swf' else '')+'href="/res/brd/'+board+'/'+str(mode)+'/'+imge+'"><img src="/res/brd/'+board+'/'+str(mode)+'/t'+imge+'.jpg"></a>'
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
                    response_body += '<a href="/res/brd/'+tboard+'/'+str(thread[0])+'/'+posts[1][1].split('/')[0]+'"><img class="cimg" src="/res/brd/'+tboard+'/'+str(thread[0])+'/t'+posts[1][1].split('/')[0]+'.jpg"></a>'
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
                #DBconnection.commit()
                response_body = code
            else:
                response_body = 'fail'
        except(psycopg2.ProgrammingError):
            response_body = 'fail'
            DBconnection.rollback()
        rtype = 'text/plain'
    else:
        with open(BasePath+'res/login','r') as f:
            response_body = f.read()
            rtype = 'text/html'

    return response_body

def getFileUpload(fileitem, board, threadnum, spoiler, OP, dim):
    loop = 0

    fsize='0 B'
    isize = ''
    width = 25

    localname = str(int(time()*1000))
    fullpath = BasePath+'res/brd/'+board+'/'+str(threadnum)+'/'
    fullname = fullpath + localname
    thumbname = fullpath + 't' + localname
    if not os.path.exists(fullpath):
        os.makedirs(fullpath)
    chunkcount = 1
    with open(fullname,'wb',10000) as f:
        for chunk in fbuffer(fileitem.file):
            if chunkcount >= 1259:
                os.remove(fullname)
                return ['' ,'' ,0, page_error('Error: Filesize too large. Maximum upload size is 12MB.')]
            f.write(chunk)
            chunkcount += 1

    #test = magic.from_file(fullname).decode('utf-8')
    test = magic.from_file(fullname)
    stest = test.split(' ')[0]
    if stest in ['JPEG','PNG','GIF']:
        filetype = stest
    elif 'MPEG' in test:
        filetype = 'MP3'
    elif test == 'WebM':
        filetype = 'WebM'
    elif test == 'Matroska data':
        filetype = 'MKV'
    elif 'MP4' in test:
        filetype = 'MP4'
    elif 'Macromedia Flash' in test:
        filetype = 'SWF'
    elif 'Zip archive' in test:
        filetype = 'HTML5'

    if board == 'f' and filetype != 'SWF':
        return ['', '', 0, page_error('Error: Only flash files allowed on /f/')]

    if spoiler:
        copyfile(BasePath+'res/spoiler.jpg', thumbname)
    elif filetype in ['JPEG','PNG','GIF']:
        image = Image.open(fullname)
        isize = ', '+str(image.size[0])+'x'+str(image.size[1])
        if filetype in ['PNG','GIF']:
            image = image.convert('RGBA')
            imageb = Image.new('RGB', image.size, StyleTransparencies[getStyle(board)][OP])
            imageb.paste(image, image)
            image = imageb
        image.thumbnail((dim, dim),Image.ANTIALIAS)
        image.save(thumbname, 'JPEG', quality=75)
        width = image.size[0]+25
    elif filetype in ['WebM','MP4','MKV']:
        os.system(FFpath+' -i '+fullname+' -vf thumbnail -frames:v 1 -f singlejpeg '+thumbname+' 2>/dev/null')
        image = Image.open(thumbname)
        image.thumbnail((dim, dim),Image.ANTIALIAS)
        image.save(thumbname, 'JPEG', quality=75)
        width = image.size[0]+25
    elif filetype == 'HTML5':
        move(fullname, fullname+'.html5')
        if not os.path.exists(fullname):
            os.makedirs(fullname)
        zip_ref = zipfile.ZipFile(fullname+'.html5', 'r')
        zsize = 0
        zdx = 0
        while True:
            try:
                zsize += zip_ref.infolist()[zdx].file_size
                zdx += 1
            except(IndexError):
                break
        if zsize <= 1228800:
            zip_ref.extractall(fullname)
            zip_ref.close()
            copyfile(BasePath+'res/html5.png', thumbpath)
            width = 153
            with open(fullname+'/index.html','w') as f:
                temp = sandbox % (board+'/'+str(threadnum)+'/'+localname+'.html', board+'/'+str(threadnum)+'/'+localname)
                f.write(temp)
        else:
            os.remove(fullname)
            return ['', '', 0, page_error('Error: File decompresses to larger than the maximum filesize. Please fix your zip file and try again.')]
    elif filetype in ['MP3','M4A','OGG','FLAC','WAV']:
        os.system(FFpath+' -i '+fullname+' -f singlejpeg '+fullpath+'f'+localname+' 2>/dev/null')
        if os.path.exists(fullpath+'f'+localname):
            image = Image.open(fullpath+'f'+localname)
            isize = ', '+str(image.size[0])+'x'+str(image.size[1])
            image.thumbnail((dim, dim),Image.ANTIALIAS)
            image.save(thumbname, 'JPEG', quality=75)
            width = image.size[0]+25
        else:
            copyfile(BasePath+'res/audio.jpg', fullpath+'f'+localname)
            copyfile(BasePath+'res/audio.jpg', thumbname)
            width = 153
    elif filetype == 'SWF':
        copyfile(BasePath+'res/flash.png', thumbname)
        width = 153
    else:
        copyfile(BasePath+'res/genericThumb.jpg', thumbname)
        width = 153
    fsize = filetype + ', '+ convertSize(os.path.getsize(fullname)) + isize

    return [localname, fsize, width, '']


def new_post_or_thread(environ, path, mode, board, last50, ip, admin):
    set_cookie = []

    if board in BoardInfo: # listed board
        listed = True
        lboard = board
    else:
        listed = False
        lboard = '*'

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
                        DBconnection.rollback()
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

    username = BoardInfo[lboard][2]

    if board in ['listed','unlisted','all','res','mod','watcher','settings','']:
        return ['', set_cookie]

    ban = getBan(ip)
    if ban:
        return [ban, set_cookie]

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
        comment = processComment('<br>'.join(comment), board, str(threadnum))
    except:
        comment = ''
        quit = 0

    images = False if 'n' in [escape(images) for images in post.getlist('images')] else True
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
        if len(filename)>33:
            filename = filename[:33]+'..'
    else:
        filename = ''

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
            localname, fsize , width, ferror = getFileUpload(fileitem, board, threadnum, spoiler, 1, 256)
            if ferror:
                return [page_error(ferror), set_cookie]
        else:
            filename = localname = fsize = ''
            width = 25

        #Cur.execute('UPDATE main.dat SET thread_count=thread_count+1 WHERE board=%s;', (board,))
        Cur.execute('INSERT INTO board."'+board+'" VALUES (DEFAULT, %s, 0, %s, %s, 0, %s, %s);', (timestamp, board, timestamp, title, images))
        if listed:
            Cur.execute('INSERT INTO board.listed VALUES (%s, %s, 0, %s, %s, 0, %s, %s);', (threadnum, timestamp, board, timestamp, title, images))
        else:
            Cur.execute('INSERT INTO board.unlisted VALUES (%s, %s, 0, %s, %s, 0, %s, %s);', (threadnum, timestamp, board, timestamp, title, images))

        Cur.execute('CREATE TABLE thread."'+board+'/'+str(threadnum)+'" (time_string text, file_path text, comment text, file_name text, name text, ip text, postnum serial, hidden boolean, image_size text, image_width integer, session text, subs boolean);')
        Cur.execute('INSERT INTO thread."'+board+'/'+str(threadnum)+'" VALUES (%s, %s, %s, %s, %s, %s, DEFAULT, false, %s, %s, %s, false);', (strftime('(%a)%b %d %Y %X',gmtime()), localname, comment, filename, name, ip, fsize, str(width), session))
        #DBconnection.commit()
        #response_body = '<html><head><script>function redirect(){window.location.replace("'+(path if noko else '/'.join(path.split('/')[:2]))+'/'+str(threadnum)+'");}</script></head><body onload="redirect()"><h1>Thread submitted successfully...</h1></body></html>'
        return [page_redirect(path+'/'+str(threadnum), 'Thread submitted successfully...'), set_cookie]
    elif comment != '' or filename != '': #just a post
        try:
            Cur.execute('SELECT imageAllow FROM board."'+board+'" WHERE threadnum=%s;', (threadnum,))
            imageAllow = bool(Cur.fetchone()[0])

            if imageAllow and filename:
                localname, fsize, width, ferror = getFileUpload(fileitem, board, threadnum, spoiler, 0, 150)
                if ferror:
                    return [page_error(ferror), set_cookie]
            else:
                filename = localname = fsize = ''
                width = 25

            #Cur.execute('SELECT hidden FROM thread."'+board+'/'+str(mode)+'" WHERE postnum=0;')
            #dnum = Cur.fetchone()[0]

            if not target:
                Cur.execute('INSERT INTO thread."'+board+'/'+str(threadnum)+'" VALUES (%s, %s, %s, %s, %s, %s, DEFAULT, false, %s, %s, %s, false);', (strftime('(%a)%b %d %Y %X',gmtime()), localname, comment, filename, name, ip, fsize, str(width), session))
                #Cur.execute('UPDATE thread."'+board+'/'+str(mode)+'" SET hidden=%s WHERE postnum=0;', (str(int(dnum)+1),))

                #Cur.execute('SELECT postnum FROM thread."'+board+'/'+str(mode)+'" WHERE postnum=(SELECT max(postnum) FROM thread."'+board+'/'+str(mode)+'");')
                #postnum = Cur.fetchone()[0]
                Cur.execute('UPDATE board."'+board+'" SET '+('bump_time='+timestamp+',' if bump else '')+'post_count=post_count+1 WHERE threadnum=%s;', (str(threadnum),))
                if listed:
                    Cur.execute('UPDATE board.listed SET '+('bump_time='+timestamp+',' if bump else '')+'post_count=post_count+1 WHERE threadnum=%s AND board=%s;', (str(threadnum), board))
                else:
                    Cur.execute('UPDATE board.unlisted SET '+('bump_time='+timestamp+',' if bump else '')+'post_count=post_count+1 WHERE threadnum=%s AND board=%s;', (str(threadnum), board))
                #DBconnection.commit()
            else:
                Cur.execute('SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=\'sub\' AND table_name=\''+board+'/'+str(threadnum)+'/'+str(target)+'\');')
                if not Cur.fetchone()[0]:
                    Cur.execute('CREATE TABLE sub."'+board+'/'+str(threadnum)+'/'+str(target)+'" (time_string text, comment text, ip text, postnum serial, hidden boolean, session text);')
                    Cur.execute('UPDATE thread."'+board+'/'+str(threadnum)+'" SET subs=true WHERE postnum=%s;', (target,))
                Cur.execute('INSERT INTO sub."'+board+'/'+str(threadnum)+'/'+str(target)+'" VALUES (%s, %s, %s, DEFAULT, false, %s);', (strftime('(%a)%b %d %Y %X',gmtime()), comment, ip, session))
        except(psycopg2.ProgrammingError):
            DBconnection.rollback()
            return [page_error('Error creating post.'), set_cookie]
        #response_body = '<html><head><script>function redirect(){window.location.replace("'+(path if noko else '/'.join(path.split('/')[:2]))+'");}</script></head><body onload="redirect()"><h1>Post submitted successfully...</h1></body></html>'
        return [page_redirect(path, 'Post submitted successfully...'), set_cookie]
    else:
        return [page_error('Please provide a comment or file.'), set_cookie]

    #return ['', set_cookie]

def fill_header(header, mode, board, lboard, title, userquery, mixed, tboard, imageAllow, cookieStyle):
    if BannerRandom:
        BannerCurrent = Banners[randint(0, len(Banners))]
    else:
        BannerCurrent = Banners[int(int(time()) / (BannerRotationTime*60)) % len(Banners)]
    boardStyle = BoardInfo[lboard][1]

    boardTitle = BoardInfo[lboard][0]
    boardMessage = BoardGreetings[board if board in BoardGreetings else '*']

    if cookieStyle == 'tomorrow':
        styles = '<link rel="stylesheet" type="text/css" title="tomorrow" href="/res/styles/tomorrow.css">'
    else:
        #styles = '<link rel="stylesheet" type="text/css" title="default" href="/res/styles/'+boardStyle+'.css"><link rel="stylesheet" type="text/css" title="default" href="/res/styles/threads.css">'
        styles = '<link rel="stylesheet" type="text/css" title="default" href="/res/styles/threads.css">'

    if mode < 0:
        header = header % ('/'+board+'/', styles, 'class="'+boardStyle+'"', ' bg', BannerCurrent, '/'+(userquery+'/ - Mixed Board<br>/'+board+'/ main' if mixed else board+'/ - '+boardTitle), boardMessage)
    else:
        header = header % ('/'+board+'/ '+title, styles, 'style="height:100%;margin-left:105px;padding:0px;border:none;box-shadow:none" class="threadcontainer '+boardStyle+'" ', '')
    return header

def prune_threads(board):
    databaseConnection()
    if board not in ['all', 'listed']:
        max_threads = BoardInfo[board][3] if board in BoardInfo else BoardInfo['*'][3]
        Cur.execute('SELECT threadnum,bump_time,board FROM board."'+board+'" ORDER BY bump_time DESC OFFSET '+str(max_threads)+';')
        threads = Cur.fetchall()
        timestamp = int(time())

        PruneTime = 60*1
        counter = 0
        for thread in threads:
        
            counter+=1
            if counter>100:
                return 'count exceeded:<br>'+str(threads)
            if thread[1] + PruneTime < timestamp:
                deleteThread(thread[2], str(thread[0]))

        warnings.warn('==========================')
        return ''

def load_page(mode, board, mixed, catalog, realquery, userquery, last50, ip, admin, cookieStyle):
    error = 0
    result = prune_threads(board)
    if result:
        return page_error(result)

    lboard = board if board in BoardInfo else '*'

    displayMode = BoardInfo[lboard][5]
    maxThreads = BoardInfo[lboard][3]
    
    if mode < 0:
        response_body_header = PageHeader + '<center><div style="margin:0 auto;" class="banner"><img id="banner" style="float:none;padding:0px;margin:5px;border:1px solid #000;" src="/res/banners/%s"></div></center><hr><div class="msg"><div class="msg2"><h1 class="boardTitle">%s</h1>%s</div></div>' + (FtEN if board not in ['listed', 'unlisted', 'all'] else '')
        response_body_header = fill_header(response_body_header, mode, board, lboard, '', userquery, mixed, '', 0, cookieStyle)
        try:
            if catalog == 0:
                Cur.execute('('+realquery+') ORDER BY bump_time DESC OFFSET %s LIMIT 15;', (str(-15*(mode+1)),))
            else:
                #CATALOG VIEW
                Cur.execute('('+realquery+') ORDER BY bump_time DESC LIMIT %s;', (maxThreads,))
            threads = Cur.fetchall()
        except(psycopg2.ProgrammingError):
            error = 1
            DBconnection.rollback()
    else:
        #VIEWING A THREAD
        Cur.execute('SELECT * FROM board."'+board+'" WHERE threadnum=%s;', (str(mode),))
        threads = Cur.fetchall()
        if len(threads)==0:
            return 'Thread not found.'

    # TABLE FOOTER WITH DYANMIC CATALOG AND PAGE LINKS
    tableFoot = ('<hr>' if mode<0 else '')+'<a href="/res/report">Report a post</a>'
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
                        DBconnection.rollback()
                else:
                    Cur.execute('SELECT * FROM thread."'+posted_on+'/'+str(thread[0])+'" ORDER BY postnum ASC;')
                    posts = Cur.fetchall()
            except(psycopg2.ProgrammingError):
                response_body += '<h1>PAGE LOADING ERROR</h1>'
                DBconnection.rollback()
                break

            if mode > -1:
                response_body_header = fill_header(PageHeader, mode, board, lboard, title, '', 0, posted_on, imageAllow, cookieStyle)
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
                        response_body += '<a href="/'+posted_on+'/'+str(thread[0])+'"><img class="cimg" src="/res/brd/'+posted_on+'/'+str(thread[0])+'/t'+imge+'.jpg"></a>'
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
        
    response_body += ('</div>' if catalog==1 else '') + (FbEN if mode>-1 else '') + tableFoot + '<br><br><a href="javascript:void(0)" onclick="window.scrollTo(0,0);">▲</a> <span id="botnav"></span> <span id="botlinks"></span><script>checkmenu()</script><hr><div style="padding:0px 0px 0px 5px;display:table;background:transparent;border:1px inset #888"><a href="/res/contactEN">Contact</a> ･ <img style="float:none;display:inline-block;vertical-align:middle" src="/res/gentoo-badge3.png" id="badge"> ･ <a href="/res/weblabels.html" rel="jslicense">WebLabels for LibreJS</a></div></div></td></tr></table></body></html>'

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
        divclass = 'threadcontainer'
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
                    response_body += '<a style="font-weight:bold" href="/res/brd/'+posted_on+'/'+str(threadnum)+'/'+lcllst[idi]+'">'+imglst[idi][:-4]+'</a> ['+fsize[idi]+']'
            response_body += '</center></td><td '+fcolor+'><a style="color:#C00;font-weight:bold" href="/'+posted_on+'/'+str(threadnum)+'/l50">'+title+'</a></td><td '+fcolor+'>'+str(post_count)+' Replies</td><td '+fcolor+'><span class="name">'+name+'</span></td><td '+fcolor+'>'+time_string+'</td><td '+fcolor+'><span class="pon">Posted on: <a class="tag" href="/'+posted_on+'">/'+posted_on+'/</a></span>&nbsp;<a href="/'+posted_on+'/'+str(threadnum)+'">View</a></td></td>'
            if fswitch:
                fswitch = 0
            else:
                fswitch = 1

    else:
        #response_body += ('<div'+(' class="style'+getStyle(posted_on)+'"' if mode<0 else '')+'>' if OP==1 else '')+'<div id="'+str(postnum)+'" id2="'+str(postnum)+'" class="'+divclass+(' hidden' if hidden else '')+'" b="'+posted_on+'" t="'+str(threadnum)+'">'+('<a id="h'+posted_on+'/'+str(threadnum)+'/'+str(postnum)+'" href="javascript:void(0)" onclick="unhide(this)">[ + ] </a>' if hidden else '')+('<div id="OP'+posted_on+'/'+str(threadnum)+'">' if OP==1 else '')+(('<div class="tb"><a class="title" href="/'+posted_on+'/'+str(threadnum)+'/l50">['+str(threadnum)+']. '+title+'</a><span class="pon">Posted on: <a class="tag" href="/'+posted_on+'">/'+posted_on+'/</a></span>'+('<span style="float:right">Text Only | </span>' if not imageAllow else '')+'&nbsp;<span class="title" style="font-size:initial;"><a href="/'+posted_on+'/'+str(threadnum)+'">View</a>|<a onclick="watchThread(\''+posted_on+'/'+str(threadnum)+'\','+str(post_count)+');" href="javascript:void(0)">Watch</a></span></div>') if OP==1 else '')+'<a style="color:inherit;text-decoration:none;" onclick="plink(\''+str(postnum)+'\')" href="'+('/'+posted_on+'/'+str(threadnum)+'#'+str(postnum )if mode<0 else 'javascript:void(0)')+'">'+str(postnum)+'</a>. <span class="name">'+name+'</span> '+time_string+(' <a href="javascript:void(0)" onclick="mod(\'udel\','+str(postnum)+')">Del</a>' if mode>-1 and ip==post_ip else '')+'<br><div class="fname">'
        response_body += '<div id="'+str(postnum)+'" id2="'+str(postnum)+'" class="'+(getStyle(posted_on)+' ' if mode<0 else '')+divclass+'" b="'+posted_on+'" t="'+str(threadnum)+'">'+('<div class="threadbody">' if OP else '')+('<a id="h'+posted_on+'/'+str(threadnum)+'/'+str(postnum)+'" href="javascript:void(0)" onclick="unhide(this)">[ + ] </a>' if hidden else '')+('<div id="OP'+posted_on+'/'+str(threadnum)+'">' if OP==1 else '')+(('<div class="tb"><a class="title" href="/'+posted_on+'/'+str(threadnum)+'"><span style="font-size:16px;color:#000">【'+str(threadnum)+'】</span> '+title+'</a>&nbsp;<a href="/'+posted_on+'/'+str(threadnum)+'/l50">last50</a>'+(' <a class="tag" href="/'+posted_on+'">/'+posted_on+'/</a>' if mode>-1 or board in ['listed','unlisted','all'] else '')+('<span> | Text Only</span>' if not imageAllow else '')+'</div>') if OP==1 else '')+'<a style="color:inherit;text-decoration:none;" onclick="plink(\''+str(postnum)+'\')" href="'+('/'+posted_on+'/'+str(threadnum)+'#'+str(postnum )if mode<0 else 'javascript:void(0)')+'">'+str(postnum)+'</a>. <span class="name">'+name+'</span> <span class="date">'+time_string+'</span>'+(' <a href="javascript:void(0)" onclick="mod(\'udel\','+str(postnum)+')">Del</a>' if mode>-1 and ip==post_ip else '')+'<br><div class="fname">'

        imglst = file_name.split('/')
        if imglst[0] != '':
            lcllst = file_path.split('/')
            fsize = image_size.split('/')
            for idi in range(len(imglst)):
                response_body += '<a href="/res/brd/'+posted_on+'/'+str(threadnum)+'/'+lcllst[idi]+'">'+imglst[idi]+'</a> ['+fsize[idi]+']<br>'
        response_body += '</div>'
        if admin:
            if OP == 1:
                response_body += '<a href="javascript:void(0)" onclick="mod(\'warn\','+str(postnum)+')">Warn</a> | <a href="javascript:void(0)" onclick="mod(\'delt\','+str(postnum)+')">Delete Thread</a> | <a href="javascript:void(0)" onclick="mod(\'ban\','+str(postnum)+')">Ban</a>'
            else:
                response_body += '<a href="javascript:void(0)" onclick="mod(\'warn\','+str(postnum)+')">Warn</a> | <a href="javascript:void(0)" onclick="mod(\'del\','+str(postnum)+')">Del</a> | <a href="javascript:void(0)" onclick="mod(\'ban\','+str(postnum)+')">Ban</a>'

        if not OP:
            #response_body += '<table><tr style="vertical-align:top">'
            pass
        if file_path != '':
            imglst = file_path.split('/')
            response_body += ('<div'+(' style="display:table"' if len(imglst)>1 else '')+'>') if OP else ''
            for imge in imglst:
                response_body += '<a '+('onclick="return false;" target="_blank" ' if imge[-3:]!='swf' else '')+'href="/res/brd/'+posted_on+'/'+str(threadnum)+'/'+imge+'"><img data-ftype="'+fsize[0].split(',')[0]+'" src="/res/brd/'+posted_on+'/'+str(threadnum)+'/t'+imge+'" onclick="imgswap(this)"></a>'
            response_body += '</div>' if OP else ''
        comment = post_comment.split('<br>')
        if mode<0 and len(comment)>20:
            comment = '<br>'.join(comment[:20])+'<span class="long"><br>...<br>Comment too long. View thread to see entire comment.</span>'
        else:
            comment = '<br>'.join(comment)
        response_body += '<blockquote style="margin-left:'+str(image_width)+'px">'+comment+'</blockquote>'

        if not OP:
            #response_body += '</tr></table>'
            if not sub and subs:
                Cur.execute('SELECT * FROM sub."'+posted_on+'/'+str(threadnum)+'/'+str(postnum)+'" ORDER BY postnum DESC;')
                subposts = Cur.fetchall()
                response_body += '<div class="sub">'
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
    return '<!DOCTYPE HTML><html><head><meta charset="utf-8"><link rel="shortcut icon" type="image/png" href="/res/favicon.png"/><title>Error</title></head><body><h2>'+msg+'</h2></body></html>'
