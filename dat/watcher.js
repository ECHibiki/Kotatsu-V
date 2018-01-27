var btimer;

function mainf(){
    var b = Math.floor((Math.random()*2)+1).toString();
    var e = document.getElementById('banner');
    e.src = '/res/dat/banner'+b.toString()+'.jpg';

    if(typeof(Storage) !== "undefined"){
        var t = localStorage.threads || '';
        var threads = t.split(' ');
        if(t.length > 0){
            var tdiv = document.getElementById('threadWatcher');
            tdiv.addEventListener('click', clicked, false);
            var html = '<input type="submit" onclick="updateAll(this)" value="Get all new"><table style="border:none;background:transparent;width:100%;">'
            for(var i=0; i<threads.length; ++i)
                html += '<tr id="x'+threads[i]+'"><td style="font-size:18px;width:5px"><div class="column"><a style="color:#000;" href="javascript:clear(\''+threads[i]+'\')">[<span id="i'+threads[i]+'">0</span>]</a></div></td><td style="background:transparent;"><div draggable="true" style="padding:1px;margin:0px;" class="'+localStorage.getItem('c'+threads[i])+'">'+localStorage.getItem('t'+threads[i])+' <input id="u'+threads[i]+'" type="submit" onclick="update(\''+threads[i]+'\',null);" value="Get new"> (<span id="a'+threads[i]+'">_</span>s)</div><div style="display:none;" id="h'+threads[i]+'">'+localStorage.getItem('o'+threads[i])+'<div id="b'+threads[i]+'"></div></div><div style="clear:both;"></div></div></div></div></td><td style="width:5px"><a style="font-size:18px;color:#D11;" href="javascript:del(\''+threads[i]+'\')">X</a></td></tr>';
            tdiv.innerHTML = tdiv.innerHTML+html+'</table>';
            for(var i=0; i<threads.length; ++i){
                processComment(threads[i]);
                setTimeout(countDownFunc(threads[i], +localStorage.getItem('p'+threads[i]), 20+(i*5)), 1000);
            }
        }else
            document.getElementById('threadWatcher').innerHTML = '<span style="background:#FFF;">No threads added yet. Visit a thread and click the [Watch Thread] link to add a thread to this watcher.</span>';

        document.getElementById("query").value = localStorage.getItem('bq') || '';
    }else{
        alert("Your browser does not support local storage objects. Please email me with your browser details, if enough people have this issue on various browsers I'll try to come up with a solution.");
    }

    var l = document.getElementsByClassName('column');
    for(var i=0; i<l.length; ++i){
        l[i].addEventListener('dragstart', handleDragStart, false);
        l[i].addEventListener('dragenter', handleDragEnter, false);
        l[i].addEventListener('dragover', handleDragOver, false);
        l[i].addEventListener('dragleave', handleDragLeave, false);
        l[i].addEventListener('drop', handleDrop, false);
        l[i].addEventListener('dragend', handleDragEnd, false);
    }
}

function handleDragStart(e){
    this.style.opacity = '0.5';
    e.dataTransfer.setData('text/plain',this.parentElement.parentElement.id);
}
function handleDragOver(e){
    if(e.preventDefault)
        e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    return false;
}
function handleDragEnter(e){
    this.classList.add('over');
}
function handleDragLeave(e){
    this.classList.remove('over');
}
function handleDrop(e){
    if(e.stopPropagation)
        e.stopPropagation();
    swapElements(document.getElementById(this.parentElement.parentElement.id), document.getElementById(e.dataTransfer.getData('text/plain')));
    var t = document.getElementsByClassName('column');
    var threads = []
    for(var i=0; i<t.length; ++i){
        var a = t[i].parentElement.parentElement;
        var thread = a.id.substring(1, a.id.length);
        threads.push(thread);
    }
    localStorage.threads = threads.join(' ');
    return false;
}
function handleDragEnd(e){
    this.style.opacity = '1.0';
    var l = document.getElementsByClassName('column');
    for(var i=0; i<l.length; ++i)
        l[i].classList.remove('over');
}
function swapElements(obj1, obj2){
    var temp = document.createElement('div');
    obj1.parentNode.insertBefore(temp, obj1);
    obj2.parentNode.insertBefore(obj1, obj2);
    temp.parentNode.insertBefore(obj2, temp);
    temp.parentNode.removeChild(temp);
}

function unhide(e){
    var a = e.parentElement;
    e.setAttribute('onclick','hide(this);');
    e.innerHTML='[ - ] ';
    var b = a.getElementsByTagName('img');
    if(typeof b[0] !== 'undefined')
        b[0].style.display = 'block';
    b = a.getElementsByTagName('blockquote');
    b[0].style.display = 'block';
}

