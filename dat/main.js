function mainf(){
    if(typeof(Storage) !== "undefined"){
        var p = localStorage.password || '';
        if(p==''){
            p = Math.random().toString(36).slice(-8);
            localStorage.password = p;
        }
        var e = document.getElementsByName('pass');
        e[0].value = p;
        if(e.length==2)
            e[1].value = p;
    }

    var path = window.location.pathname.split('/');
    if(path.length!=3 || path[2]!='c'){
        var e = document.getElementsByTagName('img');
        for(var i=0, a; a=e[i]; ++i){
            var ext = a.src.substring(a.src.length-7,a.src.length-4);
            if(ext != 'swf' && ['banner','favicon','badge'].indexOf(a.id) == -1){
                //a.addEventListener('click', imgswap);
                if(localStorage.mmc=='none'){
                    //a.parentElement.style="pointer-events:fill";
                    a.parentElement.removeAttribute('href');
                }
                //a.addEventListener('load', function(){this.style.opacity="1.0";});
/*                var bq = a.parentElement.nextSibling;
                var w = a.width + 25;
                if (typeof(bq) != "undefined")
                    bq.style.marginLeft = w.toString()+'px';*/
            }
        }
    }

//    var path = window.location.pathname.split('/');
    if (path[path.length-1] == 'l50' || path.length == 2){
        var th = document.getElementsByClassName('thread');
        for (var idw=0; idw < th.length; ++idw){
            var bq = th[idw].getElementsByTagName('blockquote');
            for (var idx=0; idx < bq.length; ++idx){
                var links = bq[idx].getElementsByTagName('a');
                for (var idy=0; idy < links.length; ++idy){
                    var c = links[idy].href;
                    var d = c.indexOf('#');
                    if (d != -1){
                        var e = Number(c.substring(d+1,c.length));
                        if (e == 1 || (Number(bq[bq.length-1].parentElement.id) - e) < 50){
                            c = c.substring(0,d)+'/l50'+c.substring(d,c.length);
                            links[idy].href = c;
                        }
                    }
                }
            }
        }
    }

    var brkchr = [' ','　','<'];
    e = Array.prototype.slice.call(document.getElementsByTagName('blockquote'),0).concat(Array.prototype.slice.call(document.getElementsByClassName('title'),0));
    for(var i=0; i<e.length; ++i){
        var t = e[i].innerHTML;
        var c = 0;
        var s = 0;
        for(var j=0; j<t.length; ++j){
            if(s == 0 && t[j] == '<'){
                if(t[j+1]=='b' && t[j+2]=='r')
                    c = 0;
                else
                    s = 1;
            }
            if(s == 0 && brkchr.indexOf(t[j]) == -1){
                ++c;
                if(c == 25){
                    t = t.substring(0,j+1)+'<wbr>'+t.substring(j+1,t.length);
                    c=0;
                }
            }else if(s == 0){
                c=0;
            }
/*            if(s == 0 && t[j] == 'h'){
                if(t.substring(j,j+7) == 'http://' || t.substring(j,j+8) == 'https://'){
                    var d = 0;
                    while(1){
                        if(brkchr.indexOf(t[j+d]) != -1 || j+d == t.length){
                            var add = t.substring(j,j+d);
                            add = '<a href="'+add+'">'+add+'</a>';
                            t = t.substring(0,j) + add + t.substring(j+d,t.length);
                            j = j + add.length + 1;
                            break;
                        }
                        ++d;
                    }
                }
            }else if(s == 0 && t[j] == '['){
                if(t[j+1] == 'j' && t[j+2] == 'a'){
                    var idx = t.indexOf('[/ja]',j+4);
                    var add = '<span class="ja">'+t.substring(j+4,idx)+'</span>';
                    t = t.substring(0,j) + add + t.substring(idx+5,t.length);
                    j = j + add.length + 1;
                }
            }*/
            if(s == 1 && t[j] == '>')
                s = 0;
        }
//        t = '<p>' + t.split('<br>').join('</p><p>') + '</p>';
        e[i].innerHTML = t;
    }

    var s = document.getElementById('tools');
    if(s)
        s.onclick=tools;

    var s = document.getElementById('srchbr');
    if(s)
        s.onkeypress=srchk;


    if(document.getElementById("countDown") != null)
        startCountDown();
}

/*function plink(n){
    if(n!='x'){
        var e = document.getElementsByName('comment')[0];
        e.value += '>>'+n+'\n';
        e.focus();
    }
}*/

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
        var prnt = this.parentElement;
        var nw = document.createElement('img');
        if(localStorage.mmc=='open') 
            nw.style.maxWidth=Number(document.body.offsetWidth-48).toString()+"px";
        nw.src = p+'/'+name;
        prnt.appendChild(nw);
        prnt.removeChild(this);
        nw.addEventListener('click', imgswap);
    }
    if(type == 'video' || type == 'audio'){
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
            var dw = document.createElement('div');
            if(name[0] == 'e'){
                var ei = document.createElement('img');
                ei.src = p+'/'+name + '.jpg';
                dw.appendChild(ei);
            }
        }else{
            this.parentElement.style.display='none';
            var aw = document.createElement('a');
            aw.href='javascript:void(0)';
//            aw.setAttribute('onclick','hidev(this);');
            aw.addEventListener('click',hidev);
            aw.setAttribute('thumb',this.parentElement.href);
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
    document.getElementById('nav').innerHTML='<a href="javascript:void(0)" onclick="showmenu()">show→</a> ';
    localStorage.menu='hide'
    document.getElementById('toplinks').innerHTML=  '<span style="font-size:13px"><b>[ <a href="/">HOME</a> <a href="/res/dat/rulesEN">Rules</a> <a href="/res/dat/faqEN">F.A.Q.</a> <a href="/watcher">Watcher</a> <a href="/settings">Settings</a> ]<br>[ <a href="/all">/all/</a> ] [ <a href="/a">/a/</a> <a href="/ma">/ma/</a> <a href="/jp">/jp/</a> <a href="/d">/d/</a> <a href="/ni">/ni/</a> ] [ <a href="/hw">/hw/</a> <a href="/sw">/sw/</a> <a href="/pr">/pr/</a> ] [ <a href="/f">/f/</a> <a href="/lit">/lit/</a> <a href="/sci">/sci/</a> <a href="/v">/v/</a> <a href="/ho">/ho/</a> ]</b></span><br>';
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
