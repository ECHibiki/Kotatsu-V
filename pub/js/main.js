function getCookie(cname) {
  var name = cname + "=";
  var decodedCookie = decodeURIComponent(document.cookie);
  var ca = decodedCookie.split(';');
  for(var i = 0; i <ca.length; i++) {
    var c = ca[i];
    while (c.charAt(0) == ' ') {
      c = c.substring(1);
    }
    if (c.indexOf(name) == 0) {
      return c.substring(name.length, c.length);
    }
  }
  return "";
}

function initSidebar() {
    var m = localStorage.sidebar || '';
    if(m != 'hide') {
        showSidebar();
    }
}

function initThread(target_id){
	document.getElementById(target_id).style.display = localStorage[target_id];
}

function showSidebar() {
    var bar_width = 110;
    var margin = 4;

    var e = document.getElementById("sidebar");
    e.style.display = "initial";

    document.body.style.marginLeft = bar_width.toString() + "px";
    document.getElementById("top-nav").style.left = (bar_width + margin).toString() + "px";

    e.innerHTML = `
<a href="/index" target=""><img src="/pub/img/favicon.ico" /></a><br />[<a target="_top" href="javascript:void(0);" onclick="hideSidebar();">Hide Menu ⇤</a>]<br /><br /><div style="padding-bottom:5px"><a href="/board/all" target="">All Threads</a></div>
<div style="padding-bottom:5px"><a href="/board/listed" target="">Listed Threads</a></div>
<div style="padding-bottom:5px"><a href="/board/unlisted" target="">Unlisted Threads</a></div><br><hr><h3>Boards</h3><div style="padding-bottom:5px"><a href="/board/a" target="">Anime & Manga</a></div>
<div style="padding-bottom:5px"><a href="/board/ni" target="">日本裏</a></div>
<div style="padding-bottom:5px"><a href="/board/d" target="">二次元エロ</a></div>
<div style="padding-bottom:5px"><a href="/board/cc" target="">Computer Club</a></div>
<div style="padding-bottom:5px"><a href="/board/f" target="">Flash & HTML5</a></div>
<div style="padding-bottom:5px"><a href="/board/v" target="">Video Games</a></div>
<div style="padding-bottom:5px"><a href="/board/ho" target="">Other</a></div><br /><hr /><br /><div id="sidebar-admin-links"><h3>Admin Links</h3><div style="padding-bottom:5px"><a href="/panel" target="">Admin Panel</a></div><div style="padding-bottom:5px"><a href="/logoff" target="">Log Off</a></div></div><h3>Information</h3><div style="padding-bottom:5px"><a href="/" target="_top">HOME</a></div><div style="padding-bottom:5px"><a href="/about" target="">About</a></div><div style="padding-bottom:5px"><a href="/rules" target="">Rules</a></div><div style="padding-bottom:5px"><a href="/news" target="">News</a></div>
`;

    hideAdminLinks();
    localStorage.sidebar = '';
}

function hideSidebar() {
    var margin = 4;

    document.getElementById("sidebar").style.display = "none";

    document.body.style.marginLeft = "0px";
    document.getElementById("top-nav").style.left = margin.toString() + "px";

    localStorage.sidebar = 'hide';
}

function hideAdminLinks() {
    if (getCookie("mod-key") == "") {
        document.getElementById("sidebar-admin-links").style.display = "none";
    }
}

function hideThread(e, target_id){
    var thread_body = document.getElementById(target_id);
    var display_type = thread_body.style.display == "none" ? "initial" : "none";

    thread_body.style.display = display_type;
    localStorage[target_id] = display_type;

    return false;
}

function thumbnailClick(e) {
    var src = e.src;
    var swap = e.dataset.swapWith;
    var mimetype = e.dataset.mimetype;

    var p = e;
    let offsetTop = 0;
    while (p) {
        offsetTop += p.offsetTop;
        p = p.offsetParent;
    }

    if (['JPEG','PNG','GIF', 'WEBP'].indexOf(mimetype) > -1) {
        e.style.opacity = 0.5;
        e.src = swap;
        e.dataset.swapWith = src;
        if (window.scrollY > offsetTop) {
            e.scrollIntoView();
        }
        return false;
    } else {
        return true;
    }
}

function swapIsLoaded(e){
	e.style.opacity = 1;
}

function postNumClick(e){
	document.forms[1].elements["comment"].value+=">>"+e.textContent;
}
