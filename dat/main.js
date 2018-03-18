function watchThread(label, cnt){
    if(typeof(Storage) !== "undefined"){
        var t = localStorage.threads || '';
        var threads = t.split(' ');
        if(threads.indexOf(label) == -1){
            if(threads[0] == ''){
                threads[0] = label;
            }else{
                threads.push(label);
            }
            localStorage.threads = threads.join(' ');
        }

        var tempobj = document.getElementById('OP'+label).parentElement.parentElement;
        var temp = tempobj.innerHTML;
        if(document.body.className=='')
            var cl = tempobj.className;
        else
            var cl = document.body.className;
        //var ti = temp.indexOf('</div>');
        var ti = temp.indexOf('<a onclick="watch')-1;
        localStorage.setItem('t'+label, temp.substring(0, ti)+'</span>');
        //var idx = temp.indexOf('<a onclick="watch')-2;
        //var op = temp.substring(ti+6, idx);
        //op += temp.substring(temp.indexOf('</a>',idx)+5, temp.indexOf('</blockquote>')+13);
        var op = temp.substring(temp.indexOf('</div>', ti)+6, temp.indexOf('</blockquote>')+13);

        localStorage.setItem('o'+label, op);
        localStorage.setItem('p'+label, cnt.toString());
        localStorage.setItem('c'+label, cl);
    }else{
        alert("Your browser does not support local storage objects. Please email me with your browser details, if enough people have this issue on various browsers I'll try to come up with a solution.");
    }
}

function unhide(e){
    var a = e.parentElement;
    e.setAttribute('onclick','hide(this);');
    e.innerHTML='[ - ] ';
    var b = a.getElementsByTagName('img');
    if(typeof b[0] !== 'undefined')
        for(var i=0, j; j=b[i]; ++i)
            j.style.display = 'block';
    b = a.getElementsByTagName('blockquote');
    b[0].style.display = 'block';
}

function hide(e){
    var a = e.parentElement;
    e.setAttribute('onclick','unhide(this);');
    e.innerHTML = '[ + ] ';
    var b = a.getElementsByTagName('img');
    if(typeof b[0] !== 'undefined')
        for(var i=0, j; j=b[i]; ++i)
            j.style.display = 'none';
    b = a.getElementsByTagName('blockquote');
    b[0].style.display = 'none';
}

function autoUpdate(){
    var url = window.location.pathname.split('/');
    url.splice(2, 0, 'a');
    e = document.getElementsByClassName('post');
    url = url.slice(0,4).join('/') + '/'
    if(e[0])
        url += (Number(e[e.length-1].id)+1).toString();
    else
        url += '2';
    var request = new XMLHttpRequest();
    request.onreadystatechange = function(){
        if(request.readyState==4 && request.status==200){
            if(request.responseText != ''){
                document.getElementById("1").innerHTML += request.responseText.substring(4, request.responseText.length);
                el = document.getElementsByTagName('img');
                for(var i=0, a; a=el[i]; ++i){
                    if(a.src.indexOf('banner')==-1 && a.src.indexOf('badge')==-1)
                        a.addEventListener('click', imgswap);
                }
            }
        }
    }
    request.open("GET", url, true);
    request.send(null);
}

function checksize(max){
    var f = document.getElementsByName('file');
    for(var i = 0; i<2; ++i){
        if(f[i].files && f[i].files.length==1 && f[i].files[0].size > max){
            alert('Maximum upload size is '+(max/1024/1024)+'MB.');
            return false;
        }
    }
    return true;
}

