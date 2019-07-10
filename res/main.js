/**
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

function checksize(max){
    var maxb = max * Math.pow(1024, 2);
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

    if (e.hasAttribute('src')){
        var type = '';
        var lst = e.src.split('/');
        var p = lst.slice(0, lst.length-1).join('/');
        var name = lst[lst.length-1];

        if (name[0] == 't')
            var expanded = false;
        else
            var expanded = true;
    }else{
        var thumb = e.dataset['thumb'];
        var expanded = true;
    }

    var mime = e.dataset['ftype'];

    if(['JPEG','PNG','GIF'].indexOf(mime) > -1){
        type = 'img';
    }else if(['WebM','MP4'].indexOf(mime) > -1){
        type = 'video'
        var srctype = 'webm';
    }else if(mime == 'MP3'){
        type = 'audio';
        var srctype = 'mpeg';
    }else if(mime == 'M4A'){
        type = 'audio';
        var srctype = 'mp4';
    }else if(mime == 'FLAC'){
    }else if(mime == 'WAV'){
    }else if(mime == 'OGG'){
    }

    var prnt = e.parentElement;

    e.style.opacity="0.5";
    if (type == 'img'){
        if (expanded)
            e.src = p+'/t'+name
        else
            e.src = p+'/'+name.substring(1, name.length)

        e.addEventListener('load', function() { e.style.opacity="1.0"; }, false);

    }else if(type == 'video'){
        if (expanded){
            prnt.nextSibling.remove();
            prnt.firstChild.remove();
            prnt.innerHTML = '<img data-ftype="'+mime+'" src="'+thumb+'" onclick="imgswap(this)">';
        }else{
            var nv = document.createElement('video');

            nv.addEventListener('loadeddata', function() {
                var src = prnt.firstChild.src;
                prnt.innerHTML = '<span data-ftype="'+mime+'" data-thumb="'+src+'">[ - ]</span><br>';
                prnt.firstChild.addEventListener('click', imgswap)
                prnt.parentElement.insertBefore(nv, prnt.nextSibling);
            }, false);

            nv.setAttribute('controls', '1');
            nv.setAttribute('autoplay', '1');
            nv.setAttribute('loop', '1');
            nv.volume = 0.1;
            nv.innerHTML = '<source src="'+p+'/'+name.substring(1, name.length)+'" type="video/'+srctype+'">Your browser does not support the video element.';


        }
    }else if(type == 'audio'){
        if (expanded){
            prnt.nextSibling.remove();
            prnt.firstChild.remove();
            prnt.innerHTML = '<img data-ftype="'+mime+'" src="'+thumb+'" onclick="imgswap(this)">';
        }else{
            var nd = document.createElement('div');
            var ni = document.createElement('img');
            var na = document.createElement('audio');

            na.addEventListener('loadeddata', function() {
                var src = prnt.firstChild.src;
                prnt.innerHTML = '<span data-ftype="'+mime+'" data-thumb="'+src+'">[ - ]</span><br>';
                prnt.firstChild.addEventListener('click', imgswap)
                ni.src = p+'/f'+name.substring(1, name.length)
                prnt.parentElement.insertBefore(nd, prnt.nextSibling);
            }, false);

            nd.appendChild(na);
            nd.appendChild(ni);

            na.setAttribute('controls', '1');
            na.setAttribute('autoplay', '1');
            na.setAttribute('loop', '1');
            na.volume = 0.1;
            na.innerHTML = '<source src="'+p+'/'+name.substring(1, name.length)+'" type="audio/'+srctype+'">Your browser does not support the audio element.';
        }
    }

    if(window.scrollY>prnt.offsetTop)
        prnt.parentElement.scrollIntoView();
    return false;
}

function srchk(e){
    if(e.keyCode==13){
        e.preventDefault();
        srch_catalog();
    }
}

function srch_catalog(){
    var text = document.getElementById('srchbr').value.toLowerCase();
    var threads = document.getElementsByClassName('threadcontainer');
    
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
    links = '<span style="font-size:13px"><b>[ <a href="/">HOME</a> <a href="/res/rulesEN">Rules</a> <a href="/res/faqEN">F.A.Q.</a> ] [ <a href="/listed">/listed/</a> <a href="/unlisted">/unlisted/</a> <a href="/all">/all/</a> ] [ <a href="/a">/a/</a> <a href="/ni">/ni/</a> <a href="/d">/d/</a> ] [ <a href="/cc">/cc/</a> ] [ <a href="/f">/f/</a> <a href="/v">/v/</a> <a href="/ho">/ho/</a> ]</b></span>';
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

function changeSortBy(sort){
    document.cookie = 'sortby='+sort.value+';path=/';
    location.reload();
}

function plink(n){
    var e = document.getElementsByName('comment');
    e[0].value += '>>'+n.toString()+'\n'
    e[1].value += '>>'+n.toString()+'\n'
}

function changeStyle(style){
    document.cookie = 'style='+style.value+';path=/';
    location.reload();
}

function removeflash(){
    document.getElementById("shadediv").style.display="none";
    var flashcont = document.getElementById("flashcont");
    flashcont.innerHTML = "";
}

function embedflash(file, width, height){
    var flashcont = document.getElementById("flashcont");
    document.getElementById("shadediv").style.display = "initial";
    flashcont.innerHTML = "\
<object type='application/x-shockwave-flash' data='"+file+"' width='"+width+"' height='"+height+"'>\
<param name='jello' value='"+file+"'>\
<param name='quality' value='high'>\
</object>";
}