function hide(e){
    var a = e.parentElement;
    e.setAttribute('onclick','unhide(this);');
    e.innerHTML = '[ + ] ';
    var b = a.getElementsByTagName('img');
    if(typeof b[0] !== 'undefined')
        b[0].style.display = 'none';
    b = a.getElementsByTagName('blockquote');
    b[0].style.display = 'none';
}

function del(thread){
    localStorage.removeItem('t'+thread);
    localStorage.removeItem('o'+thread);
    localStorage.removeItem('p'+thread);
    localStorage.removeItem('c'+thread);
    var l = localStorage.threads;
    l = l.split(' ');
    var n = l.indexOf(thread);
    if(n != -1){
        l.splice(n, 1);
        localStorage.threads = l.join(' ');
    }
    var el = document.getElementById('x'+thread);
    el.parentElement.removeChild(el);
}

function clear(thread){
    document.getElementById('b'+thread).innerHTML = '';
    var el = document.getElementById('i'+thread);
    el.innerHTML = '0';
    el.style.color="#000";

}

function countDown(obj, dat){
    obj.innerHTML = dat.i;
    if(dat.i==0){
        if(!document.getElementById(obj.id))
            return;
        update(obj.id.replace('a',''), dat);
        dat.i = dat.imax+1;
    }
    dat.i -= 1;
    setTimeout(function(){countDown(obj, dat);}, 1000);
}


/*function autoUpdate(obj, dat){
    var url = dat.thread.split('/')
    url.splice(1, 0, 'a');
    url = '/' + url.join('/') + '/' + (dat.pcnt+2).toString();
    var request = new XMLHttpRequest();
    request.onreadystatechange = function(){
        if(request.readyState==4 && request.status==200){
            if(request.responseText != ''){
                var add = +request.responseText.substring(0, request.responseText.search(' '));
                var html = request.responseText.substring(4, request.responseText.length);
                document.getElementById('b'+dat.thread).innerHTML += html;
                var el = document.getElementById('i'+dat.thread);
                var num = +el.innerHTML;
                el.innerHTML = num + add;
                el.style.color="#D11";

                dat.imax = 10;
                dat.pcnt += add;
                processComment(dat.thread);
                localStorage.setItem('p'+dat.thread, dat.pcnt.toString());
                obj = document.getElementById('a'+dat.thread);
            }else{
                dat.imax += Math.ceil(dat.imax/2)+1;
                if(dat.imax>300){dat.imax=300;}
            }
            //dat.i = dat.imax+1;
        }
    }
    request.open("GET", url, true);
    request.send(null);
}*/

function update(thread, dat){
    var obj = document.getElementById('u'+thread);
    obj.value='updating...';
    obj.style.color='#888';
    var url = thread.split('/')
    var pcnt = +localStorage.getItem('p'+thread);
    url.splice(1, 0, 'a');
    url = '/' + url.join('/') + '/' + (pcnt+2).toString();
    var request = new XMLHttpRequest();
    request.onreadystatechange = function(){
        if(request.readyState==4 && request.status==200){
            if(request.responseText != ''){
                var add = +request.responseText.substring(0, request.responseText.search(' '));
                var html = request.responseText.substring(4, request.responseText.length);
                document.getElementById('b'+thread).innerHTML += html;
                var el = document.getElementById('i'+thread);
                var num = +el.innerHTML;
                el.innerHTML = num + add;
                el.style.color="#D11";

                if(dat)
                    dat.imax = 30;
                pcnt += add;
                processComment(thread);
                localStorage.setItem('p'+thread, pcnt.toString());
                obj = document.getElementById('u'+thread);
            }else if(dat){
                dat.imax += Math.ceil(dat.imax/2)+1;
                if(dat.imax>300){dat.imax=300;}
            }
            obj.value='Get new';
            obj.style.color='#000';
        }
    }
    request.open("GET", url, true);
    request.send(null);
}
function updateAll(e){
    e.value='updating all...';
    e.style.color='#888';
    var t = localStorage.threads || '';
    var threads = t.split(' ');
    if(t.length > 0){
        for(var i=0; i<threads.length; ++i)
            update(threads[i], null);
    }
    e.value='Get all new';
    e.style.color='#000';
}

function countDownFunc(thread, pcnt, t){
    return function(){
        countDown(document.getElementById('a'+thread), {'thread':thread, 'pcnt':pcnt, 'i':t, 'imax':30});
    }
}