function imgswap(e){
    if (typeof e.src == 'undefined')
        e = this;

    var type = '';
    var lst = e.src.split('/');
    var p = lst.slice(0, lst.length-1).join('/');
    var name = lst[lst.length-1];
    var ext = ''
    if(name[0] == 't'){
        name = name.substring(1,name.length-4);
        var split = name.split('.');
        ext = split[split.length-1];
        if(['jpg','jpeg','png','gif'].indexOf(ext) > -1)
            type = 'img';
        else if(['webm','mp4'].indexOf(ext) > -1)
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
        type = 'img';
        name = 't'+name+'.jpg';
        //this.style.width="initial";
    }
    //this.style.opacity="0.5";
    if(type=='img'){
        var prnt = e.parentElement;
        var nw = document.createElement('img');
        if(localStorage.mmc=='open') 
            nw.style.maxWidth=Number(document.body.offsetWidth-48).toString()+"px";
        nw.src = p+'/'+name;
        prnt.appendChild(nw);
        prnt.removeChild(e);
        nw.addEventListener('click', imgswap);
    }
    if(type == 'video' || type == 'audio'){
        var prnt = e.parentElement.parentElement;
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
            e.parentElement.style.opacity='0.5';
            e.removeEventListener('click',imgswap);
            e.addEventListener('click',hidev);
            var dw = document.createElement('div');
            if(name[0] == 'e'){
                var ei = document.createElement('img');
                ei.src = p+'/'+name + '.jpg';
                dw.appendChild(ei);
            }
        }else{
            e.parentElement.style.display='none';
            var aw = document.createElement('a');
            aw.href='javascript:void(0)';
//            aw.setAttribute('onclick','hidev(this);');
            aw.addEventListener('click',hidev);
            aw.setAttribute('thumb',e.parentElement.href);
            if(type == 'audio' && name[0] == 'e')
                aw.innerHTML = '<img src="'+p+'/'+name+'.jpg"><br>';
            else
                aw.innerHTML = '[ - ]<br>';
            var dw = document.createElement('div');
        }
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


function srchk(e){
    if(e.keyCode==13){
        e.preventDefault();
        srch();
    }
}

function srch(){
    var text = document.getElementById('srchbr').value.toLowerCase();
    var threads = document.getElementsByClassName('thread');
    
    for (var idx=0, thread; thread = threads[idx]; ++idx){
        if(thread.innerHTML.toLowerCase().indexOf(text) == -1){
            thread.style.display='none';
        }else{
            thread.style.display='inline-block';
        }
    }
}

function hidemenu(){
    document.getElementsByClassName('menu')[0].style.display='none';
    document.getElementsByTagName('body')[0].style.marginLeft="5px";
    document.getElementsByTagName('body')[0].style.width="auto";
    document.getElementsByTagName('body')[0].style.border="none";
    var links = '<a href="javascript:void(0)" onclick="showmenu()">SideMenu</a> ';
    document.getElementById('topnav').innerHTML = links;
    document.getElementById('botnav').innerHTML = links;
    localStorage.menu='hide'
    links = '<span style="font-size:13px"><b>[ <a href="/">HOME</a> <a href="/res/dat/rulesEN">Rules</a> <a href="/res/dat/faqEN">F.A.Q.</a> <a href="/watcher">Watcher</a> <a href="/settings">Settings</a> ] [ <a href="/all">/all/</a> ] [ <a href="/a">/a/</a> <a href="/ma">/ma/</a> <a href="/jp">/jp/</a> <a href="/d">/d/</a> <a href="/ni">/ni/</a> ] [ <a href="/hw">/hw/</a> <a href="/sw">/sw/</a> <a href="/pr">/pr/</a> ] [ <a href="/f">/f/</a> <a href="/lit">/lit/</a> <a href="/sci">/sci/</a> <a href="/v">/v/</a> <a href="/ho">/ho/</a> ]</b></span>';
    document.getElementById('toplinks').innerHTML = links;
    document.getElementById('botlinks').innerHTML = links;
}

function showmenu(){
    document.getElementsByClassName('menu')[0].style.display='';
    document.getElementsByTagName('body')[0].style.marginLeft="105px";
    document.getElementsByTagName('body')[0].style.width="auto";
    document.getElementsByTagName('body')[0].style.border="none";
    document.getElementById('topnav').innerHTML='';
    document.getElementById('toplinks').innerHTML='';
    document.getElementById('botnav').innerHTML='';
    document.getElementById('botlinks').innerHTML='';
    localStorage.menu=''
}

function checkmenu(){
    var e = document.getElementById('navlnks');
    var m = localStorage.menu || '';
    if(m=='hide')
        hidemenu();
    var e = document.getElementById('mhide');
    e.innerHTML = '←Hide';
}

function addFile(p, n){
    n += 1;
    if(n==5)
        return 0;
    var a = '<td class="label">File</td><td colspan="2"><input type="file" name="file'+n.toString()+'">';
    if(n==2)
        a += ' <a id="'+p+'rf" href="javascript:void(0)" onclick="remFile(\''+p+'\',2)">[-]</a>';
    a += '</td><td><input type="checkbox" name="spoiler'+n.toString()+'" value="y">Spoiler Image</input></td>';
    var tr = document.createElement('tr');
    tr.className = 'fbox obox';
    tr.innerHTML = a;
    document.getElementById(p+'tab').children[0].insertBefore(tr,document.getElementById(p+'hook'));
    document.getElementById(p+'af').setAttribute('onclick','addFile(\''+p+'\','+n.toString()+')');
    document.getElementById(p+'rf').setAttribute('onclick','remFile(\''+p+'\','+n.toString()+')');
}
function remFile(p, n){
    n -= 1;
    if(n==0)
        return 0;
    var e = document.getElementById(p+'hook').previousSibling;
    e.parentElement.removeChild(e);
    document.getElementById(p+'af').setAttribute('onclick','addFile(\''+p+'\','+n.toString()+')');
    if(n>1)
        document.getElementById(p+'rf').setAttribute('onclick','remFile(\''+p+'\','+n.toString()+')');
}

function changeStyle(style){
    document.cookie = 'style='+style.value+';path=/';
    location.reload();
}

function changeSortBy(sort){
    document.cookie = 'sortby='+sort.value+';path=/';
    location.reload();
}
