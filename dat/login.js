function mainf(){
    var b = Math.floor((Math.random()*2)+1).toString();
    var e = document.getElementById('banner');
    e.src = '/res/dat/banner'+b.toString()+'.jpg';

}

function send(){
    var request = new XMLHttpRequest();
    var params = 'id='+document.getElementById('id').value+'&pass='+document.getElementById('pass').value;
    request.open("POST", '/mod/login', true);
    request.setRequestHeader("Content-type", "text/plain");
    request.setRequestHeader("Content-length", params.length);
    request.setRequestHeader("Connection", "close");          

    request.onreadystatechange = function(){
        if(request.readyState==4 && request.status==200){
            if(request.responseText != '' && request.responseText != 'fail'){
                document.cookie='mod='+request.responseText+';path=/'
                document.getElementById('status').innerHTML = '<span style="background:#FFF;color:#0F0">Login Successful.</span>'
            }else if(request.responseText == 'fail'){
                document.getElementById('status').innerHTML = '<span style="background:#FFF;color:#F00">Login Failed.</span>'
            }
        }
    }
    request.send(params);
    
    return false;
}

function logout(){
    document.cookie='mod=;expires=Thu, 2 Aug 2001 20:47:11 UTC;path=/';
    document.getElementById('status').innerHTML = '<span style="background:#FFF;color:#00F">Logged out successfully.</span>'
}