function processComment(thread){
    var d = document.getElementById('OP'+thread);
    var e = d.getElementsByTagName('img');
    for(var i=0, a; a=e[i]; ++i){
        var ext = a.src.substring(a.src.length-7,a.src.length-4);
        if(ext != 'swf' && a.src.indexOf('banner')==-1){
            var a2 = a.cloneNode(true);
            a.parentNode.insertBefore(a2, a.nextSibling);
            a.parentNode.removeChild(a);
            a2.addEventListener('click', imgswap);
            if(localStorage.mmc=='none'){
                a2.parentElement.removeAttribute('href');
            }
            //a2.addEventListener('load', function(){this.style.opacity="1.0";});
            //a.parentNode.removeChild(a);
        }
    }
}

function imgswap(){
    var type = ''
    var lst = this.src.split('/');
    var p = lst.slice(0, lst.length-1).join('/');
    var name = lst[lst.length-1];
    var ext = ''
    if(name[0] == 't'){
        name = name.substring(1,name.length-4);
        var split = name.split('.');
        ext = split[split.length-1];
        if(['webm','mp4'].indexOf(ext) > -1)
            type = 'video'
        else if(['mp3','ogg','flac','wav'].indexOf(ext) > -1)
            type = 'audio'
        if(ext == 'm4a'){
            type = 'audio';
            ext = 'mp4';
        }
//        else if(name.slice(name.length-3,name.length)=='.14')
//            type = 2
        //this.style.maxWidth=Number(document.body.offsetWidth-48).toString()+"px";
    }else{
        name = 't'+name+'.jpg';
        //this.style.width="initial";
    }
    //this.style.opacity="0.5";
    if(type==''){
        var prnt = this.parentElement;
        var nw = document.createElement('img');
        nw.style.maxWidth=Number(document.body.offsetWidth-48).toString()+"px";
        nw.src = p+'/'+name;
        prnt.appendChild(nw);
        prnt.removeChild(this);
        nw.addEventListener('click', imgswap);
    }else{
        var prnt = this.parentElement.parentElement;
        //this.parentElement.remove();
        if(prnt.style.display == 'table'){
            if(prnt.lastChild.tagName == 'DIV')
                prnt.removeChild(prnt.lastChild);
            var c = prnt.children;
            for(var i=0; i<c.length; ++i){
                if(c[i].style.opacity == '0.5'){
                    c[i].style.opacity='1.0';
                    c[i].firstChild.removeEventListener('click',hidev);
                    c[i].firstChild.addEventListener('click',imgswap);
                }
            }
            this.parentElement.style.opacity='0.5';
            this.removeEventListener('click',imgswap);
            this.addEventListener('click',hidev);
        }else{
            this.parentElement.style.display='none';
            var aw = document.createElement('a');
            aw.href='javascript:void(0)';
//            aw.setAttribute('onclick','hidev(this);');
            aw.addEventListener('click',hidev);
            aw.setAttribute('thumb',this.parentElement.href);
            aw.innerHTML = '[ - ]<br>';
        }
        var dw = document.createElement('div');
        dw.style.display='table';
        var nw = document.createElement(type);
        nw.setAttribute('controls','2');
        nw.setAttribute('autoplay','1');
        if(localStorage.getItem('volume')===null)
            nw.volume=0.1;
        else
            nw.volume=Number(localStorage.volume)/100
        nw.setAttribute('loop','1');
        var sc = document.createElement('source');
        alert('ext: '+ext);
        sc.setAttribute('type',type+'/'+ext);
        sc.src = p+'/'+name;
        nw.appendChild(sc);
        if(aw)
            dw.appendChild(aw);
        dw.appendChild(nw);
        prnt.appendChild(dw);
        dw.style.maxWidth=Number(document.body.offsetWidth-48).toString()+"px";
        prnt = dw;
    }
    if(window.scrollY>prnt.parentElement.offsetTop)
        prnt.parentElement.parentElement.scrollIntoView();
}

function hidev(){
    if(this.tagName == 'A'){
        var p = this.parentElement.parentElement;
        //var s = e.getAttribute('thumb');

        var c = p.children;
        for(var i=0; i<c.length; ++i){
            //if(c[i].href == s){
            c[i].style.display='initial';
            //}
        }
        this.parentElement.parentElement.removeChild(this.parentElement);
    }else if(this.tagName == 'IMG'){
        var p = this.parentElement.parentElement;
        var c = p.children;
        for(var i=0; i<c.length; ++i){
            if(c[i].style.opacity == '0.5'){
                c[i].style.opacity='1.0';
                c[i].firstChild.removeEventListener('click',hidev);
                c[i].firstChild.addEventListener('click',imgswap);
            }
        }
        p.removeChild(p.lastChild);
    }

    //nw.addEventListener('click', imgswap);
    if(window.scrollY>p.parentElement.offsetTop)
        p.parentElement.scrollIntoView();
}

