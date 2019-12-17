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

function showSidebar() {
    var bar_width = 110;
    var margin = 4;

    var e = document.getElementById("sidebar");
    e.style.display = "initial";

    document.body.style.marginLeft = bar_width.toString() + "px";
    document.getElementById("top-nav").style.left = (bar_width + margin).toString() + "px";

    e.innerHTML = `
<%= sidebar-data %>
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

    if (['JPEG','PNG','GIF'].indexOf(mimetype) > -1) {
        //e.style.opacity = 0.5;
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
