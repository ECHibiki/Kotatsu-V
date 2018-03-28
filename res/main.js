/**
 *
 * @source: https://4taba.net/res/main.js
 *
 * @licstart  The following is the entire license notice for the 
 *  JavaScript code in this page.
 *
 * Copyright (C) 2018  4taba
 *
 *
 * The JavaScript code in this page is free software: you can
 * redistribute it and/or modify it under the terms of the GNU
 * General Public License (GNU GPL) as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option)
 * any later version.  The code is distributed WITHOUT ANY WARRANTY;
 * without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU GPL for more details.
 *
 * As additional permission under GNU GPL version 3 section 7, you
 * may distribute non-source (e.g., minimized or compacted) forms of
 * that code without the copy of the GNU GPL normally required by
 * section 4, provided you include this license notice and a URL
 * through which recipients can access the Corresponding Source.
 *
 * @licend  The above is the entire license notice
 * for the JavaScript code in this page.
 *
 */

function watchThread(label, timestamp){
// Three different ways to store watched thread list:
// 1) No Javascript - this onclick function is ignored and the user makes a call to the server to calculate the new value of their cookie for them
// 2) Yes Javascript, No localStorage - return false from this function to block server call, use Javascript to update the users threadlist cookie
// 3) Yes Javascript, Yes localStorage - return false from this function to block server call, use Javascript to update the users threadlist in localStorage
////
//// NOTE: Watch button should have property onclick="return watchThread()" which can be used to block the link if it returns false (in this case, if Javascript is enabled)

    if (label == "")
        alert('Error: Thread label is blank.');
        return false;

    if (typeof(Storage) !== "undefined"){
    // USE LOCAL STORAGE
        var ls = true;
        var val = localStorage.threads || '';
    }else{
    // USE COOKIES
        var ls = false;
        var c = document.cookie.split(';');
        var val = '';
        for (var i = 0; i < c.length; ++i){
            var idx = c[i].indexOf('=');
            if (idx >= 0){
                var key = c[i].substring(0, idx);
                var jdx = key.indexOf(' ');
                if (jdx >= 0)
                    key = key.substring(0, jdx);

                if (key == 'threads'){
                    val = c[i].substring(idx+1, c[i].length);
                    while (val.length>0 && val[0] == " "){
                        val = val.substring(1, val.length);
                    }
                    break;
                }
            }
        }
    }

    var index = 0;
    var threads = val.split(' ');
    for (var tdx = 0; tdx<threads.length; ++tdx){
        var edx = threads[tdx].indexOf('!');
        if (label == threads[tdx] || label == threads[tdx].substring(0, edx)){
        // Already watching thread; just update timestamp
            threads[tdx] = label+'!'+timestamp;
        }else{
        // Not watching thread yet; add it to the list
            threads.push(label+'!'+timestamp;
        }
    }

    if (ls){
        localStorage.threads = threads.join(' ');
    }else{
        document.cookie='threads='+threads.join(' ')+'; expires=Tue, 19 Jan 2038 03:14:07 UTC; domain=.4taba.net; path=/';
    }

    return false;
}

function autoUpdate(){
    var url = window.location.pathname.split('/');
    var board = url[1];
    var thread = url[2];
    var timestamp = document.getElementById('timestamp').innerHTML;
    var req_url = '/update/'+board+'/'+thread+'!'+timestamp

    var request = new XMLHttpRequest();
    request.onreadystatechange = function(){
        if(request.readyState==4 && request.status==200){
            if(request.responseText != '')
                document.getElementById("1").innerHTML += request.responseText;
        }
    }

    request.open("GET", url, true);
    request.send(null);
}

function checksize(max){
    maxb = max * 1024**2;
    var f = document.getElementsByName('file')[0];
    if(f.files && f.files[0].size > maxb){
        alert('Maximum upload size is '+(max)+'MB.');
        return false;
    }
    return true;
}

function imgswap(e){
    // First time around this function called through onclick="imgswap(this)" and so e already = this.
    // Second (and further) time around function is called from event listeners and e is undefined.
    if (typeof e.src == 'undefined')
        e = this;

    var type = '';
    var lst = e.src.split('/');
    var p = e.src.slice(0, lst.length-1).join('/');
    var name = lst[lst.length-1];
    var ext = ''

    var mime = getRealFileType()

    /*if(['JPEG','PNG','GIF'].indexOf(mime) > -1)
        type = 'img';
    else if(['WebM','MP4'].indexOf(mime) > -1)
        type = 'video'
    else if(['MP3','OGG','FLAC','WAV'].indexOf(mime) > -1)
        type = 'audio'
    if(ext == 'M4A'){
        type = 'audio';
        mime = 'mp4';
    }*/
    type='img';

    var swap = e.getAttribute('data-swap') || '';
    var orig = e.src;

    e.style.opacity="0.5";
    if (type == 'img'){
        e.setAttribute('data-swap', orig);
        e.src = swap;
    }






    /*if(type=='img'){
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
    }*/
    if(window.scrollY>prnt.parentElement.offsetTop)
        prnt.parentElement.parentElement.scrollIntoView();
}

/*function hidev(){
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
}*/


/*function srchk(e){
    if(e.keyCode==13){
        e.preventDefault();
        srch();
    }
}*/

/*function srch(){
    var text = document.getElementById('srchbr').value.toLowerCase();
    var threads = document.getElementsByClassName('thread');
    
    for (var idx=0, thread; thread = threads[idx]; ++idx){
        if(thread.innerHTML.toLowerCase().indexOf(text) == -1){
            thread.style.display='none';
        }else{
            thread.style.display='inline-block';
        }
    }
}*/

function hidemenu(){
    document.getElementsByClassName('menu')[0].style.display='none';
    document.getElementsByTagName('body')[0].style.marginLeft="5px";
    document.getElementsByTagName('body')[0].style.width="auto";
    document.getElementsByTagName('body')[0].style.border="none";
    var links = '<a href="javascript:void(0)" onclick="showmenu()">SideMenu</a> ';
    document.getElementById('topnav').innerHTML = links;
    document.getElementById('botnav').innerHTML = links;
    localStorage.menu='hide'
    links = '<span style="font-size:13px"><b>[ <a href="/">HOME</a> <a href="/res/rulesEN">Rules</a> <a href="/res/faqEN">F.A.Q.</a> <a href="/watcher">Watcher</a> <a href="/settings">Settings</a> ] [ <a href="/all">/all/</a> ] [ <a href="/a">/a/</a> <a href="/ma">/ma/</a> <a href="/jp">/jp/</a> <a href="/d">/d/</a> <a href="/ni">/ni/</a> ] [ <a href="/hw">/hw/</a> <a href="/sw">/sw/</a> <a href="/pr">/pr/</a> ] [ <a href="/f">/f/</a> <a href="/lit">/lit/</a> <a href="/sci">/sci/</a> <a href="/v">/v/</a> <a href="/ho">/ho/</a> ]</b></span>';
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

/*function addFile(p, n){
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
}*/

/*function changeStyle(style){
    document.cookie = 'style='+style.value+';path=/';
    location.reload();
}

function changeSortBy(sort){
    document.cookie = 'sortby='+sort.value+';path=/';
    location.reload();
}*/