function clicked(e){
    var el = e.target;
    for(var i=0; i<5; ++i){
        if(el.className.indexOf('thread') > -1)
            break;
        else if(el.className == 'tw' || ['img','input'].indexOf(el.tagName.toLowerCase()) > -1)
            return false;
        el = el.parentElement;
        if(i==4)
            return false;
    }
    var ctr = document.getElementById('h'+el.getAttribute('b')+'/'+el.getAttribute('t'));
    if(ctr.style.display == 'none')
        ctr.style.display = 'block';
    else
        ctr.style.display = 'none';
    if(window.scrollY>ctr.parentElement.offsetTop)
        ctr.parentElement.scrollIntoView();
}

/*function setquery(){
    var bq = document.getElementById('query').value;
    localStorage.setItem('bq', bq);
    var obj = document.getElementById('bc')
    var epoch = 0;
    var dat = {'bq':bq, 'obj':obj, 't':10, 'tmax':10, 'epoch':epoch};
    boardUpdate(dat);
    clearTimeout(btimer);
    btimer = setTimeout(function(){boardCountDown(dat);}, 1000);
}

function boardCountDown(dat){
    dat.obj.innerHTML = dat.t;
    if(dat.t==0){
        boardUpdate(dat);
        dat.t = dat.tmax+1;
    }
    dat.t -= 1;
    btimer = setTimeout(function(){boardCountDown(dat);}, 1000);
}*/

function boardUpdate(e){
    e.value='updating...';
    e.style.color='#888';
    var bq = document.getElementById('query').value;
    localStorage.setItem('bq', bq);
    var epoch = +localStorage.epoch || 0;
    var url = '/'+bq+'!'+epoch.toString()+'/b';
    if(epoch==0)
        url+='0';
    var request = new XMLHttpRequest();
    request.onreadystatechange = function(){
        if(request.readyState==4 && request.status==200){
            if(request.responseText != ''){
                localStorage.epoch = +request.responseText.substring(0, request.responseText.search(' '));
                var html = request.responseText.substring(12, request.responseText.length);
                var el = document.getElementById('boardWatcher');
                el.innerHTML = el.innerHTML + html;
            }
            e.value='Update';
            e.style.color='#000';
        }
    }
    request.open("GET", url, true);
    request.send(null);
}

/*function stopquery(){
    clearTimeout(btimer);
    document.getElementById('bc').innerHTML = '';
}*/

function clearThreads(){
    document.getElementById('boardWatcher').innerHTML = '';
}

function hidemenu(){
    document.getElementsByClassName('menu')[0].style.display='none';
    document.getElementsByTagName('body')[0].style.marginLeft="5px";
    document.getElementsByTagName('body')[0].style.width="auto";
    document.getElementsByTagName('body')[0].style.border="none";
    document.getElementById('nav').innerHTML='<a href="javascript:void(0)" onclick="showmenu()">show→</a> ';
    localStorage.menu='hide'
    document.getElementById('toplinks').innerHTML=  '<span style="font-size:13px"><b>[ <a href="/">HOME</a> <a href="/res/dat/rulesEN">Rules</a> <a href="/res/dat/faqEN">F.A.Q.</a> <a href="/watcher">Watcher</a> <a href="/settings">Settings</a> ]<br>[ <a href="/all">/all/</a> ] [ <a href="/a">/a/</a> <a href="/ma">/ma/</a> <a href="/jp">/jp/</a> <a href="/d">/d/</a> <a href="/ni">/ni/</a> ] [ <a href="/hw">/hw/</a> <a href="/sw">/sw/</a> <a href="/pr">/pr/</a> ] [ <a href="/f">/f/</a> <a href="/lit">/lit</a> <a href="/sci">/sci/</a> <a href="/v">/v/</a> <a href="/ho">/ho/</a> ]</b></span><br>';
}

function showmenu(){
    document.getElementsByClassName('menu')[0].style.display='';
    document.getElementsByTagName('body')[0].style.marginLeft="105px";
    document.getElementsByTagName('body')[0].style.width="auto";
    document.getElementsByTagName('body')[0].style.border="none";
    document.getElementById('nav').innerHTML='';
    localStorage.menu=''
    document.getElementById('toplinks').innerHTML='';
}

function checkmenu(){
    var e = document.getElementById('navlnks');
    e.innerHTML = '<span id="nav"></span><a href="javascript:void(0)" onclick="window.scrollTo(0,0);">T</a> <a href="javascript:void(0)" onclick="window.scrollTo(0,document.body.scrollHeight);">B</a>';

    var m = localStorage.menu || '';
    if(m=='hide')
        hidemenu();
    var e = document.getElementById('mhide');
    e.innerHTML = '←Hide';
}
